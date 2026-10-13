"""
The document store: files on the office server's disk, content-addressed by SHA-256.

Keys look like  <tenant id>/<first two hex of the hash>/<hash>.<ext>  and the first page
rendered as PNG sits beside the file as  <same key>.p1.png . Nothing in a key comes from
the browser: the tenant comes from the session, the hash from the bytes. Only PDF, PNG and
JPEG are accepted, decided by the bytes, never by the filename. Previews are bounded in
both directions so a hostile page geometry cannot exhaust memory, and every write lands
through a unique temp file and os.replace, so a reader never sees a half-written file.
"""
import hashlib
import os
import re
import tempfile
from pathlib import Path

from django.conf import settings

MAX_BYTES = 25 * 1024 * 1024
KEY_RE = re.compile(r"^[0-9a-f-]{36}/[0-9a-f]{2}/[0-9a-f]{64}\.(pdf|png|jpg)(\.p1\.png)?$")
PREVIEW_WIDTH = 1000
PREVIEW_MAX_HEIGHT = 1500
IMAGE_MAX_PIXELS = 40_000_000      # 40 MP: anything bigger gets no preview, the file is still filed


class RejectedFile(ValueError):
    pass


def sniff(data: bytes):
    """Return (mime_type, extension) from the leading bytes, or raise RejectedFile."""
    if data.startswith(b"%PDF-"):
        return "application/pdf", "pdf"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", "jpg"
    raise RejectedFile("Only PDF, PNG and JPEG files can be filed. This one is something else.")


def root() -> Path:
    return Path(settings.DOCUMENT_ROOT)


def path_for(key: str) -> Path:
    if not KEY_RE.match(key):
        raise RejectedFile("bad storage key")
    p = (root() / key).resolve()
    if root().resolve() not in p.parents:
        raise RejectedFile("bad storage key")
    return p


def identify(tenant_id: str, data: bytes):
    """Check the bytes and name their key without touching the disk. Returns (key, sha256, mime, ext)."""
    if not data:
        raise RejectedFile("The file is empty.")
    if len(data) > MAX_BYTES:
        raise RejectedFile("That file is over 25 MB. Scan it at a lower resolution or split it.")
    mime, ext = sniff(data)
    sha = hashlib.sha256(data).hexdigest()
    return f"{tenant_id}/{sha[:2]}/{sha}.{ext}", sha, mime, ext


def _write_atomic(dest: Path, writer):
    """writer(path) writes the content to a unique temp path; then it is moved into place.
    Two requests writing the same key race harmlessly: the first move wins, the second is dropped."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=dest.name + ".", suffix=".tmp")
    os.close(fd)
    try:
        writer(tmp)
        try:
            os.replace(tmp, dest)
        except (PermissionError, FileExistsError):
            if not dest.exists():
                raise
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def store(key: str, data: bytes):
    """Write the bytes under their key once; a second identical upload is a no-op."""
    p = path_for(key)
    if p.exists():
        return
    def writer(tmp):
        with open(tmp, "wb") as fh:
            fh.write(data)
    _write_atomic(p, writer)


def render_first_page(key: str, mime: str):
    """Render page 1 as a bounded PNG beside the file. Returns (preview_key, page_count), or
    (None, None) when nothing could be rendered; the document is still filed without a picture."""
    src = path_for(key)
    out_key = key + ".p1.png"
    out = path_for(out_key)
    try:
        if mime == "application/pdf":
            import pymupdf
            with pymupdf.open(src) as doc:
                pages = doc.page_count
                page = doc[0]
                w, h = max(page.rect.width, 1), max(page.rect.height, 1)
                zoom = min(PREVIEW_WIDTH / w, PREVIEW_MAX_HEIGHT / h, 4.0)
                if w * h * zoom * zoom > PREVIEW_WIDTH * PREVIEW_MAX_HEIGHT * 1.05:
                    return None, pages
                pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), alpha=False)
                _write_atomic(out, lambda tmp: pix.save(tmp, output="png"))
            return out_key, pages
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = IMAGE_MAX_PIXELS
        with Image.open(src) as im:
            if im.width * im.height > IMAGE_MAX_PIXELS:
                return None, 1
            im.draft("RGB", (PREVIEW_WIDTH, PREVIEW_MAX_HEIGHT))   # JPEG decodes at reduced size
            im.thumbnail((PREVIEW_WIDTH, PREVIEW_MAX_HEIGHT))
            rgb = im.convert("RGB")
            _write_atomic(out, lambda tmp: rgb.save(tmp, format="PNG", optimize=True))
        return out_key, 1
    except Exception:
        return None, None


def remove(key: str):
    """Delete a file and its preview if present (used when a filing is refused after writing)."""
    for k in (key, key + ".p1.png"):
        try:
            path_for(k).unlink(missing_ok=True)
        except RejectedFile:
            pass


def open_file(key: str):
    p = path_for(key)
    if not p.is_file():
        return None
    return open(p, "rb")
