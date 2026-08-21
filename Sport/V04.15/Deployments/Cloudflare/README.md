# Cloudflare Deployment Boundary

Cloudflare Workers is a deployment target for the V0.4.15 application contracts.

Deployment code must not own Catalog/Meta/Stream business rules; it only exposes the stable runtime interfaces.
