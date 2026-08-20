# Vietnam Sports Hub

Modular PowerShell-controlled Stremio sports project.

## Control

Run only `Sport.ps1` from the `Sport` directory.

## Architecture

- `Sport.ps1` — single project controller.
- `Modules/` — versioned feature modules (`.psm1`).
- `Shared/` — reusable PowerShell modules.
- `Logs/` — test and runtime logs.

## Development rule

A version module is frozen only after all tests pass. Fixes are made as a new version of the same module; PASS versions are not modified in place.

## V0.2 design principles

- Daily catalog is cache-first.
- Catalog returns minimal preview data only.
- Meta loads only after a user selects a match.
- Stream loads only after playback is requested.
- Live polling starts only while a live match is actively being watched.
- Exiting a match stops live polling but keeps warm metadata cache for a short TTL.
