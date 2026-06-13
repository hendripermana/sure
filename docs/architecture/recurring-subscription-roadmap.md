# Recurring and Subscription Architecture

Last reviewed against `we-promise/sure` commit
`172301f875a7699967b675f7c69418b2cbd4442a` from June 6, 2026.

## Product Boundary

Recurring transactions describe observed or expected money movement. A
subscription is a recurring expense with an explicit service lifecycle,
renewal state, and optional provider control.

The recurring engine is the discovery layer. Subscription Manager is the
management layer. Converting a recurring expense into a subscription keeps a
suppression signature so automatic detection does not recreate the candidate.

## Current Capabilities

| Capability | Sure | Community | Notes |
| --- | --- | --- | --- |
| Account-scoped recurring candidates | Yes | Yes | Prevents cross-account pattern merging. |
| Persistent ignore/suppression | Yes | No equivalent | Ignored patterns remain suppressed after later scans. |
| Recurring-to-subscription conversion | Yes | No equivalent | Conversion reuses an existing matching subscription. |
| Transfer exclusion during detection | Yes | Yes | Transfer kinds are filtered in SQL. |
| Recurring transfer source/destination | Yes | Yes | Created from validated Transfer pairs. |
| Debounced post-sync identification | Yes | Yes | Stale jobs and concurrent family runs are gated. |
| Provider-complete sync gate | Yes | Yes | Provider associations are discovered by reflection. |
| Subscription renewal ledger | Yes | No equivalent | Renewal records can link back to transaction entries. |
| Pause/resume lifecycle | Yes | Not applicable | Stripe-managed plans use `pause_collection`. |
| Immediate/period-end cancellation | Yes | Not applicable | Provider failure cannot silently mutate local state. |
| Stripe webhook lifecycle parity | Yes | Not applicable | Status, period end, pause state, and item ID are synced. |
| Stripe webhook idempotency/ordering | Yes | Not applicable | Unique receipts reject duplicates; stale events are retained but ignored. |
| Undo scheduled cancellation | Yes | Not applicable | Provider-authoritative for Stripe plans. |
| Stripe price change correctness | Yes | Not applicable | Updates the subscription item ID, not subscription ID. |

## Remaining Gaps

### P0: Correctness and Data Integrity

- Define provider-neutral lifecycle events and idempotency keys before adding a
  second remotely controlled subscription provider.
- Add operational retention policy for Stripe event receipts.

### P1: Recurring Intelligence

- Replace exact-amount grouping with a confidence model covering amount bands,
  cadence variance, normalized merchant descriptors, and pending/posted
  transaction reconciliation.
- Store detection evidence and confidence so users can understand why a
  candidate was suggested.
- Support weekly, biweekly, quarterly, and annual cadence inference.

### P1: Subscription Operations

- Add provider reconciliation jobs for missed webhooks and stale local state.
- Support scheduled pause/resume dates and provider-specific pause semantics.
- Add price-change previews, proration choice, and effective-date controls.
- Separate observed payment status from service lifecycle in all API responses,
  exports, and analytics.

### P2: Platform Surface

- Add recurring and subscription endpoints to the external API with family
  authorization, pagination, and OpenAPI coverage.
- Add bulk review for detected candidates: confirm, ignore, merge, or convert.
- Add lifecycle audit history for user actions, provider requests, webhook
  events, and reconciliation corrections.
- Add operational metrics for detection duration, candidate yield, suppression
  hit rate, provider failures, and webhook lag.

## Engineering Rule

Community changes are reference material, not an automatic cherry-pick target.
Changes are adopted only when their domain assumptions match this repository,
especially its Subscription Manager, Indonesian finance transaction kinds, and
provider model.
