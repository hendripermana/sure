# Split Transaction & Transaction Form — Comprehensive Refactor

## Problem Statement
Comprehensive fix of the split-transaction feature + transaction form in the Permoney
(Maybe-fork) Rails app: i18n, styling (DESIGN.md tokens), accessibility, mobile
responsiveness, validation, tests, and JS controller code-quality/perf.

## Stack
Rails 7 (Ruby 3.4.7) · Postgres · Hotwire/Stimulus · Tailwind v4 (tailwindcss-rails) · Propshaft.
Form uses the self-contained "wise-form" design system (DESIGN.md → CSS variables).

## Key Files
- app/views/transactions/_form.html.erb (form template + split section)
- app/javascript/controllers/new_transaction_split_controller.js (split logic)
- app/assets/tailwind/application.css (wise-form styles)
- app/controllers/transactions_controller.rb (create/split logic)
- test/controllers/transactions_controller_test.rb (tests)
- config/locales/views/transactions/en.yml (i18n)

## Implemented (2026-01)
- i18n: all split UI strings moved to en.yml; JS strings injected via Stimulus `i18n` Object value (data attr). No hardcoded user-facing text left in split section.
- Styling: `.wise-split-row-input` polished to DESIGN.md text-input spec (rounded.md 12px, mute placeholder, focus ring); per user decision kept the wise-form CSS-variable token system (DESIGN.md) rather than generic Tailwind tokens.
- Remove button: real `.split-remove-btn` (icon("trash-2"), destructive hover, focus-visible ring, WCAG target size) + title/aria-label, in both template row and JS-added rows.
- Remaining balance indicator: icon (check/alert) + label + amount layout, gentle pulse animation on unbalanced (respects prefers-reduced-motion).
- Mobile: split rows stack on mobile, row layout ≥ md.
- A11y: aria-labels on all split inputs + checkbox + sr-only label; Delete-key removes focused row.
- Validation: real-time empty-field feedback (`wise-split-row-input--error`); server enforces MINIMUM_SPLITS=2 (renders 422 with flash.now alert); failure branch sets flash.now alert.
- JS refactor: named constants (MINIMUM_SPLITS, COLLAPSE_ANIMATION_DURATION_MS, BALANCE_TOLERANCE); memory-leak fixes (bound listeners stored + removed, timeouts cleared on disconnect); reindex via data-field-type; remainingIcon target.
- Category dropdown in split rows: kept custom-select (per user) with cleaner clone (i18n prompt, data-field-type on hidden input).
- Tests: 5 split scenarios (balanced, unbalanced→422, <2 rows→422, inflow negative signs, child independence after parent update).

## Testing Status
- bin/rails test test/controllers/transactions_controller_test.rb → 20 runs, 97 assertions, 0 failures, 0 errors.
- RuboCop (changed ruby): no offenses. erb_lint: clean. ESLint (JS controller): clean. Tailwind build: no warnings.
- NOTE: No full-browser e2e screenshot was run (Rails app has no running preview server / auth session in this env); the error-path tests render the full `_form` partial, validating ERB + icon helper + i18n + JSON data attr render correctly.

## Backlog / Next
- P1: Live browser e2e of the split UI (toggle, add/remove rows, balance turns green, submit) once a dev server + seeded login are available.
- P2: Edit/unsplit flow UX on an existing split transaction.
- P2: Translate new keys into other present locales (currently English only; others fall back).

## Implemented (2026-01) — Split DISPLAY redesign (transactions list + account activity)
- Redesigned split rendering into a cohesive **collapsible card** (`app/views/entries/_split_group.html.erb`):
  - Parent summary header (chevron toggle, merchant logo, name, strong "Split · N" chip, child-category color-dot preview, muted total + tooltip "Excluded from balance — counted across its splits").
  - Hover actions: Edit splits (turbo modal → splits#edit) + Unsplit (DELETE → splits#destroy, confirm).
  - Children connected via dashed vertical connector, indented, with redundant account name removed.
- New Stimulus controller `split_group_controller.js` (collapse/expand, default expanded, chevron rotate, a11y aria-expanded + keyboard enter/space; `stop` guards action clicks).
- Grouping is DEFAULT ON (`user.show_split_grouped?` already true) and now also applied on the **account activity page** (`app/components/UI/account/activity_date.html.erb`).
- `entries_helper#group_split_entries` hardened to skip the standalone parent row when its children are present (safe reuse on account page where parent lives in the same list).
- CSS: color-agnostic collapse animation (`.split-group__children` / `.is-collapsed`, respects reduced-motion). Contrast improved by replacing faded `opacity-50` parent with proper `text-secondary`/`text-primary` tokens (dark-mode safe).
- Tests: added index render test (`split-group` card markup, children, unsplit form). Full suite: 21 transactions tests + 8 accounts tests pass, 0 failures.
- NOTE: still validated via Rails test suite + lint (no live browser screenshot — Rails app has no running preview server/auth session in sandbox; sandbox also resets apt packages between sessions, so Postgres was reinstalled to run tests).
