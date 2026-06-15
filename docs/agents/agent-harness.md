# Sure Agent Harness

This document defines the portable execution contract for engineering agents
working on Sure.

## Authority

Apply guidance in this order:

1. The current user request and repository safety constraints.
2. `AGENTS.md`, including the issue-tracker and domain-doc rules it references.
3. `CONTEXT.md` for canonical domain language.
4. Relevant decisions under `docs/adr/`.
5. `DESIGN.md` for all user-facing behavior and presentation.
6. Current source code, `db/schema.rb`, dependency lockfiles, and tests.
7. Historical notes and Serena memories.

When two sources conflict, surface the conflict and follow the higher authority.

## Grounding Loop

Before changing code:

1. Activate the project in Serena and read its initial instructions.
2. Inspect the worktree and preserve unrelated changes.
3. Read the relevant glossary terms and ADRs.
4. Use Serena symbol overview, symbol search, and reference search before broad
   source reads.
5. Confirm behavior from current code and tests rather than historical prose.
6. Consult current official documentation for external frameworks and APIs.

## Engineering Standards

- Prefer deep domain modules with small stable interfaces.
- Keep financial facts, observed anchors, and rebuildable projections distinct.
- Preserve data provenance and make material corrections auditable.
- Make imports and provider synchronization idempotent.
- Resolve root causes; do not disable behavior to make checks pass.
- Follow existing Rails and Hotwire patterns unless an accepted ADR says
  otherwise.
- Use Minitest, fixtures, and focused behavioral tests.
- Use pnpm as the only JavaScript package manager.
- Use Sure as the product identity. Upstream community changes must be adapted,
  not copied without analysis.
- Preserve a Global Financial Core with explicit Regional Coverage. Indonesia
  and Southeast Asia are first-class markets, but country-specific products,
  labels, providers, and assumptions must not leak into universal financial
  invariants.
- Classify upstream changes as Adopt, Adapt, Reject, Already Ahead, or
  Investigate, and record the evidence and local issue rather than chasing
  commit-count parity.
- Use `DS::*` and `DESIGN.md` as the sole public design system. Do not add
  shadcn-namespaced product components, isolated visual systems, or globally
  floating application controls.

## Feedback Loop

Run focused checks while developing. Before declaring work complete, the
following must pass:

```bash
bin/rails zeitwerk:check
bin/rubocop -f github
pnpm install --frozen-lockfile
pnpm run lint
bin/brakeman --no-pager
bin/importmap audit
```

The database verification environment must use a disposable PostgreSQL 18
instance that cannot access production data or volumes. It must successfully
load the checked-in schema and run the full suite:

```bash
RAILS_ENV=test bin/rails db:schema:load
RAILS_ENV=test bin/rails test
```

CI must also exercise managed and self-hosted smoke coverage and critical system
journeys for sign-in, dashboard access, transaction creation, and account
reconciliation.

Static typing is not currently configured. Do not describe Zeitwerk or linting
as type checking. Evaluate gradual typing separately after the baseline gates
are consistently green.

## AFK Readiness

Apply `ready-for-agent` only when an issue contains:

- canonical domain terminology;
- explicit user-visible behavior and exclusions;
- named architectural boundaries and ownership;
- acceptance criteria at observable seams;
- focused and full-suite verification commands;
- migration, security, and data-integrity constraints;
- no unresolved product decision that requires guessing.

If any of these are missing, use `needs-info`, `needs-triage`, or
`ready-for-human` instead.
