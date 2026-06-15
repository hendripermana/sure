# Require blocking quality gates for AFK-ready work

An issue may be marked ready for an AFK agent only when its completion can be
verified by blocking CI gates: schema load and the full Minitest suite on
disposable PostgreSQL 18, Zeitwerk validation, RuboCop, Biome installed through
the frozen pnpm lockfile, Brakeman, and Importmap audit. Managed and self-hosted
smoke coverage plus a small set of critical system journeys are required; static
typing is deferred until the untyped baseline is reliable.
