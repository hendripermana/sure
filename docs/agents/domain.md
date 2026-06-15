# Domain Docs

Sure uses a single-context documentation layout.

## Required Reading

Before exploring or changing a domain area:

1. Read `CONTEXT.md` at the repository root when it exists.
2. Read relevant decisions under `docs/adr/` when that directory exists.
3. Treat source code, `db/schema.rb`, lockfiles, `AGENTS.md`, and `DESIGN.md` as
   authoritative when documentation conflicts with current behavior.

Missing domain files are not an error. `grill-with-docs` creates them lazily as
terms and durable architectural decisions are resolved.

## Glossary Rules

Use the canonical vocabulary from `CONTEXT.md` in code, tests, issues, and
documentation. Do not introduce synonyms for defined terms. If a required
concept is absent or ambiguous, resolve it through `grill-with-docs` before
making it part of a public contract.

`CONTEXT.md` is only a ubiquitous-language glossary. It must not contain
implementation details, plans, task status, or architectural rationale.

## Architecture Decisions

Durable architectural decisions live under `docs/adr/`. Surface any conflict
with an existing ADR instead of silently overriding it. Create an ADR only when
the decision is hard to reverse, surprising without context, and based on a real
trade-off.
