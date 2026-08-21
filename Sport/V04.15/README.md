# Vietnam Sports Hub — V0.4.15

## New Structure Contract

V0.4.15 starts a new organizational structure without modifying or replacing the frozen V0.4.14 implementation.

### Structure

```text
V04.15/
├── Core/
│   ├── State/
│   └── Runtime/
├── Adapters/
│   ├── Catalog/
│   ├── Meta/
│   └── Stream/
├── Deployments/
│   └── Cloudflare/
├── Contracts/
└── Tests/
```

### Principle

- V0.4.14 and earlier remain frozen.
- New ideas enter through V0.4.15 contracts.
- Adapters transform data; Core owns state/runtime decisions.
- Deployment is separated from application contracts.
- Diagnostics are part of the contract, not an afterthought.
- Catalog, Meta and Stream remain independent stages.
- Stream resolution stays deferred until playback is requested.

This is a structural evolution, not a rewrite of the existing addon.
