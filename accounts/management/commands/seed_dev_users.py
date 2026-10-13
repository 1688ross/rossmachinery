"""Create the three development logins that match fixtures/seed_dev.sql. Dev only."""
from django.core.management.base import BaseCommand
import hashlib
from accounts.models import User
from django_otp.plugins.otp_totp.models import TOTPDevice

DEV = [("chuck", "local|chuck"), ("ross", "local|ross"), ("tammie", "local|tammie"), ("ashley", "local|ashley"), ("zach", "local|zach")]

class Command(BaseCommand):
    def handle(self, *args, **opts):
        for username, subject in DEV:
            u, created = User.objects.get_or_create(username=username, defaults={"auth_subject": subject})
            u.auth_subject = subject
            u.set_password("devpass123")
            u.is_staff = username == "ross"
            u.save()
            # Dev only: a confirmed authenticator with a known key, so tests can compute codes.
            # "ross" gets none, to exercise the first-sign-in setup flow.
            if username != "ross" and not TOTPDevice.objects.filter(user=u, confirmed=True).exists():
                TOTPDevice.objects.create(user=u, name="dev authenticator", confirmed=True, key=hashlib.sha1(f"dev-{username}".encode()).hexdigest())
            self.stdout.write(f"{'created' if created else 'updated'} {username} / devpass123")
