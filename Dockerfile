# syntax=docker/dockerfile:1
ARG PRETALX_VERSION=main

# Base image with Python 3.12
FROM python:3.12-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    gettext \
    git \
    libffi-dev \
    libjpeg-dev \
    libmemcached-dev \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    locales \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Generate locales
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en

# Build stage
FROM base

ARG PRETALX_VERSION

# Clone target pretalx repository
WORKDIR /build
RUN git clone --depth 1 --branch ${PRETALX_VERSION} https://github.com/COSCUP/pretalx.git .

# Install build deps
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install uv && uv pip install --system wheel psycopg2 redis gunicorn -Ue ".[dev]"

RUN --mount=type=cache,target=/root/.cache/pip \
    python -m build

# Install wheel + extras
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install dist/pretalx*whl

# Create pretalx user
RUN mkdir /data && \
    mkdir /static && \
    groupadd -g 999 pretalx && \
    useradd -r -u 999 -g pretalx -d /pretalx -ms /bin/bash pretalx && \
    chown -R pretalx:pretalx /data && \
    chown -R pretalx:pretalx /static

# Create deployment directory
RUN mkdir -p /etc/pretalx

COPY --chmod=755 deployment/entrypoint.sh /usr/local/bin/entrypoint.sh

# Create a temporary, valid config file for the build process with network components disabled
RUN echo "[pretalx]\n\
instance_name = My Conference\n\
short_domain = pretalx\n\
datadir = /data\n\
logdir = /data/logs\n\
secret = build-time-secret-key-is-not-used\n\
url = http://localhost\n\
[database]\n\
#backend = postgresql\n\
[mail]\n\
host = localhost\n\
port = 25\n\
user = \n\
password = \n\
from = pretalx@localhost\n\
tls = False\n\
ssl = False\n\
[redis]\n\
#sessions = True\n\
[celery]\n\
#backend = redis://redis:6379/2\n\
#broker = redis://redis:6379/3\n\
[filesystem]\n\
static = /static" > /tmp/pretalx.build.cfg

# Set environment to use the temporary config
ENV PRETALX_CONFIG_FILE=/tmp/pretalx.build.cfg \
    DJANGO_SETTINGS_MODULE=pretalx.settings

# Run migrate and rebuild using the default (SQLite) settings
# RUN python -m pretalx migrate
RUN python -m pretalx rebuild --npm-install

# Now, copy the real configuration file for runtime
COPY --chmod=644 deployment/pretalx.cfg /etc/pretalx/pretalx.cfg
ENV PRETALX_CONFIG_FILE=/etc/pretalx/pretalx.cfg


WORKDIR /pretalx

# Expose ports
EXPOSE 8000

# Set volumes
VOLUME ["/data", "/static"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/healthcheck/ || exit 1

USER pretalx

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["web"]
