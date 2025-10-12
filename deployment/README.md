# pretalx Docker Deployment Configuration

This directory contains configuration files for running pretalx in Docker containers.

## Files

### `pretalx.cfg`
Template configuration file that uses environment variables. The actual configuration is populated at runtime from environment variables.

### `entrypoint.sh`
Container entrypoint script that:
- Waits for database and Redis to be ready
- Supports multiple run modes:
  - `web` (default): Run gunicorn web server with migrations
  - `web-no-migrate`: Run gunicorn without migrations (for orchestrated deployments)
  - `worker`: Run celery worker for background tasks
  - `beat`: Run celery beat scheduler for periodic tasks
  - `migrate`: Run database migrations only
  - `shell`: Open Django shell
  - `createsuperuser`: Create admin user
  - `rebuild`: Rebuild frontend assets
  - Custom commands: Pass through to Django management

## Environment Variables

All configuration is done via environment variables.

### Required Variables
- `POSTGRES_PASSWORD`: Database password
- `PRETALX_SECRET_KEY`: Django secret key
- `PRETALX_SITE_URL`: Public URL of your instance

### Gunicorn Configuration (Optional)
- `GUNICORN_WORKERS`: Number of worker processes (default: 4)
- `GUNICORN_MAX_REQUESTS`: Max requests per worker (default: 1200)
- `GUNICORN_MAX_REQUESTS_JITTER`: Request restart jitter (default: 50)
- `GUNICORN_BIND_ADDR`: Bind address (default: 0.0.0.0:8000)
- `GUNICORN_FORWARDED_ALLOW_IPS`: Trusted proxy IPs (default: *)

### Filesystem Configuration (Optional)
- `PRETALX_FILESYSTEM_MEDIA`: Media files path (default: /public/media)
- `PRETALX_FILESYSTEM_STATIC`: Static files path (default: /public/static)

### Database
- `POSTGRES_DB`: Database name (default: pretalx)
- `POSTGRES_USER`: Database user (default: pretalx)
- `POSTGRES_HOST`: Database host (default: db)
- `POSTGRES_PORT`: Database port (default: 5432)

### Redis
- `REDIS_URL`: Redis connection URL (default: redis://redis:6379/0)
- `REDIS_SESSIONS`: Redis URL for sessions (default: redis://redis:6379/1)
- `CELERY_BACKEND`: Celery result backend (default: redis://redis:6379/2)
- `CELERY_BROKER`: Celery broker URL (default: redis://redis:6379/3)

### Mail (Optional)
- `PRETALX_MAIL_FROM`: From address
- `PRETALX_MAIL_HOST`: SMTP server
- `PRETALX_MAIL_PORT`: SMTP port
- `PRETALX_MAIL_USER`: SMTP username
- `PRETALX_MAIL_PASSWORD`: SMTP password
- `PRETALX_MAIL_TLS`: Use TLS (True/False)
- `PRETALX_MAIL_SSL`: Use SSL (True/False)

## Directory Structure

```
/pretalx/               # Application code
  src/                  # Django project
    manage.py
    pretalx/
/data/                  # Persistent data (volume mount)
  media/                # Legacy user uploads
  static/               # Legacy collected static files
  logs/                 # Application logs
/public/                # Public files (volume mount for reverse proxy)
  media/                # User uploads
  static/               # Collected static files
/etc/pretalx/           # Configuration
  pretalx.cfg           # Main config (from template)
```

## Running Different Modes

### Web Server (Default)
```bash
docker run -d -p 8000:8000 pretalx:latest
# or explicitly
docker run -d -p 8000:8000 pretalx:latest web
```

### Worker Only
```bash
docker run -d pretalx:latest worker
```

### Management Commands
```bash
docker run -it pretalx:latest migrate
docker run -it pretalx:latest createsuperuser
docker run -it pretalx:latest shell
docker run -it pretalx:latest rebuild
```

## Deployment

### Docker Compose
For a complete deployment example with PostgreSQL, Redis, and reverse proxy, see:
- [pretalx-docker](https://github.com/pretalx/pretalx-docker) - Official Docker Compose setup

### Kubernetes
For Kubernetes deployments:
1. Create init container with `migrate` command
2. Run web containers with `web-no-migrate` command
3. Run worker containers with `worker` command
4. Share `/public` volume across all pods
5. Configure ingress/service to serve static files from `/public`

### Orchestration Best Practices

When deploying with orchestration tools:
1. **Migrations**: Run in a separate init container or job
2. **Web containers**: Use `web-no-migrate` mode
3. **Worker containers**: Use `worker` mode for async tasks
4. **Beat scheduler**: Use `beat` mode (single instance only)
5. **Shared storage**: Mount `/public` volume on all web/worker containers
6. **Static files**: Configure reverse proxy to serve `/public/static/` and `/public/media/`

## Logs

Application logs are written to stdout/stderr and can be viewed with:
```bash
docker logs -f <container-id>
```

Additional logs may be written to `/data/logs/` depending on configuration.

## Health Check

The container includes a health check at the root path (`/`) that returns a 200 OK if the application is running properly.

## Building

From the project root:
```bash
docker build -t pretalx:latest .
```

## Support

For more information, see:
- [Main Docker Documentation](../../DOCKER.md)
- [pretalx Documentation](https://docs.pretalx.org/)
