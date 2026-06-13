# Recurring and Subscription Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make recurring identity, Stripe lifecycle ordering, cancellation undo, and recurring transfers concurrency-safe and user-operable.

**Architecture:** Use deterministic database-backed identities for recurring records, provider-authoritative lifecycle commands, monotonic Stripe event application, and validated Transfer pairs for recurring transfers.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL, Hotwire, Minitest, Stripe Ruby.

**Status:** Implemented by PRs #177 and #178. The checklist is retained as
historical implementation context; the migrations were split by domain so
recurring identity and Stripe event tracking can evolve independently.

---

### Task 1: Schema invariants

**Files:**
- Create: `db/migrate/20260606000300_harden_recurring_identity_and_transfers.rb`
- Create: `db/migrate/20260606000400_add_stripe_event_tracking.rb`
- Modify: `app/models/recurring_transaction.rb`
- Modify: `app/models/subscription_plan.rb`

- [ ] Add destination account, recurring identity, and Stripe event cursor columns.
- [ ] Backfill and deduplicate recurring identities.
- [ ] Add unique index, foreign key, and transfer endpoint constraints.
- [ ] Add model callbacks and validations matching database invariants.

### Task 2: Stripe event ordering

**Files:**
- Modify: `app/models/provider/stripe/event_processor.rb`
- Modify: `app/models/provider/stripe/subscription_event_processor.rb`
- Modify: `app/models/subscription_plan.rb`
- Test: `test/models/provider/stripe/subscription_event_processor_test.rb`

- [ ] Pass event ID and created timestamp into subscription synchronization.
- [ ] Reject duplicate or stale events using a deterministic event cursor.
- [ ] Verify newer events apply and stale events preserve current state.

### Task 3: Cancellation undo

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/subscription_plans_controller.rb`
- Modify: `app/models/subscription_plan.rb`
- Modify: `app/views/subscription_plans/_row.html.erb`
- Modify: `app/views/subscription_plans/show.html.erb`
- Test: `test/models/subscription_plan_test.rb`
- Test: `test/controllers/subscription_plans_controller_test.rb`

- [ ] Add `undo_cancellation!`.
- [ ] Add member route and controller action.
- [ ] Render the action only for pending cancellation.
- [ ] Keep local state unchanged when Stripe rejects the request.

### Task 4: Recurring transfers

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/transfers_controller.rb`
- Modify: `app/models/recurring_transaction.rb`
- Modify: `app/views/transfers/show.html.erb`
- Modify: `app/views/recurring_transactions/index.html.erb`
- Test: `test/models/recurring_transaction_test.rb`
- Test: `test/controllers/transfers_controller_test.rb`

- [ ] Create recurring transfers from persisted Transfer pairs.
- [ ] Match occurrences through source/destination Transfer pairs.
- [ ] Expose endpoint data in projections and recurring UI.
- [ ] Prevent transfer candidates from converting to subscriptions.

### Task 5: Verification

- [ ] Prepare a disposable PostgreSQL test database.
- [ ] Run focused tests after every vertical slice.
- [ ] Run combined regression tests.
- [ ] Run RuboCop, ERB lint, Brakeman, and `git diff --check`.
