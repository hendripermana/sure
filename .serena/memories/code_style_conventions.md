# Sure Code Style & Conventions

## Ruby Conventions

### General
- **Indentation**: 2 spaces (not tabs)
- **Naming**: `snake_case` for methods/variables, `CamelCase` for classes/modules
- **Line Length**: 120 characters max (follow Rubocop rules)
- **File Organization**: Follow Rails conventions
  - Models: `app/models/`
  - Controllers: `app/controllers/`
  - Views: `app/views/`
  - Components: `app/components/`
  - Jobs: `app/jobs/`
  - Domain collaborators: prefer POROs and concerns under `app/models/`

### Rails Conventions
- **Controllers**: Skinny controllers - business logic belongs in models
- **Models**: Fat models - contain domain business logic
- **Validations**:
  - Simple validations (null checks, unique indexes) in DB
  - ActiveRecord validations for convenience
  - Complex logic and business rules in ActiveRecord
- **ActiveRecord**: Use concerns and POROs for organization

### Authentication Context
```ruby
# ✅ CORRECT
Current.user
Current.family

# ❌ WRONG
current_user
current_family
```

### Documentation
- Add comments only where complex logic is not self-explanatory
- Explain invariants and provider behavior, not line-by-line mechanics

## JavaScript/TypeScript Conventions

### Naming
- `lowerCamelCase` for variables and functions
- `PascalCase` for classes and components
- `UPPER_SNAKE_CASE` for constants

### Code Style
- Use Biome for automated formatting
- 2-space indentation
- Follow the repository's current Biome configuration

### Stimulus Controllers
```javascript
// File: app/javascript/controllers/example_controller.js
// Naming: snake_case filename, registered as a hyphenated Stimulus identifier
export default class ExampleController extends Controller {
  static targets = ["button", "content"];
  static values = { delay: Number };

  connect() {
    // Runs when controller is connected
  }

  disconnect() {
    // Clean up resources here
  }

  #doSomething() {}
}
```

**Best Practices**:
- Keep controllers lightweight (< 7 targets)
- Use private methods for internal logic
- Pass data via `data-*-value` attributes
- Use declarative actions in HTML
- Always cleanup in `disconnect()`

## CSS/Styling Conventions

### TailwindCSS & Design System
- **Always use design tokens** from `app/assets/tailwind/Sure-design-system.css`
- Use functional tokens:
  - `text-primary` instead of `text-white`
  - `bg-container` instead of `bg-white`
  - `border border-secondary` instead of `border border-gray-200`
- **Never create new styles** without permission
- Generate semantic HTML
- Follow mobile-first responsive approach

### Responsive Breakpoints
- Mobile: < 1024px
- Desktop: ≥ 1024px
- Use Tailwind's breakpoint prefixes: `sm:`, `md:`, `lg:`, `xl:`

## ViewComponent Conventions

### When to Use ViewComponent
- ✅ Element has complex logic or styling patterns
- ✅ Element is reused across multiple views
- ✅ Element needs structured styling with variants
- ✅ Element requires interactive behavior (Stimulus)
- ✅ Element has configurable slots or complex API

### When to Use Partials
- ✅ Element is primarily static HTML
- ✅ Element used in only one/few contexts
- ✅ Simple template content
- ✅ Doesn't need variants or complex configuration

### Component Structure
```ruby
# app/components/example_component.rb
class ExampleComponent < ViewComponent::Base
  renders_one :header
  renders_many :items

  def initialize(title:, variant: :default)
    @title = title
    @variant = variant
  end

  private

  def css_classes
    "component-#{@variant}"
  end
end
```

## Testing Conventions

### Framework & Tools
- **Framework**: Minitest (Rails) - NOT RSpec
- **Naming**: `*_test.rb`
- **Fixtures**: Keep minimal (2-3 per model for base cases)
- **Mocks**: Use `mocha` gem
- **External APIs**: Use VCR cassettes

### Testing Philosophy
- Test critical code paths only
- Test commands (verify they were called)
- Test queries (verify output)
- Don't test implementation details
- Keep tests minimal and effective

### Testing Example
```ruby
# ✅ GOOD - Testing critical business logic
test "syncs balances" do
  Holding::Syncer.any_instance.expects(:sync_holdings).returns([]).once
  assert_difference "@account.balances.count", 2 do
    Balance::Syncer.new(@account, strategy: :forward).sync_balances
  end
end

# ❌ BAD - Testing ActiveRecord functionality
test "saves balance" do
  balance = Balance.new(balance: 100, currency: "USD")
  assert balance.save
end
```

## ERB/View Conventions

### Best Practices
- Keep logic minimal (use helpers/components)
- Use semantic HTML
- Use `icon` helper for icons (NOT `lucide_icon` directly)
- Use server-side formatting for dates/currencies/numbers
- Prefer Turbo Frames for partial updates

### Example
```erb
<%# ✅ GOOD: Semantic HTML with helper %>
<%= link_to "Edit", edit_account_path(@account), class: "btn btn-primary" %>
<%= icon("edit") %>

<%# ❌ BAD: Unnecessary JavaScript %>
<button onclick="editAccount()">Edit</button>
<i class="lucide-edit"></i>
```

## Commit & PR Conventions

### Commit Messages
- Imperative mood: "Add feature" not "Added feature"
- Subject ≤ 72 characters
- Reference issues: `#123`
- Include rationale in body

### Pull Requests
- Clear description
- Link related issues
- Screenshots for UI changes
- Migration notes if applicable
- Ensure all tests pass
- Run linting/security scans

## Code Style Enforcement

### Rubocop
- Configuration: `.rubocop.yml`
- Run before PRs: `bin/rubocop -f github -a`
- Covers Ruby and Rails style

### Biome
- Configuration: `biome.json`
- Covers JavaScript, TypeScript, CSS, JSON
- Run before PRs: `npm run lint:fix && npm run format`

### ERB Lint
- Configuration: `.erb_lint.yml`
- Run before PRs: `bundle exec erb_lint ./app/**/*.erb -a`

## Special Conventions

### Hotwire & Turbo
- Use `data-turbo-frame="_top"` to break out of frames
- Listen to `turbo:before-visit` for navigation events
- Allow events to bubble (don't use `stopPropagation()`)

### Background Jobs (Sidekiq)
- Queues: `scheduled`, `high_priority`, `medium_priority`, `low_priority`, `default`
- Use `perform_later` for async jobs
- Handle errors gracefully
- Write idempotent jobs

### Internationalization
- Ignore i18n methods for now
- Hardcode strings in English
- Focus on development speed
