# Recurring and Subscription Integrity Design

## Invariants

Recurring candidates have one deterministic identity per family. The identity
includes source account, optional destination account, merchant or normalized
name, amount, and currency. A database unique index is the final concurrency
guard; model validation only improves error messages.

Recurring transfers are created from a persisted `Transfer`, not inferred from
an isolated transfer-kind transaction. The recurring record stores source and
destination accounts and matches future occurrences through validated Transfer
pairs.

Stripe is authoritative for Stripe-managed lifecycle commands. Local state is
updated only from successful API responses or accepted webhook events.
Webhook events are accepted only when newer than the last applied event.
Events with the same timestamp use their Stripe event ID as a deterministic
tie-breaker.

Scheduled cancellation can be undone. Stripe-managed subscriptions first clear
`cancel_at_period_end` remotely; tracking-only subscriptions clear it locally.

## Data Changes

- `recurring_transactions.destination_account_id`
- `recurring_transactions.identity_signature`
- `subscription_plans.stripe_last_event_created_at`
- `subscription_plans.stripe_last_event_id`

The recurring migration backfills identities, removes duplicate rows using the
existing preference order, then creates a unique family/signature index.
Transfer endpoint check constraints enforce source presence and distinct
accounts.

## UI and Commands

- Subscription rows and details expose `Keep subscription` while cancellation
  is pending.
- Transfer details expose `Mark recurring`; duplicate creation is handled by
  both application lookup and database uniqueness.
- Recurring transfer projections expose both endpoint accounts and cannot be
  converted into a Subscription Plan.

## Verification

Tests cover concurrent identity semantics, stale/equal/new Stripe events,
provider failure behavior, undo cancellation, transfer endpoint validation,
creation from Transfer, matching future pairs, controller authorization, and
rendered lifecycle actions.
