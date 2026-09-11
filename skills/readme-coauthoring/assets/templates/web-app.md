# project-name

> One-sentence pitch. What does it do, who is it for.

**🌐 [Live demo](https://your-demo.example.com)** • [Documentation](docs/) • [Report a bug](https://github.com/USER/REPO/issues)

![Alt: Screenshot of the app's main dashboard showing the primary user flow](docs/screenshot.png)

[![Build](https://img.shields.io/github/actions/workflow/status/USER/REPO/test.yml?branch=main&style=flat-square)](https://github.com/USER/REPO/actions)
[![Netlify Status](https://api.netlify.com/api/v1/badges/PROJECT-ID/deploy-status)](https://app.netlify.com/sites/SITE/deploys)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

## Why this exists

[2–3 sentences: problem solved, what differentiates it.]

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | React 18 + Vite |
| Styling | Tailwind CSS |
| State | TanStack Query + Zustand |
| Backend | Node 20 + Fastify |
| Database | Postgres 16 |
| Hosting | Vercel (frontend) + Railway (backend) |

## Features

| Feature | Status |
|---|---|
| Real-time collaboration | ✅ Stable |
| Offline mode | 🚧 In progress |
| Mobile responsive | ✅ |
| Dark mode | ✅ |
| i18n | 📅 Planned |

## Run locally

**Prerequisites:** Node 20+, pnpm, Docker (for Postgres).

```bash
git clone https://github.com/USER/REPO
cd REPO
pnpm install
cp .env.example .env       # fill in DATABASE_URL, etc.
docker compose up -d       # starts Postgres
pnpm dev
```

Open http://localhost:3000.

## Deploy

### Vercel

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/USER/REPO)

### Netlify

[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/USER/REPO)

## Architecture

```mermaid
flowchart LR
  U[User] -->|HTTPS| F[Frontend - Vercel]
  F -->|REST| B[Backend - Railway]
  B --> D[(Postgres)]
  B --> Q[Queue - Upstash]
  Q --> W[Worker]
  W --> D
```

Frontend talks to backend over REST. Long-running jobs go through a queue worker. Database is the single source of truth.

## Project structure

```
src/
├── app/          ← routes (file-based)
├── components/   ← shared UI
├── lib/          ← utilities, hooks, API client
└── styles/       ← Tailwind config + globals
```

## Contributing

Issues and PRs welcome.

```bash
pnpm test
pnpm lint
pnpm build
```

## License

[MIT](LICENSE) © 2026 Your Name
