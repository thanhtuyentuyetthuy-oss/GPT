# Vietnam Sports Hub — Cloudflare Workers deployment

This directory is a **new deployment target** for the existing Vietnam Sports Hub contracts. It does not modify the V0.4.x Node addon or its tests.

## Architecture

```text
Stremio / TV
    |
    v
Cloudflare Workers
    |
    +-- /manifest.json
    +-- /catalog/tv/vietnam-sports.json
    +-- /meta/tv/...
    +-- /stream/tv/...
    +-- /health
```

The Worker is self-contained and has **no dependency on a Windows localhost server at runtime**.

The current Worker is intentionally a **public-test deployment**. It exposes the same tested source policy and the current three-event FINISHED catalog snapshot used by the V0.4.13 verification. Production sports data should be connected later only after the source/authorization design is finalized.

## One-time setup on Windows

1. Install/verify Node.js.
2. Log in to Cloudflare from PowerShell:

```powershell
npx wrangler login
```

3. Verify the login:

```powershell
npx wrangler whoami
```

## Deploy

From this directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\Deploy-VietnamSportsHub.ps1
```

Or directly:

```powershell
npx wrangler deploy
```

Wrangler will provision/use the Worker and print its `workers.dev` URL. Use:

```text
https://<worker-url>/manifest.json
```

as the Stremio addon URL.

## Local verification before deploy

Cloudflare's local development server can be used without changing the production addon:

```powershell
npx wrangler dev
```

## CI/CD later

The repository can later auto-deploy this directory from GitHub Actions. Cloudflare's documented CI/CD flow uses `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as GitHub secrets and then runs `wrangler deploy`.
