# Ross Machinery Sales platform: one image, runs the web app. Postgres runs beside it
# (docker-compose.yml) so the schema's database roles can be created with full control.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN chmod +x docker/entrypoint.sh && mkdir -p /data/documents /app/staticfiles

EXPOSE 8000
ENTRYPOINT ["docker/entrypoint.sh"]
