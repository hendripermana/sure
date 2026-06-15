  # Sure Development Guide for AI Agents

  ## Canonical Agent Instructions

  `AGENTS.md` is the single source of truth for repository instructions.
  `CLAUDE.md` and `.github/copilot-instructions.md` must remain symlinks to this
  file so Codex, Claude Code, GitHub Copilot, and other agents follow the same
  engineering rules.

  ### Companion Documents

  - `CONTEXT.md` — canonical domain glossary (ubiquitous language). Use its terms
    in code, tests, issues, and documentation. Do not introduce synonyms.
  - `docs/adr/` — durable architectural decisions. Surface conflicts with existing
    ADRs instead of silently overriding them.
  - `docs/agents/` — agent harness, domain-doc rules, issue-tracker conventions,
    and triage labels. Read `docs/agents/agent-harness.md` for the full execution
    contract and feedback-loop commands.
  - `DESIGN.md` — the authoritative design-system reference for all user-facing work.

  ### Serena Workflow

  - Activate the Sure project and read Serena's initial instructions at session start.
  - Use Serena symbol overview, symbol search, and reference search before broad
    file reads or repository-wide text searches.
  - Keep `.serena/project.yml` aligned with the languages actually used by the app.
  - Treat source code, `db/schema.rb`, dependency lockfiles, `DESIGN.md`, and this
    file as authoritative. Serena memories are supporting context and may be stale.
  - Preserve unrelated changes in a dirty worktree.

  ### Instruction Precedence

  1. User request and repository safety constraints.
  2. This file, `CONTEXT.md`, and `DESIGN.md` for user-facing work.
  3. Relevant decisions under `docs/adr/`.
  4. Existing code patterns and tests.
  5. Serena memories and historical documentation.

  ## ⚠️ CRITICAL: Development Philosophy

  ### Engineering Standard

  Every change must be **durable, grounded, and verified**.

  **Durable** — Code must survive years of evolution. Design for
  maintainability, adaptability, and clarity. Prefer deep domain
  modeling over surface-level fixes. A proper permanent solution
  always beats a fast temporary one.

  **Grounded** — Never guess at APIs, patterns, or behavior.
  Use Context7, Firecrawl, or Exa MCP to verify current
  documentation before writing code. Read existing code patterns
  and `CONTEXT.md` vocabulary before introducing new ones.
  When stuck on a bug, analyze the root cause — never disable
  features, skip tests, or suggest workarounds.

  **Verified** — Every change must pass the full feedback loop
  (see Pre-PR CI Workflow and `docs/agents/agent-harness.md`).
  Work incrementally with small tested changes. Never leave
  code in a broken state. If you cannot verify something works,
  say so explicitly. Always use TDD workflow (`/tdd` skill) for
  implementation work. For UI changes, record E2E verification
  using Playwright or headless Chrome — screenshots or video —
  before declaring work complete.

  **Honest** — State what you know, what you assumed, and what
  you could not verify. Flag uncertainty rather than presenting
  guesses as facts. If a task exceeds your capability or context,
  say so instead of producing plausible-looking but wrong output.

  ## Project Overview

  Sure is a global personal finance product for a household to understand and
  manage its shared financial life while preserving the financial practices of
  the regions in which that household lives. See `CONTEXT.md` for canonical
  domain language and `docs/adr/0012-global-core-with-regional-depth.md` for the
  architectural framing.

  ### Application Modes
  - **Managed**: Sure team operates servers for users (`Rails.application.config.app_mode = "managed"`)
  - **Self Hosted**: Users host on their own infrastructure via Docker Compose (`Rails.application.config.app_mode = "self_hosted"`)

  ## Project Structure & Module Organization
  - **Code**: `app/` (Rails MVC, services, jobs, mailers, components), JS in `app/javascript/`, styles/assets in `app/assets/` (Tailwind, images, fonts)
  - **Config**: `config/`, environment examples in `.env.local.example` and `.env.test.example`
  - **Data**: `db/` (migrations, seeds), fixtures in `test/fixtures/`
  - **Tests**: `test/` mirroring `app/` structure (e.g., `test/models/*_test.rb`)
  - **Tooling**: `bin/` (project scripts), `docs/` (guides), `public/` (static), `lib/` (shared libs)
  - **Components**: `app/components/DS/` (Sure design system ViewComponents — the sole public component API per ADR-0008)
  - **Planning**: `CONTEXT.md` (glossary), `docs/adr/` (decisions), `docs/agents/` (agent harness), `issues/` (issue specs)

  ## Core Domain Model

  The application is built around financial data management with these key relationships:
  - **User** → has many **Accounts** → has many **Transactions**
  - **Family**: Top-level entity containing users, accounts, and preferences
  - **Account** types: checking, savings, credit cards, investments, crypto, loans, properties, personal lending
  - **Transaction** → belongs to **Category**, can have **Tags** and **Rules**
  - **Investment accounts** → have **Holdings** → track **Securities** via **Trades**
  - **Entry**: Base class for transactions, valuations, and trades that modify account balances
  - **Balance**: Daily balance snapshots for accounts

  ### Account Classifications
  **Assets**: Depository, Investment, Crypto, Property, Vehicle, Other Asset
  **Liabilities**: Credit Card, Loan (Person and Institute), Pay Later/BNPL, Personal Lending (borrowing), Other Liability

  ### Regional Coverage (Indonesia / Southeast Asia)
  Indonesia and Southeast Asia are first-class markets, but country-specific
  products must not leak into universal financial invariants (ADR-0012).
  - **Islamic Finance**: Sharia-compliant loans, credit cards, transaction types (Zakat, Infaq/Sadaqah)
  - **Personal Lending**: Qard Hasan, informal lending with tracking and reminders
  - **Fintech Integration**: Pinjol, P2P Lending, PayLater services
  - **Local Categories**: Arisan, Indonesian-specific expense categories

  ## Build, Test, and Development Commands
  - **Setup**: `cp .env.local.example .env.local && bin/setup` — install deps, set DB, prepare app
  - **Run app**: `bin/dev` — starts Rails server and asset/watchers via `Procfile.dev`
  - **Test suite**: `bin/rails test` — run all Minitest tests; add `TEST=test/models/user_test.rb` to target a file
  - **Lint Ruby**: `bin/rubocop` — style checks; add `-A` to auto-correct safe cops
  - **Lint/format JS/CSS**: `pnpm run lint` and `pnpm run format` — uses Biome
  - **Security scan**: `bin/brakeman` — static analysis for common Rails issues

  ### Isolated Test DB (Docker, never touch production DB/volumes)
  - Start disposable Postgres for tests (credentials from `.env`):\
    `sudo docker run --rm -d --name Sure-test-pg -p 5544:5432 -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -e POSTGRES_DB=Sure_test postgres:18`
  - Prepare test DB:\
    `DB_HOST=127.0.0.1 DB_PORT=5544 POSTGRES_USER=$POSTGRES_USER POSTGRES_PASSWORD=$POSTGRES_PASSWORD POSTGRES_DB_TEST=Sure_test POSTGRES_DB=Sure_test RAILS_ENV=test bin/rails db:prepare`
  - Run tests (same env vars):\
    `DB_HOST=127.0.0.1 DB_PORT=5544 POSTGRES_USER=$POSTGRES_USER POSTGRES_PASSWORD=$POSTGRES_PASSWORD POSTGRES_DB_TEST=Sure_test POSTGRES_DB=Sure_test RAILS_ENV=test bin/rails test`
  - Cleanup after: `sudo docker rm -f Sure-test-pg`

  ### Safe Local Testing Workflow
  **ALWAYS ensure `.env.local` is configured correctly before running tests to prevent production DB access:**

  1. **Configure Local Environment**:
     ```bash
     cp .env.local.example .env.local
     # Edit .env.local to set:
     # POSTGRES_DB_DEVELOPMENT=Sure_development
     # POSTGRES_DB_TEST=Sure_test
     # DB_HOST=127.0.0.1 (if running locally against Docker DB)
     ```

  2. **Run Tests Safely**:
     ```bash
     # Explicitly set DB_HOST if needed
     RAILS_ENV=test DB_HOST=127.0.0.1 bin/rails test
     ```

  3. **Troubleshooting "Aborting test database task"**:
     If you see warnings about "pointing to production database":
     - Verify `.env.local` exists and has `POSTGRES_DB_TEST=Sure_test`.
     - Ensure `POSTGRES_DB` env var is NOT set to `Sure_production` in your shell session.
     - Use `RAILS_ENV=test` explicitly.

  ### Pre-Pull Request CI Workflow
  **ALWAYS run these commands before opening a pull request:**
  1. `bin/rails zeitwerk:check` — Autoload verification
  2. `bin/rubocop -f github` — Ruby linting
  3. `pnpm install --frozen-lockfile && pnpm run lint` — JS linting
  4. `bin/brakeman --no-pager` — Security analysis
  5. `bin/importmap audit` — JS dependency audit
  6. `RAILS_ENV=test bin/rails db:schema:load && bin/rails test` — Full test suite (every test, no skips)
  7. For UI changes: record E2E verification via Playwright or headless Chrome (screenshot or video)

  Only proceed with pull request creation if ALL checks pass. "All tests pass"
  means you ran the entire suite and can show the output — never claim green
  without actually running it.

  ## General Development Rules

  ### Authentication Context
  - **Use `Current.user` for the current user. DO NOT use `current_user`**
  - **Use `Current.family` for the current family. DO NOT use `current_family`**

  ### Development Guidelines
  - Prior to generating any code, carefully read the project conventions and guidelines
  - Ignore i18n methods and files. Hardcode strings in English for now to optimize speed of development
  - Do not run `rails server` in your responses
  - Do not run `touch tmp/restart.txt`
  - Do not run `rails credentials`
  - Do not automatically run migrations

  ### Key Conventions
  1. **Minimize Dependencies**: Push Rails to its limits before adding new dependencies
  2. **Skinny Controllers, Fat Models**: Business logic in `app/models/`, avoid `app/services/`
  3. **Hotwire-First Frontend**: Native HTML preferred over JS components
  4. **Optimize for Simplicity**: Prioritize good OOP domain design over performance
  5. **Database vs ActiveRecord Validations**: Simple validations in DB, complex logic in ActiveRecord

  ## Assets, Importmap, and Controllers (Rails 8.1)
  - **Asset pipeline**: Propshaft with Importmap (no bundler). Assets are served from:
    - `app/assets/builds` for Tailwind output (`tailwind.css`)
    - `app/javascript` for app code and Stimulus controllers
    - `vendor/javascript` for third‑party ESM files
  - **Controller loading** (CRITICAL for Rails 8.1):
    - We pin `@hotwired/stimulus-loading` to a local shim at `app/javascript/stimulus-loading.js` via `config/importmap.rb`
    - Custom loading uses `Promise.all` for proper async controller registration
    - `app/javascript/controllers/index.js` eager‑loads controllers with `await` to ensure all controllers load before app initialization
    - **ALL controllers MUST be in `app/javascript/controllers/`** — subdirectory `controllers/DS/` is supported
    - Controllers are registered with hyphenated identifiers: `DS/tabs_controller.js` → `ds--tabs`
  - **After adding controllers or vendor JS**, restart `bin/dev` and consider `bin/rails tmp:cache:clear` if digests look stale

  ## TailwindCSS Design System

  ### Design System Rules
  - **Always reference `app/assets/tailwind/Sure-design-system.css`** for primitives and tokens
  - **Use functional tokens** defined in design system:
    - `text-primary` instead of `text-white`
    - `bg-container` instead of `bg-white`
    - `border border-primary` instead of `border border-gray-200`
  - **NEVER create new styles** in design system files without permission
  - **Always generate semantic HTML**
  - **Always use `icon` helper** in `application_helper.rb`, NEVER `lucide_icon` directly

  ## Component Architecture

  `DS::*` is the sole public component API (ADR-0008). Do not add components
  outside the `DS::` namespace.

  ### ViewComponent vs Partials Decision Making
  **Use DS:: ViewComponents when:**
  - Element has complex logic, styling variants, or interactive behavior
  - Element will be reused across multiple views/contexts
  - Element needs accessibility features or ARIA support

  **Use Partials when:**
  - Element is primarily static HTML with minimal logic
  - Element is used in only one or few specific contexts

  ### Stimulus Controller Guidelines
  **Declarative Actions (Required):**
  ```erb
  <!-- GOOD: Declarative - HTML declares what happens -->
  <div data-controller="toggle">
    <button data-action="click->toggle#toggle" data-toggle-target="button">Show</button>
    <div data-toggle-target="content" class="hidden">Hello World!</div>
  </div>
  ```

  **Controller Best Practices:**
  - Keep controllers lightweight and simple (< 7 targets)
  - Use private methods and expose clear public API
  - Single responsibility or highly related responsibilities
  - **CRITICAL**: ALL Stimulus controllers MUST be in `app/javascript/controllers/` (Rails 8.1 requirement)
  - Subdirectory `app/javascript/controllers/DS/` is used for design-system controllers
  - Pass data via `data-*-value` attributes, not inline JavaScript
  - Avoid `event.stopPropagation()` - let events bubble for Turbo navigation

  ## Coding Style & Naming Conventions
  - **Ruby**: 2-space indent, `snake_case` for methods/vars, `CamelCase` for classes/modules. Follow Rails conventions for folders and file names
  - **Views**: ERB checked by `erb-lint` (see `.erb_lint.yml`). Avoid heavy logic in views; prefer helpers/components
  - **JavaScript**: `lowerCamelCase` for vars/functions, `PascalCase` for classes/components. Let Biome format code
  - **Commit**: Small, cohesive changes; keep diffs focused

  ## Testing Philosophy

  ### General Testing Rules
  - **ALWAYS use Minitest + fixtures** (NEVER RSpec or factories)
  - Keep fixtures minimal (2-3 per model for base cases)
  - Create edge cases on-the-fly within test context
  - Use Rails helpers for large fixture creation needs

  ### Test Quality Guidelines
  - **Write minimal, effective tests** - system tests sparingly
  - **Only test critical and important code paths**
  - **Test boundaries correctly:**
    - Commands: test they were called with correct params
    - Queries: test output
    - Don't test implementation details of other classes

  ### Testing Examples
  ```ruby
  # GOOD - Testing critical domain business logic
  test "syncs balances" do
    Holding::Syncer.any_instance.expects(:sync_holdings).returns([]).once
    assert_difference "@account.balances.count", 2 do
      Balance::Syncer.new(@account, strategy: :forward).sync_balances
    end
  end

  # BAD - Testing ActiveRecord functionality
  test "saves balance" do
    balance_record = Balance.new(balance: 100, currency: "USD")
    assert balance_record.save
  end
  ```

  ### Stubs and Mocks
  - Use `mocha` gem
  - Prefer `OpenStruct` for mock instances
  - Only mock what's necessary

  ### Test Structure
  - **Framework**: Minitest (Rails). Name files `*_test.rb` and mirror `app/` structure
  - **Run**: `bin/rails test` locally and ensure green before pushing
  - **Fixtures/VCR**: Use `test/fixtures` and existing VCR cassettes for HTTP. Prefer unit tests plus focused integration tests

  ## Background Processing

  Sidekiq handles asynchronous tasks:
  - **Account syncing** (`SyncJob`, `SyncAllAccountsJob`, `SyncCleanupJob`)
  - **Import processing** (`ImportJob`, `ImportMarketDataJob`)
  - **AI chat responses** (`StreamingAssistantResponseJob`)
  - **Scheduled maintenance** via sidekiq-cron (`config/schedule.yml`)
  - **Recurring intelligence** (`RecurringIntelligenceJob`)
  - **Subscription lifecycle** (`SubscriptionRenewalJob`)
  - **Regional data** (`GoldPriceFetchJob`, `GoldAutoRevaluationJob`)
  - **Monitoring** (`MemoryMonitoringJob`, `DatabasePoolMonitoringJob`, `CacheMonitoringJob`)

  ### Job Configuration
  - **Queues**: `scheduled`, `high_priority`, `medium_priority`, `low_priority`, `default`
  - **Cron jobs**: Defined in `config/schedule.yml`
  - **Redis**: Required for Sidekiq operation
  - **Monitoring**: Available at `/sidekiq` (production auth required)

  ## API Architecture

  The application provides both internal and external APIs:
  - **Internal API**: Controllers serve JSON via Turbo for SPA-like interactions
  - **External API**: `/api/v1/` namespace with Doorkeeper OAuth and API key authentication
  - **API responses**: Use Jbuilder templates for JSON rendering
  - **Rate limiting**: Via Rack Attack with configurable limits per API key
  - **Authentication**: Session-based for web, OAuth2/API keys for external access

  ### API Development Guidelines
  - Inherit from `Api::V1::BaseController`
  - Use `authorize_scope!("read"|"write")` for permissions
  - Respect API key rate limiting headers
  - Force JSON responses
  - Add comprehensive tests under `test/controllers/api/v1/`

  ## External Services Integration

  ### Plaid Integration
  - **Bank account syncing**: Real-time transaction and balance updates
  - **Transaction import**: Automatic categorization and processing
  - **PlaidItem**: Manages connections and sync operations
  - **Background jobs**: Handle data updates asynchronously

  ### OpenAI Integration
  - **AI chat functionality**: Financial Q&A and insights
  - **Transaction categorization**: Automatic expense/income classification
  - **Financial insights**: Spending analysis and recommendations
  - **Assistant functions**: Structured data queries (balance sheet, income statement)

  ### Stripe Integration
  - **Subscription management**: Billing for managed hosting
  - **Payment processing**: Secure payment handling
  - **Webhook handling**: Real-time subscription updates

  ## Technology Stack

  ### Verified Runtime Baseline (June 6, 2026)
  Verify versions from the runtime and lockfiles before making upgrade decisions.

  - **Ruby**: 3.4.7 (PRISM parser enabled, CVE-2025-61594 fixed)
  - **Bundler**: 2.7.2 (preparing for Bundler 4)
  - **RubyGems**: 3.7.2 (IMDSv2 support)
  - **Rails**: 8.1.3
  - **Node.js**: 24.16.0
  - **PostgreSQL**: 18.x (latest stable)
  - **Redis**: 7.4.x (latest stable)
  - **Turbo Rails**: 2.0.23
  - **Stimulus**: 3.x (Improved event binding)

  ### Rails 8.1 New Features & Changes
  - **Active Job Continuations**: Long-running jobs can be broken into discrete steps for better resilience during deployments
  - **Structured Event Reporting**: Unified interface for producing structured events for logging and monitoring
  - **Schema Format Version 8.1**: Columns now sorted alphabetically in schema dumps by default
  - **Enhanced Turbo Integration**: Better frame handling and error recovery
  - **Improved Performance**: Optimized query execution and caching strategies

  ### Rails 8.1 Breaking Changes from 8.0
  - **Schema Sorting**: `schema.rb` columns are now sorted alphabetically by default (configure with `config.active_record.schema_format_version`)
  - **Event Reporting**: New structured event reporting system for better observability
  - **Stimulus Event Binding**: Arrow functions in event handlers must be properly bound to maintain context
  - **Turbo Frame Handling**: Enhanced error handling for missing frames requires explicit event listeners

  ## Turbo Frame Best Practices (Rails 8.1)

  ### Breaking Out of Turbo Frames

  **Problem**: Links inside Turbo Frames try to load responses inside the frame instead of navigating the full page.

  **Solution**: Use `data-turbo-frame="_top"` to break out of frames for full page navigation:

  ```erb
  <%# In a component inside a Turbo Frame %>
  <%= link_to "Settings", settings_path, data: { turbo_frame: "_top" } %>
  ```

  **When to use `_top`:**
  - Menu items that should navigate to new pages
  - Links inside frames that need full page navigation
  - Any navigation that shouldn't be constrained to the frame

  **Automatic Implementation**:
  ```ruby
  # app/components/DS/menu_item.rb automatically adds _top for menu links
  def merged_opts
    # ...
    if frame.present?
      data = data.merge(turbo_frame: frame)
    else
      # Default to _top frame for menu items to break out of any parent frames
      data = data.merge(turbo_frame: "_top") if variant == :link
    end
    # ...
  end
  ```

  ### Turbo Frame Events

  Always listen to proper Turbo events for menu/modal close behavior:

  ```javascript
  // ✅ GOOD: Listen to turbo:before-visit for navigation
  document.addEventListener("turbo:before-visit", () => {
    if (this.show) this.close();
  });

  // ❌ BAD: Don't intercept turbo:click - let Turbo handle navigation
  // document.addEventListener("turbo:click", (event) => {
  //   event.stopPropagation(); // DON'T DO THIS
  // });
  ```

  ### Rails 8.1 Upgrade Shims (still active)
  - **ActiveSupport::Configurable shim** (`lib/active_support/configurable.rb`): Suppresses deprecation flood from ViewComponent/OmniAuth until upstream gems drop the dependency. Loaded early in `config/boot.rb`.
  - **connection_pool 3.x shim** (`config/boot.rb`): Normalizes positional args to keywords for Sidekiq/Redis. Keep until Sidekiq is fully keyword-safe.

  ### Rails 8 Breaking Changes (from 7.x)
  - **RedisCacheStore Configuration**: Connection pool parameters changed from `pool_size:` and `pool_timeout:` to nested `pool: { size:, timeout: }` format
  - **Query Log Tags**: `verbose_query_logs` replaced with `query_log_tags_enabled`
  - **Puma Worker Boot**: `on_worker_boot` deprecated in favor of `before_worker_boot`

  ### Stack Components
  - **Backend**: Ruby on Rails 8.1.3
  - **Database**: PostgreSQL 18.x with UUID primary keys
  - **Frontend**: Hotwire (Turbo 2.0.23 + Stimulus 3.x)
  - **Styling**: TailwindCSS v4 with Sure design system (`DS::*`, see `DESIGN.md`)
  - **Linting**: Biome 2.4.16 (JavaScript/TypeScript), RuboCop (Ruby), Brakeman 8.0.5 (security)
  - **Testing**: Minitest + fixtures
  - **Jobs**: Sidekiq 8.1.6 + Redis 7.4.x
  - **External APIs**: Plaid, OpenAI, Stripe 19.2.0
  - **Deployment**: Docker support for self-hosting
  - **Package manager (JS)**: pnpm (not npm/yarn)

  ### Key Dependencies
  - **aws-sdk-s3**: 1.224.0 (IMDSv2 support)
  - **rubyzip**: 3.2.2
  - **@biomejs/biome**: 2.4.16

  ### Upgrade Policy
  - Always use latest stable versions
  - Security patches applied immediately
  - Major version upgrades documented in AGENTS.md
  - Run `bundle outdated` and `npm outdated` regularly

  ## Sync & Import System

  Two primary data ingestion methods:
  1. **Plaid Integration**: Real-time bank account syncing
     - `PlaidItem` manages connections
     - `Sync` tracks sync operations
     - Background jobs handle data updates
  2. **CSV Import**: Manual data import with mapping
     - `Import` manages import sessions
     - Supports transaction and balance imports
     - Custom field mapping with transformation rules

  ## Commit & Pull Request Guidelines
  - **Commits**: Imperative subject ≤ 72 chars (e.g., "Add account balance validation"). Include rationale in body and reference issues (`#123`)
  - **PRs**: Clear description, linked issues, screenshots for UI changes, and migration notes if applicable. Ensure CI passes, tests added/updated, and `rubocop`/Biome are clean

  ## Security & Authentication

  ### Security Best Practices
  - **Never commit secrets**: Use `.env.local` for development, environment variables for production
  - **Session-based auth**: For web users with CSRF protection
  - **API authentication**: OAuth2 (Doorkeeper) for third-party apps, API keys with JWT for direct access
  - **Scoped permissions**: System for API access control
  - **Strong parameters**: Throughout application with CSRF protection
  - **Security scanning**: Run `bin/brakeman` before major PRs

  ### Multi-Currency Support
  - All monetary values stored in base currency (user's primary currency)
  - `Money` objects handle currency conversion and formatting
  - Historical exchange rates for accurate reporting
  - Indonesian Rupiah (IDR) support with proper formatting

  ## Performance Optimization

  ### Performance Architecture

  Sure is optimized for blazing-fast performance with comprehensive improvements:

  **Runtime Optimization:**
  - **YJIT Enabled**: 12-40% performance boost via JIT compilation
  - **jemalloc**: 30-40% memory reduction via optimized allocation (system-level, not gem)
  - **Ruby GC Tuning**: Optimized garbage collection parameters

  **Application Server:**
  - **Puma Workers**: 1 per CPU core for true parallelism
  - **Thread Pool**: 3-5 threads per worker for optimal throughput
  - **Preload App**: Memory efficiency via copy-on-write

  **Database Layer:**
  - **Connection Pooling**: Sized for (workers × threads) + Sidekiq + buffer
  - **Query Timeouts**: Statement (15s), connect (5s), lock (10s)
  - **Prepared Statements**: Enabled for better query performance
  - **Slow Query Monitoring**: Automatic detection and alerting

  **Caching Strategy:**
  - **Redis Cache Store**: Distributed caching with compression
  - **Fragment Caching**: For expensive views and calculations
  - **Cache Monitoring**: Hit/miss rates, slow operations
  - **Namespace Isolation**: Multi-tenant cache separation

  **Background Processing:**
  - **Sidekiq Concurrency**: 10-25 threads for optimal throughput
  - **Weighted Queues**: Priority-based job processing
  - **Job Monitoring**: Queue depths, slow jobs, retries

  **Comprehensive Monitoring:**
  - **Sentry APM**: 50% sampling (100% for critical paths)
  - **Database Monitoring**: Slow queries, connection pool usage
  - **Cache Monitoring**: Hit rates, slow operations
  - **External API Monitoring**: Plaid, OpenAI, Stripe performance
  - **Memory Profiling**: Leak detection, GC performance
  - **Background Job Tracking**: Queue depths, slow jobs

  ### Performance Guidelines
  - Use `includes` / `preload` to avoid N+1 queries; use `pluck` for simple data
  - Use `find_each` / `in_batches` instead of `Account.all.each`
  - Use `Rails.cache.fetch` with TTL for expensive calculations
  - Move slow operations to background jobs (`perform_later`)
  - Target <200ms p95 response time, >80% cache hit rate
  - Monitor via Sentry APM, Sidekiq Dashboard (`/sidekiq`), PostgreSQL slow query logs

  ## Security Best Practices (Rails 8.1)

  ### CSS Content Sanitization

  **Always sanitize CSS content before using `html_safe` to prevent XSS attacks:**

  ```ruby
  # ❌ BAD: Direct html_safe without sanitization
  def inline_critical_css(css_content)
    tag.style(css_content.html_safe, type: "text/css")
  end

  # ✅ GOOD: Sanitize CSS content first
  def inline_critical_css(css_content)
    sanitized_content = sanitize_css_content(css_content)
    tag.style(sanitized_content.html_safe, type: "text/css")
  end

  private
    def sanitize_css_content(css_content)
      return "" if css_content.blank?

      # Remove dangerous CSS constructs
      sanitized = css_content
        .gsub(/javascript:/i, "")           # Remove javascript: protocol
        .gsub(/expression\s*\(/i, "")       # Remove IE expression()
        .gsub(/vbscript:/i, "")             # Remove vbscript: protocol
        .gsub(/@import/i, "")               # Remove @import statements
        .gsub(/url\s*\(\s*["']?data:/i, "") # Remove data: URLs
        .gsub(/behavior\s*:/i, "")          # Remove behavior: (IE-specific)

      # Additional validation
      ActionController::Base.helpers.sanitize(sanitized, tags: [], attributes: [])
    end
  end
  ```

  **Key Points:**
  - CSS can contain XSS payloads via `javascript:`, `expression()`, `@import`, etc.
  - Never trust user-provided CSS content
  - Always sanitize before marking as `html_safe`
  - Multiple CVEs exist for CSS-based XSS (CVE-2024-53987, CVE-2024-53988)

  ## Production Monitoring Best Practices (Rails 8.1)

  ### Avoid Custom Monitoring Threads in Initializers

  **Problem**: Custom `Thread.new` in initializers are problematic with Puma's worker forking:

  ```ruby
  # ❌ BAD: Thread.new in initializer (doesn't survive Puma fork)
  if Rails.env.production?
    Thread.new do
      loop do
        sleep 300
        # monitoring code
      end
    end
  end
  ```

  **Solution**: Use Sidekiq Cron jobs for periodic monitoring:

  ```ruby
  # ✅ GOOD: Sidekiq Cron job (production-safe)
  class MemoryMonitoringJob < ApplicationJob
    queue_as :low_priority

    def perform
      return unless Rails.env.production?
      # monitoring code
    end
  end

  # config/schedule.yml
  memory_monitoring:
    cron: "*/5 * * * *" # every 5 minutes
    class: "MemoryMonitoringJob"
    queue: "low_priority"
  ```

  **Benefits:**
  - ✅ Works correctly with Puma's worker forking
  - ✅ Survives server restarts
  - ✅ Can be monitored via Sidekiq dashboard
  - ✅ More reliable than custom threads
  - ✅ Follows Rails/Sidekiq best practices

  **Monitoring Jobs Available:**
  - `MemoryMonitoringJob` - Memory usage and GC stats (every 5 min)
  - `DatabasePoolMonitoringJob` - Connection pool usage (every 1 min)
  - `SidekiqQueueMonitoringJob` - Queue depths and job status (every 1 min)
  - `CacheMonitoringJob` - Cache statistics (every 5 min)

  ## ActiveStorage Best Practices (Rails 8.1)

  ### Preprocessed Variants for Blazing Fast Performance

  **Always use preprocessed variants for frequently accessed images:**

  ```ruby
  # app/models/user.rb
  has_one_attached :profile_image do |attachable|
    # Preprocessed = generated immediately after upload for instant display
    attachable.variant :small, resize_to_fill: [72, 72],
      convert: :webp,
      saver: { quality: 85, strip: true },
      preprocessed: true

    attachable.variant :medium, resize_to_fill: [200, 200],
      convert: :webp,
      saver: { quality: 85, strip: true },
      preprocessed: true
  end
  ```

  ### Use .processed.url for Immediate Variant Generation

  **Always use `.processed.url` instead of `.url` for variants:**

  ```erb
  <%# ❌ BAD: May not display if variant not yet processed %>
  <%= image_tag user.profile_image.variant(:small).url %>

  <%# ✅ GOOD: Uses preprocessed variant with immediate URL generation %>
  <% avatar_url = user.profile_image.attached? ? user.profile_image.variant(:small).processed.url : nil %>
  <%= image_tag avatar_url %>
  ```

  ### Prevent N+1 Queries with Eager Loading

  **Eager load variant records in controllers:**

  ```ruby
  # app/controllers/users_controller.rb
  def set_user
    @user = Current.user
    @user.profile_image.attachment&.blob&.variant_records&.load if @user.profile_image.attached?
  end
  ```

  ### Performance Optimization Tips

  - **Use WebP format**: Smaller file size, better compression
  - **Enable strip: true**: Remove metadata for smaller files
  - **Use preprocessed: true**: For instant display without delays
  - **Lazy loading**: Use `loading: "lazy"` for offscreen images
  - **Async decoding**: Use `decoding: "async"` for non-blocking image decode

  ### Memory Management in JavaScript

  **Always cleanup blob URLs to prevent memory leaks:**

  ```javascript
  // app/javascript/controllers/profile_image_preview_controller.js
  #currentBlobUrl = null;

  disconnect() {
    this.#revokeBlobUrl();
  }

  #revokeBlobUrl() {
    if (this.#currentBlobUrl) {
      URL.revokeObjectURL(this.#currentBlobUrl);
      this.#currentBlobUrl = null;
    }
  }
  ```

  ## Documentation Guidelines

  ### ⚠️ CRITICAL: NO NEW DOCUMENTATION FILES

  **NEVER create new .md files after completing tasks!**

  - ❌ **NEVER** create summary reports, completion reports, or task-specific .md files
  - ❌ **NEVER** create UPGRADE_GUIDE.md, CHANGELOG_*.md, or similar files
  - ❌ **NEVER** create documentation for completed work
  - ✅ **ALWAYS** update existing files only (AGENTS.md, README.md, existing docs/)
  - ✅ **ONLY** create new docs when explicitly requested by user for NEW features

  **After completing ANY task:**
  1. Update AGENTS.md if it affects development workflow
  2. Update README.md if it affects setup/usage
  3. Update inline code comments for complex logic
  4. **DO NOT** create any summary or completion documents

  **Exception:** Only create new documentation when:
  - User explicitly says "create documentation for X"
  - Adding entirely new features that require user guidance
  - Creating API documentation for new endpoints (when requested)

  ## Troubleshooting

  ### Common Issues
  1. **Asset 404s**: Clear cache with `bin/rails tmp:cache:clear`
  2. **Database issues**: Check `config/database.yml`
  3. **Importmap issues**: Restart `bin/dev`
  4. **Test failures**: Check fixtures and test data
  5. **Redis issues**: Ensure Redis is running for Sidekiq

  ### Debugging
  - Use `Rails.logger.debug` for logging
  - Check `log/development.log`
  - Use `binding.pry` for debugging
  - Monitor Sidekiq dashboard for job issues
  - VCR cassettes for external API testing

  ## Important Files

  ### Configuration
  - `config/routes.rb`: Application routes
  - `config/database.yml`: Database configuration
  - `config/application.rb`: Rails configuration
  - `config/importmap.rb`: JavaScript imports
  - `config/schedule.yml`: Sidekiq cron jobs
  - `config/sidekiq.yml`: Queue configuration

  ### Models
  - `app/models/family.rb`: Family entity (top-level)
  - `app/models/user.rb`: User entity
  - `app/models/account.rb`: Account base class
  - `app/models/entry.rb`: Entry base class
  - `app/models/transaction.rb`: Transaction model with Indonesian types
  - `app/models/personal_lending.rb`: Personal lending/borrowing
  - `app/models/loan.rb`: Institutional loans with Islamic finance

  ### Views & Components
  - `app/views/layouts/application.html.erb`: Main layout
  - `app/components/DS/`: Sure design system ViewComponents (sole public component API)
  - `app/helpers/application_helper.rb`: Global helpers (icon helper)

  ### Assets
  - `app/assets/tailwind/Sure-design-system.css`: Design tokens (ALWAYS reference)
  - `app/javascript/controllers/`: Stimulus controllers
  - `app/javascript/application.js`: Main JS entry point

  ### Testing
  - `test/models/`: Model tests
  - `test/controllers/`: Controller tests
  - `test/system/`: System tests (use sparingly)
  - `test/fixtures/`: Test data (keep minimal)

  ## Notes for AI Agents

  When working on this codebase:

  1. **Read `CONTEXT.md`** for canonical domain vocabulary before writing code
  2. **Use `DS::*` components and `DESIGN.md`** for all UI work
  3. **Use `Current.user` and `Current.family`** — never `current_user`/`current_family`
  4. **Always use `icon` helper** in `application_helper.rb` — never `lucide_icon` directly
  5. **Keep controllers skinny** — business logic belongs in models
  6. **Global core, regional depth** — country-specific products must not leak into universal invariants
  7. **Consider both managed and self-hosted modes** in implementations
  8. **Always use TDD** — invoke `/tdd` skill for every implementation task
  9. **Run the full feedback loop** before declaring work complete (see Pre-PR CI Workflow) — show actual test output, never claim passing without running
  10. **Record UI verification** — use Playwright or headless Chrome for E2E evidence on UI changes
  11. **Use pnpm** as the JavaScript package manager — not npm or yarn
  12. **Product identity is Sure** — do not introduce other product names (ADR-0002)

  ### Quick Reference Commands
  ```bash
  # Setup and run
  cp .env.local.example .env.local && bin/setup
  bin/dev

  # Full feedback loop (run before PRs)
  bin/rails zeitwerk:check
  bin/rubocop -f github
  pnpm install --frozen-lockfile && pnpm run lint
  bin/brakeman --no-pager
  bin/importmap audit
  RAILS_ENV=test bin/rails test

  # Debugging
  bin/rails console
  bin/rails tmp:cache:clear
  ```
