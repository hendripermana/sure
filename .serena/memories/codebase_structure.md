# Sure Codebase Structure

## Directory Layout

```
Sure/
├── app/                          # Application code
│   ├── assets/                   # CSS, images, fonts
│   │   └── tailwind/             # Tailwind CSS files
│   │       └── Sure-design-system.css
│   ├── components/               # ViewComponents
│   ├── controllers/              # Rails controllers
│   │   ├── api/v1/               # External API controllers
│   │   └── concerns/             # Shared controller logic
│   ├── data_migrations/          # Data migration scripts
│   ├── helpers/                  # View helpers
│   ├── javascript/               # JavaScript/TypeScript code
│   │   ├── controllers/          # Stimulus controllers
│   │   ├── application.js        # Main JS entry
│   │   └── stimulus-loading.js   # Controller loading
│   ├── jobs/                     # Sidekiq background jobs
│   ├── mailers/                  # Email templates
│   ├── middleware/               # Custom middleware
│   ├── models/                   # ActiveRecord models
│   │   └── concerns/             # Shared model logic
│   ├── models/                   # Domain models, POROs, and concerns
│   └── views/                    # ERB templates
│       ├── layouts/              # Layout templates
│       └── [controller]/         # Controller-specific views
│
├── config/                       # Configuration files
│   ├── environments/             # Environment-specific config
│   ├── initializers/             # Rails initializers
│   ├── locales/                  # i18n translations
│   ├── application.rb            # Main Rails config
│   ├── boot.rb                   # Boot configuration
│   ├── routes.rb                 # Route definitions
│   ├── importmap.rb              # JS import mappings
│   ├── sidekiq.yml               # Sidekiq configuration
│   ├── schedule.yml              # Cron job schedule
│   ├── database.yml              # Database configuration
│   └── puma.rb                   # Puma server config
│
├── db/                           # Database files
│   ├── migrate/                  # Migrations
│   ├── schema.rb                 # Database schema
│   └── seeds.rb                  # Seed data
│
├── docs/                         # Documentation
│   ├── hosting/                  # Deployment guides
│   ├── api/                      # API documentation
│   ├── onboarding/               # User onboarding guides
│   └── *.md                      # Various guides
│
├── lib/                          # Shared libraries
│   ├── money.rb                  # Money utilities
│   └── ...                       # Other utilities
│
├── public/                       # Static assets
├── scripts/                      # Utility scripts
├── test/                         # Test files
│   ├── fixtures/                 # Test data
│   ├── models/                   # Model tests
│   ├── controllers/              # Controller tests
│   ├── system/                   # System/integration tests
│   └── test_helper.rb            # Test configuration
│
├── bin/                          # Executable scripts
│   ├── dev                       # Start dev server
│   ├── setup                     # Initial setup
│   ├── rails                     # Rails CLI
│   └── ...                       # Other utilities
│
├── vendor/                       # Third-party code
├── Gemfile                       # Ruby dependencies
├── package.json                  # JavaScript dependencies
├── Rakefile                      # Rake tasks
├── Procfile.dev                  # Dev processes
├── Dockerfile                    # Docker configuration
├── compose.yml                   # Docker Compose config
├── .rubocop.yml                  # Rubocop configuration
├── biome.json                    # Biome configuration
├── .erb_lint.yml                 # ERB Lint config
└── README.md                     # Project documentation
```

## Key Directories Explained

### `app/models/`
- **User**: User account and authentication
- **Family**: Top-level grouping for family/household
- **Account**: Bank account, investment, loan, property types
- **Entry**: Base class for transactions, valuations, trades
- **Transaction**: Individual financial transaction
- **Category**: Transaction categorization
- **PersonalLending**: Peer-to-peer lending/borrowing
- **Loan**: Institutional loans with Islamic finance support
- **Holding**: Investment holdings
- **Balance**: Daily account balances
- **PlaidItem**: Plaid bank connection
- **Sync**: Sync operation tracking
- **Import**: CSV import session

### `app/controllers/`
- **Skinny controllers**: Route to model logic
- **API namespace** (`api/v1/`): External API endpoints
- **ViewComponent helpers**: Render components

### `app/components/`
- **Reusable UI components**: ViewComponents
- **Co-located files**: Component class, template, and controller
- Examples: BreadcrumbComponent, FloatingChatComponent, BoxCarouselComponent

### `app/javascript/controllers/`
- **Stimulus controllers**: Interactive behavior
- Naming: `kebab-case` filename → `CamelCase` controller class
- Example: `app/javascript/controllers/example_controller.js` → `ExampleController`

### `config/`
- **Routes**: Define URL routing patterns
- **Database**: PostgreSQL connection pooling
- **Sidekiq**: Background job configuration
- **Schedule**: Cron jobs (every 5 min, hourly, daily, etc.)
- **Environments**: Development, test, production settings

### `db/`
- **Migrations**: Schema changes (never edit directly, run `rails generate migration`)
- **Schema**: Current database structure (auto-generated)
- **Seeds**: Initial data loading

### `test/`
- **Fixtures**: Test data files
- **Unit tests**: Model, controller tests
- **System tests**: Full integration tests (use sparingly)
- **Format**: `*_test.rb` files using Minitest

## Important Files

### Configuration
- `.rubocop.yml` - Ruby linting rules
- `biome.json` - JavaScript/CSS linting
- `.erb_lint.yml` - ERB template linting
- `config/importmap.rb` - JavaScript import mappings
- `.env.local.example` - Environment template

### Assets
- `app/assets/tailwind/Sure-design-system.css` - Design tokens
- `app/javascript/application.js` - Main JS entry point
- `app/javascript/stimulus-loading.js` - Controller loader

### Documentation
- `AGENTS.md` - AI agent guidelines
- `README.md` - Project overview
- `CONTRIBUTING.md` - Contribution guidelines
- `docs/` - Various technical guides

## Database Schema Key Points

- **UUID primary keys** for most tables
- **Soft deletion/archive behavior** varies by domain model; verify schema and model scopes
- **Polymorphic associations** for entries
- **Multi-currency support** with `Money` objects
- **Audit trail** for sensitive operations
- **Indexes** on frequently queried columns
- **Foreign key constraints** for referential integrity

## External Services Integration

- **Plaid**: Bank account syncing and transactions
- **OpenAI**: AI chat and transaction categorization
- **Stripe**: Managed-hosting billing plus optional SubscriptionPlan lifecycle synchronization
- **AWS S3**: Document/attachment storage
- **Sentry**: Error tracking and APM
- **Redis**: Caching and Sidekiq jobs

## Development Workflow

1. Create feature branch from `main`
2. Make atomic, testable commits
3. Run `bin/rails test` locally
4. Run linting: `bin/rubocop -A`, `npm run lint:fix`
5. Run security scan: `bin/brakeman --no-pager`
6. Create pull request
7. Merge after CI passes and review approved
