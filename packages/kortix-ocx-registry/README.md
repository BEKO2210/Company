# Kortix OCX Registry

The registry package is intentionally empty for now.

Local first-party skills now live directly in `packages/kortix-opencode/skills/`.

When marketplace-only skills return, this package can be repopulated with installable registry entries.

When that happens again, add source skills under `skills/` and let `scripts/build_registry.py`
rebuild the public registry artifacts. The `sync-registry-artifacts` workflow auto-commits
those generated files on push.
