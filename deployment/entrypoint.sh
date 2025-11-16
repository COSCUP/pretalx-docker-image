#!/bin/bash
set -e



# Substitute environment variables in config file
CONFIG_SRC=/etc/pretalx/pretalx.cfg
CONFIG_DST=/tmp/pretalx.cfg
export PRETALX_CONFIG_FILE=${CONFIG_DST}

# Define all variables that are used in the config template
# We need to export them so envsubst can see them.
export PRETALX_MAIL_HOST
export PRETALX_MAIL_PORT
export PRETALX_MAIL_USER
export PRETALX_MAIL_PASSWORD
export PRETALX_MAIL_FROM
export PRETALX_MAIL_TLS
export PRETALX_MAIL_SSL

envsubst < "${CONFIG_SRC}" > "${CONFIG_DST}"

# Function to wait for PostgreSQL
wait_for_db() {
    echo "Waiting for PostgreSQL..."
    while ! python -c "import psycopg2; psycopg2.connect('host=${POSTGRES_HOST} port=${POSTGRES_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD} dbname=${POSTGRES_DB}')" 2>/dev/null; do
        sleep 1
    done
    echo "PostgreSQL is ready!"
}

# Function to wait for Redis
wait_for_redis() {
    echo "Waiting for Redis..."
    while ! python -c "import redis; r = redis.from_url('${REDIS_URL}'); r.ping()" 2>/dev/null; do
        sleep 1
    done
    echo "Redis is ready!"
}

# Gunicorn configuration with environment variable support
GUNICORN_WORKERS=${GUNICORN_WORKERS:-4}
GUNICORN_MAX_REQUESTS=${GUNICORN_MAX_REQUESTS:-1200}
GUNICORN_MAX_REQUESTS_JITTER=${GUNICORN_MAX_REQUESTS_JITTER:-50}
GUNICORN_BIND_ADDR=${GUNICORN_BIND_ADDR:-0.0.0.0:8000}
GUNICORN_FORWARDED_ALLOW_IPS=${GUNICORN_FORWARDED_ALLOW_IPS:-*}

case "$1" in
    "web")
        # Gunicorn web server without running migrations
        # Migrations are handled by separate migration service
        wait_for_db
        wait_for_redis
        exec gunicorn pretalx.wsgi \
            --bind "$GUNICORN_BIND_ADDR" \
            --workers "$GUNICORN_WORKERS" \
            --max-requests "$GUNICORN_MAX_REQUESTS" \
            --max-requests-jitter "$GUNICORN_MAX_REQUESTS_JITTER" \
            --forwarded-allow-ips "$GUNICORN_FORWARDED_ALLOW_IPS" \
            --log-level info \
            --access-logfile - \
            --error-logfile -
        ;; 
    "worker")
        wait_for_db
        wait_for_redis
        exec celery -A pretalx.celery_app worker -l info
        ;; 
    "upgrade")
        wait_for_db
        python -m pretalx check --deploy
        python -m pretalx migrate --noinput
        python -m pretalx rebuild --npm-install
        ;; 
    "manage")
        wait_for_db
        wait_for_redis
        shift
        exec python -m pretalx "$@"
        ;; 
    *)
        exec "$@"
        ;; 
esac
