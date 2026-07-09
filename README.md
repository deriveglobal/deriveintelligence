# KRB Digital Transformation Assessment Platform

This is the first working version of a reusable digital transformation assessment platform. KRB is the first client/project configuration, but the product is designed to support many organizations, industries, and assessment methodologies.

It currently runs as a lightweight browser and Node backend app with:

- Sign-in/sign-up access gate
- Executive dashboard with maturity score, top problems, heat map, and opportunity matrix
- Stakeholder survey templates
- Working survey workflow with private links, email draft, response capture, response tracking, and AI-style analysis
- Meeting module with AI agent participation, Teams invite generator, `.ics` calendar download, transcript capture, notes, decisions, and action items
- Layered stakeholder map, response tracking, and sentiment analysis
- Creator-only user management with role assignment and credential email workflow
- Local response storage while the database-backed version is being built
- Findings dashboard with AI-style clusters and customer insights
- Opportunities dashboard with impact and effort labels
- Process health and bottleneck dashboard
- Transformation roadmap
- Methodology documentation section with Discovery Framework and bilingual Master Survey Architecture v1
- JSON report export

## Run Locally

Open `index.html` in a browser, or serve the folder:

```bash
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080
```

## Run With Docker

```bash
docker build -t krb-assessment .
docker run -p 8080:80 krb-assessment
```

Then open:

```text
http://localhost:8080
```

## Hetzner VPS Deployment

For details, see `DEPLOYMENT.md`.

Quick deploy on the Hetzner server:

```bash
git clone <repo-url> krb-assessment
cd krb-assessment
docker compose up -d --build
```

The default Docker Compose config exposes:

```text
http://SERVER_IP:8080
```

If the server already uses ports `80` and `443`, keep the app on port `8080` and run it behind an existing reverse proxy:

```bash
docker run -d --name krb-assessment --restart unless-stopped -p 8080:80 krb-assessment
```

Then configure Nginx, Caddy, or Traefik to proxy the domain to `http://127.0.0.1:8080`.

## Product Database Foundation

The reusable SaaS database design is documented in:

```text
docs/DATABASE_DESIGN.md
```

Initial PostgreSQL artifacts:

```text
database/schema.sql
database/seed_methodology.sql
```

## Production Upgrade Path

For the database-backed product version, upgrade in this order:

1. Add backend database: PostgreSQL on Hetzner or Supabase.
2. Add admin authentication and role-based access.
3. Store survey links and responses server-side instead of browser local storage.
4. Add transactional email sending for survey invitations.
5. Add OpenAI API analysis with structured JSON outputs.
6. Add meeting audio capture and transcription with participant consent.
7. Add Microsoft Graph integration to create real Teams meetings and sync transcripts.
8. Add PDF export for owner briefing and final assessment reports.
9. Add customer/employee privacy controls and KVKK-ready consent language.

## Suggested Production Stack

- Frontend: Next.js
- Database: PostgreSQL
- Auth: Auth.js, Supabase Auth, or Keycloak
- AI: OpenAI API structured outputs
- PDF: Playwright or server-side report renderer
- Hosting: Hetzner VPS with Docker Compose
