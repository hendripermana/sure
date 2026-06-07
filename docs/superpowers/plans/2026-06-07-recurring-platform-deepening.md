# Recurring Platform Deepening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify subscription payments, recurring detection, merchant identity, schedules, lifecycle reminders, and transaction reconciliation behind consistent domain interfaces.

**Architecture:** Introduce a schema-compatible `Recurring::Schedule` value object backed by existing `billing_cycle` and JSON metadata. Make `ServiceMerchant` the canonical subscription identity while retaining read-only legacy `Service` compatibility. Trigger scoped reconciliation from committed transaction changes and use the existing audit ledger to deduplicate lifecycle notifications.

**Tech Stack:** Rails 8.1, Active Record, Hotwire/Turbo, Stimulus, Sidekiq, Minitest, PostgreSQL JSONB.

**Status:** Core schedule, service identity, reconciliation, reminder, date
rollover, and lifecycle work shipped in PRs #177 and #178. Theme consistency
items remain follow-up work and intentionally stay unchecked.

---

### Task 1: Canonical Schedule

**Files:**
- Create: `app/models/recurring/schedule.rb`
- Modify: `app/models/subscription_plan.rb`
- Modify: `app/models/recurring_transaction.rb`
- Modify: `app/models/recurring/forecast.rb`
- Test: `test/models/recurring/schedule_test.rb`

- [ ] Define interval units `day`, `week`, `month`, and `year`, with a positive interval count.
- [ ] Preserve legacy cycle names as projections into the canonical schedule.
- [ ] Use one advance operation for subscription renewal and recurring forecast dates.
- [ ] Cover month-end clamping, leap years, daily, weekly, and multi-unit intervals.

### Task 2: Flexible Schedule UI

**Files:**
- Modify: `app/controllers/subscription_plans_controller.rb`
- Modify: `app/views/subscription_plans/_form.html.erb`
- Modify: `app/views/subscription_plans/show.html.erb`
- Modify: `app/helpers/subscription_plans_helper.rb`
- Test: `test/controllers/subscription_plans_controller_test.rb`

- [ ] Accept `interval_count` and `interval_unit` as virtual form attributes.
- [ ] Store custom schedule data in `subscription_plans.metadata`.
- [ ] Render human-readable schedule labels and preserve legacy form submissions.

### Task 3: Canonical Merchant Identity

**Files:**
- Modify: `app/models/subscription_plan.rb`
- Modify: `app/controllers/subscription_plans_controller.rb`
- Modify: `app/controllers/services_controller.rb`
- Modify: `app/views/subscription_mailer/renewal_reminder.html.erb`
- Test: `test/models/subscription_plan_test.rb`
- Test: `test/controllers/subscription_plans_controller_test.rb`

- [ ] Make all new subscription writes target `merchant_id`.
- [ ] Treat `ServiceMerchant` as the service catalog and transaction identity.
- [ ] Retain `Service` only as a legacy read adapter until data migration/removal.
- [ ] Remove user-facing code that assumes `subscription.service`.

### Task 4: Transaction-Triggered Reconciliation

**Files:**
- Create: `app/jobs/reconcile_transaction_job.rb`
- Modify: `app/models/entry.rb`
- Modify: `app/models/recurring/reconciler.rb`
- Modify: `app/models/subscription_plan/renewal_form.rb`
- Test: `test/jobs/reconcile_transaction_job_test.rb`
- Test: `test/models/recurring/reconciler_test.rb`

- [ ] Enqueue reconciliation after committed transaction creation/update.
- [ ] Scope matching to the transaction family/date/account to avoid full-family scans.
- [ ] Prefer explicit `subscription_plan_id`, then merchant identity, then normalized-name evidence.
- [ ] Record anomalies immediately and keep nightly reconciliation as a repair pass.

### Task 5: Lifecycle Reminder Policy

**Files:**
- Create: `app/models/subscription_plan/reminder_policy.rb`
- Modify: `app/jobs/subscription_renewal_job.rb`
- Modify: `app/mailers/subscription_mailer.rb`
- Test: `test/models/subscription_plan/reminder_policy_test.rb`
- Test: `test/jobs/subscription_renewal_job_test.rb`

- [ ] Send renewal reminders at configured 3-day and 1-day milestones.
- [ ] Send trial-ending reminders at 3, 2, and 1 days.
- [ ] Send trial-expired mail when expiry is processed.
- [ ] Deduplicate all messages through audit events rather than mutable ad-hoc flags.

### Task 6: Theme and Date Freshness

**Files:**
- Modify: `app/javascript/controllers/theme_controller.js`
- Modify: `app/views/layouts/_dark_mode_check.html.erb`
- Create: `app/javascript/controllers/current_date_controller.js`
- Modify: `app/views/transactions/_form.html.erb`
- Test: `test/controllers/settings/preferences_controller_test.rb`

- [ ] Make persisted user preference authoritative over localStorage.
- [ ] Resolve `system` from `prefers-color-scheme`.
- [ ] Refresh date input maximums when Turbo-rendered forms connect.

### Task 7: UI and Verification

**Files:**
- Modify: `app/views/subscription_plans/show.html.erb`
- Modify: `app/views/recurring/index.html.erb`
- Modify: relevant controller and system tests

- [ ] Use semantic design tokens for primary payment actions in light and dark themes.
- [ ] Surface schedule, reminder, and reconciliation context in subscription details.
- [ ] Run focused tests, RuboCop, ERB lint, Brakeman, and development smoke tests.
- [ ] Produce UI-first UAT instructions for active payment, paused unexpected renewal, custom schedules, trial reminders, theme, and date rollover.
