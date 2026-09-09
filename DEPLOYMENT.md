# Hetzner Deployment

This deploys the current KRB Digital Transformation Assessment Platform as a Dockerized static web app.

## Important Current Limitation

The app is currently static and stores survey links/responses in browser `localStorage`.

That means:

- The app can be reachable from anywhere.
- Each user can open the platform.
- Public survey links can show the right survey template.
- Responses are not yet stored centrally on the server.

For real multi-person survey collection, the next production step is a backend with PostgreSQL and real authentication.

## Server Requirements

Use a small Hetzner VPS:

- Ubuntu 22.04 or 24.04
- Docker
- Docker Compose plugin
- Optional domain pointed to the server IP

## Deploy With Docker Compose

On the server:

```bash
git clone <repo-url> krb-assessment
cd krb-assessment
docker compose up -d --build
```

The app will run on:

```text
http://SERVER_IP:8080
```

## Run On Port 80

If nothing else is using port `80`, edit `docker-compose.yml`:

```yaml
ports:
  - "80:80"
```

Then run:

```bash
docker compose up -d --build
```

The app will run on:

```text
http://SERVER_IP
```

## Domain Setup

Create a DNS `A` record:

```text
assessment.yourdomain.com -> SERVER_IP
```

Then run the app behind a reverse proxy such as Caddy, Nginx, or Traefik.

## Suggested Production Upgrade

To make surveys truly work across users:

1. Add backend API.
2. Add PostgreSQL.
3. Store survey invitations server-side.
4. Store survey responses server-side.
5. Add real admin login.
6. Add email sending.
7. Add OpenAI API analysis.
8. Add KVKK consent and privacy controls.

Kaynak depo: git@github.com:deriveglobal/deriveintelligence.git (dal: master)
