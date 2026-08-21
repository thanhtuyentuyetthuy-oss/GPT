# V0.4.15 Adapters

Adapters are responsible for translating external/cache representations into stable internal contracts.

- Catalog adapter: daily schedule/reference input -> Stremio Catalog.
- Meta adapter: selected event -> Stremio Meta.
- Stream adapter: selected event -> authorized Stremio Stream.

Adapters must not decide global runtime polling policy.
