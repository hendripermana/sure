# Recurring Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Recurring workspace into an operational system that reviews detected patterns, reconciles actual transactions, forecasts future cash flow, records lifecycle history, and alerts users to anomalies.

**Architecture:** Keep `SubscriptionPlan`, `SubscriptionRenewal`, and `RecurringTransaction` as separate domain records. Add deterministic POROs under `Recurring::` that calculate confidence, reconcile entries, build forecasts, record idempotent domain events in `AuditLog`, and deliver anomaly notifications without introducing a parallel source of truth.

**Tech Stack:** Rails 8.1, Active Record, Active Job/Sidekiq, Action Mailer, Hotwire, Minitest.

**Status:** Implemented by PR #178. The checklist is retained as historical
implementation context and a record of the validation scope.

---

### Task 1: Confidence and review workflow

**Files:**
- Create: `app/models/recurring/assessment.rb`
- Modify: `app/models/recurring_transaction.rb`
- Modify: `app/controllers/recurring_transactions_controller.rb`
- Modify: `app/views/recurring_transactions/index.html.erb`
- Test: `test/models/recurring/assessment_test.rb`
- Test: `test/controllers/recurring_transactions_controller_test.rb`

- [ ] Calculate a stable confidence score and expose its evidence.
- [ ] Add explicit confirm-as-recurring and ignore actions.
- [ ] Render confidence and transaction evidence in the review table.
- [ ] Verify controller family scoping and repeated confirmation idempotency.

### Task 2: Reconciliation engine

**Files:**
- Create: `app/models/recurring/event_recorder.rb`
- Create: `app/models/recurring/reconciler.rb`
- Create: `app/jobs/recurring_intelligence_job.rb`
- Modify: `app/models/audit_log.rb`
- Modify: `config/schedule.yml`
- Test: `test/models/recurring/reconciler_test.rb`
- Test: `test/jobs/recurring_intelligence_job_test.rb`

- [ ] Match actual entries by account, merchant/name, currency, date window, and amount.
- [ ] Classify paid, missed, amount changed, duplicate, and unexpected renewal.
- [ ] Link transactions through `Transaction#extra` and renewals through `entry_id`.
- [ ] Use transaction locks and advisory locks to make reruns idempotent.
- [ ] Emit structured Active Support events and Sentry context for failures.

### Task 3: Forecast and budget projection

**Files:**
- Create: `app/models/recurring/forecast.rb`
- Modify: `app/models/budget.rb`
- Modify: `app/controllers/recurring_controller.rb`
- Modify: `app/views/recurring/index.html.erb`
- Test: `test/models/recurring/forecast_test.rb`
- Test: `test/models/budget_test.rb`

- [ ] Generate subscription and recurring-transfer occurrences for a bounded horizon.
- [ ] Exclude occurrences already represented by actual reconciled entries.
- [ ] Expose projected recurring spending to budgets without changing historical actuals.
- [ ] Render a compact 30-day cash-flow forecast.

### Task 4: Lifecycle timeline and notifications

**Files:**
- Modify: `app/models/subscription_plan.rb`
- Modify: `app/models/recurring_transaction.rb`
- Create: `app/models/recurring/notifier.rb`
- Modify: `app/mailers/subscription_mailer.rb`
- Create: `app/views/subscription_mailer/recurring_anomaly.html.erb`
- Modify: `app/controllers/subscription_plans_controller.rb`
- Modify: `app/views/subscription_plans/show.html.erb`
- Test: `test/models/recurring/notifier_test.rb`
- Test: `test/mailers/subscription_mailer_test.rb`

- [ ] Audit lifecycle fields with the existing `AuditableChanges` concern.
- [ ] Show lifecycle and reconciliation events on subscription detail.
- [ ] Send deduplicated renewal, trial, price-change, failed-payment, duplicate, and missed-payment alerts.
- [ ] Keep notification delivery retry-safe.

### Task 5: Verification and operational hardening

**Files:**
- Modify focused tests above.

- [ ] Run focused model, job, controller, and mailer tests against the isolated test database.
- [ ] Run RuboCop and ERB lint on all changed files.
- [ ] Run Brakeman and review warnings related to new endpoints.
- [ ] Browser-test overview, review actions, forecast, timeline, and responsive layout.
