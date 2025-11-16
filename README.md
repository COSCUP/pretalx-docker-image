# pretalx Docker Image

Official Docker image builder for [pretalx](https://github.com/pretalx/pretalx), a conference planning tool.

## Quick Start

### Using Docker Compose (Recommended)

1. **Clone this repository**
   ```bash
   git clone https://github.com/pretalx/pretalx-docker-image.git
   cd pretalx-docker-image
   ```

2. **Create environment file**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` and set at minimum:**
   - `POSTGRES_PASSWORD`: A secure database password
   - `PRETALX_SECRET_KEY`: A random secret key (generate with `openssl rand -base64 32`)
   - `PRETALX_SITE_URL`: Your site URL (e.g., `https://pretalx.example.com`)
   - `COMPOSE_PROFILES=local-db`: Keeps the bundled PostgreSQL service enabled (default). Clear the value to use an external database and set `POSTGRES_HOST`.

4. **Start the services**
   ```bash
   docker compose up -d
   ```
   With `COMPOSE_PROFILES=local-db` this launches the bundled PostgreSQL container. If you cleared the profile and set `POSTGRES_HOST`, the stack connects to your external database instead.

5. **Create a superuser**
   ```bash
   docker compose exec web python manage.py createsuperuser
   ```

6. **Access pretalx**
   Open your browser to `http://localhost:8080`

### Using Pre-built Images

Pull the latest image from GitHub Container Registry:

```bash
docker pull ghcr.io/coscup/pretalx:latest
```

Run web server:
```bash
docker run -d -p 8000:8000 \
  -e POSTGRES_PASSWORD=secret \
  -e PRETALX_SECRET_KEY=your-secret-key \
  -e PRETALX_SITE_URL=http://localhost:8000 \
  -v pretalx_data:/data \
  -v pretalx_public:/public \
  ghcr.io/coscup/pretalx:latest web
```

## Configuration

### Environment Variables

See [.env.example](.env.example) for all available configuration options.

#### Database Options
- `COMPOSE_PROFILES=local-db`: Start the bundled PostgreSQL service (default). Clear the value to disable the container and connect to an external database.
- `POSTGRES_HOST`: PostgreSQL hostname (default: `db`). When you disable the bundled database, set this to your external host.
- `POSTGRES_PORT`: PostgreSQL port (default: `5432`)
- `POSTGRES_DB`: Database name (default: `pretalx`)
- `POSTGRES_USER`: Database user (default: `pretalx`)
- `POSTGRES_PASSWORD`: Database password (required)

#### Required Variables
- `POSTGRES_PASSWORD`: Database password
- `PRETALX_SECRET_KEY`: Django secret key
- `PRETALX_SITE_URL`: Public URL of your instance

#### Image Configuration
- `PRETALX_VERSION`: pretalx version to build (tag or branch, default: main)
- `PRETALX_IMAGE`: Use pre-built image instead of building (optional)

#### Gunicorn Configuration
- `GUNICORN_WORKERS`: Number of worker processes (default: 4)
- `GUNICORN_MAX_REQUESTS`: Max requests per worker (default: 1200)
- `GUNICORN_MAX_REQUESTS_JITTER`: Request jitter (default: 50)
- `GUNICORN_FORWARDED_ALLOW_IPS`: Trusted proxy IPs (default: *)

### Volumes

- `pretalx_data`: Application data and logs
- `pretalx_public`: Static and media files (for reverse proxy)
- `postgres_data`: PostgreSQL database
- `redis_data`: Redis data

## Architecture

The Docker Compose setup includes:
- **migrate**: One-time migration service (runs before other services)
- **web**: Gunicorn WSGI server on port 8000
- **worker**: Celery background task worker
- **db**: PostgreSQL 15 database (enabled when `COMPOSE_PROFILES` includes `local-db`)
- **redis**: Redis for caching and Celery

### Using an External PostgreSQL Database

1. Edit `.env`, clear the `COMPOSE_PROFILES` value (or comment it out) so the bundled `db` service is not started.
2. Set `POSTGRES_HOST` (and optionally `POSTGRES_PORT`) to point at your external database.
3. Ensure `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` match the external database credentials.
4. Start the stack with `docker compose up -d`. Docker Compose skips the `db` service automatically, and migrate/web/worker wait until they can connect to the external database.

## Production Deployment

### Using a Reverse Proxy

For production, use a reverse proxy (nginx, Traefik, Caddy) to:
- Serve static files from `/public/static/` and `/public/media/`
- Provide HTTPS/SSL termination
- Handle load balancing if scaling web services

Example nginx configuration is available in [`reverse-proxy-examples/nginx/`](reverse-proxy-examples/nginx/).

### Scaling

Scale web and worker services independently:

```bash
docker compose up -d --scale web=3 --scale worker=5
```

Note: You'll need a load balancer in front when scaling web services.

## Building Custom Images

### Build Locally

```bash
# Build latest main branch
docker compose build

# Build specific version
docker compose build --build-arg PRETALX_VERSION=v2024.1.0
```

### Build Manually

```bash
docker build -t pretalx:custom \
  --build-arg PRETALX_VERSION=main \
  .
```

## Management Commands

```bash
# Create superuser
docker compose exec web python manage.py createsuperuser

# Django shell
docker compose exec web python manage.py shell

# Run migrations manually
docker compose exec web python manage.py migrate

# View logs
docker compose logs -f web
docker compose logs -f worker

# Rebuild frontend assets
docker compose exec web python manage.py rebuild
```

## Available Image Tags

Images are published to `ghcr.io/coscup/pretalx`:

- `latest`: Latest stable build from pretalx main branch
- `main`: Latest commit from pretalx main branch
- `v*`: Specific version releases (e.g., `v2024.1.0`)

## Updating

```bash
# Pull latest image
docker compose pull

# Restart services (migrations run automatically)
docker compose down
docker compose up -d
```

## How It Works

This repository:
1. Clones the [pretalx](https://github.com/pretalx/pretalx) repository at the specified version
2. Builds the Docker image with all dependencies
3. Publishes to GitHub Container Registry via GitHub Actions

The build is triggered:
- Automatically when pretalx repository pushes to main
- On demand via workflow_dispatch
- On tags in this repository

## Support

- [pretalx Documentation](https://docs.pretalx.org/)
- [pretalx Repository](https://github.com/pretalx/pretalx)
- [GitHub Issues](https://github.com/pretalx/pretalx-docker-image/issues)

## License

This Docker configuration is licensed under the Apache License 2.0.
pretalx itself is licensed under the Apache License 2.0.
