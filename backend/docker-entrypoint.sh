#!/bin/sh
# migrate + collectstatic trước khi start (web khởi tạo DB; worker/beat chờ db).
set -e

if [ "${RUN_MIGRATE:-1}" = "1" ]; then
    until python -c "import socket; socket.create_connection(('${DB_HOST:-db}', ${DB_PORT:-5432}), 2)" 2>/dev/null; do
        sleep 2
    done
    python manage.py migrate --noinput
    python manage.py collectstatic --noinput
fi

exec "$@"
