# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# `pg_dump` cho sao lưu (ADM-08). Phải cùng bản 16 với máy chủ db (postgres:16): pg_dump cũ hơn máy chủ
# sẽ từ chối chạy, mà Debian bookworm chỉ có bản 15 → lấy từ kho PGDG.
RUN apt-get update     && apt-get install -y --no-install-recommends ca-certificates curl gnupg     && install -d /usr/share/keyrings     && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg     && . /etc/os-release     && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list     && apt-get update     && apt-get install -y --no-install-recommends postgresql-client-16     && apt-get purge -y curl gnupg && apt-get autoremove -y     && rm -rf /var/lib/apt/lists/*

# psycopg[binary] đã bundled libpq — không cần apt-get libpq-dev.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000
# entrypoint tách riêng để web/worker/beat dùng chung image.
ENTRYPOINT ["sh", "docker-entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
