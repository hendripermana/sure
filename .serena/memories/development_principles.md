# ⚠️ CRITICAL: Development Principles & Quality Standards

## 🚫 ABSOLUTE RULES (NON-NEGOTIABLE)

### NO QUICK FIXES - PERIOD
This is NOT a suggestion. This is MANDATORY for every AI Agent working on Sure.

**NEVER do this:**
- ❌ Temporary workarounds that create technical debt
- ❌ Hardcoded solutions without verification
- ❌ Disabling features when stuck on bugs
- ❌ "Simple fixes" that don't address root causes
- ❌ Solutions not verified against official documentation
- ❌ Skipping tests or linting to "save time"
- ❌ Creating new files/solutions without proper analysis
- ❌ Leaving code in broken state
- ❌ Assuming API compatibility without checking
- ❌ Ignoring deprecation warnings

### ALWAYS do this:
- ✅ Analyze root cause THOROUGHLY
- ✅ Use Context7, Firecrawl, EXA MCP for verification
- ✅ Verify against OFFICIAL documentation
- ✅ Test COMPREHENSIVELY after changes
- ✅ Work INCREMENTALLY with small changes
- ✅ Document complex logic with comments
- ✅ Run pre-PR checks (tests, lint, security)
- ✅ Keep code in WORKING state always
- ✅ Follow Rails/Shadcn/UI latest stable versions
- ✅ Respect AGPL license and attribution

## 🎯 THE QUALITY HIERARCHY (In Order of Priority)

1. **CORRECTNESS** - Code must work correctly
   - No shortcuts
   - Proper error handling
   - Edge cases covered
   - Tested thoroughly

2. **MAINTAINABILITY** - Future developers must understand
   - Clear naming
   - Good documentation
   - Follows conventions
   - Minimal dependencies

3. **PERFORMANCE** - Only optimize proven bottlenecks
   - Profile first
   - Measure results
   - Document optimizations
   - Don't over-engineer

4. **SIMPLICITY** - Choose simplicity over complexity
   - Rails way first
   - Built-in solutions preferred
   - Add dependencies only with strong justification
   - Keep business logic in models

## 🔍 VERIFICATION PROTOCOL

Before submitting ANY code:

1. **Official Documentation Check**
   - Use Context7 MCP for Rails docs
   - Use Context7 MCP for Shadcn/UI docs
   - Check for API changes/deprecations
   - Verify version compatibility

2. **Root Cause Analysis**
   - WHY does this bug exist?
   - WHERE is the actual problem?
   - HOW can we fix it properly?
   - WHAT are we NOT addressing?

3. **Testing Verification**
   - ✅ `bin/rails test` - All tests pass
   - ✅ `bin/rubocop -f github -a` - No lint issues
   - ✅ `bin/brakeman --no-pager` - No security issues
   - ✅ Manual testing in dev environment
   - ✅ Edge cases tested

4. **Code Review Readiness**
   - Clear, descriptive commit messages
   - Proper code formatting
   - Inline comments for complex logic
   - No debug code left behind
   - No console.log or puts statements
   - Follows design system (Tailwind tokens)
   - Uses proper helpers (icon, not lucide_icon)

## ❌ FORBIDDEN PATTERNS

**NEVER commit code with:**
```ruby
# ❌ Temporary fixes
if Rails.env.production?
  # TODO: Fix this later
  result = something_broken rescue "fallback"
end

# ❌ Magic numbers
timeout = 300  # Why 300? Should be configurable

# ❌ Commented out code
# old_implementation_that_might_be_useful_later
# new_implementation

# ❌ Hardcoded values
email = "admin@example.com"
api_key = "sk-1234567890"

# ❌ Insufficient error handling
begin
  risky_operation
rescue
  # Ignore errors silently
end
```

**ALWAYS use:**
```ruby
# ✅ Clear, well-reasoned implementations
SYNC_TIMEOUT = 5.minutes  # Give Plaid time for large accounts
timeout = ENV.fetch("SYNC_TIMEOUT_SECONDS", 300).to_i

# ✅ Proper error handling with context
begin
  account.sync_transactions
rescue Plaid::ApiError => e
  Sentry.capture_exception(e)
  raise SyncError, "Failed to sync account: #{e.message}"
end

# ✅ Verified against documentation
# Per Rails 8.1 docs, use Active Job Continuations for long tasks
SyncAccountJob.perform_later(account_id)
```

## 🧪 TESTING REQUIREMENTS

Every code change MUST have:

1. **Unit Tests** (for business logic)
   - Use Minitest + fixtures (NOT RSpec, NOT FactoryBot)
   - Test critical paths only
   - Mock external dependencies
   - Don't test ActiveRecord basics

2. **Integration Tests** (for workflows)
   - Test boundaries, not implementation
   - Use VCR for external APIs
   - Focus on happy path + critical failures

3. **System Tests** (sparingly)
   - Only for critical user flows
   - Use system tests sparingly (they're slow)
   - Focus on real user scenarios

**Example (GOOD):**
```ruby
test "syncs account transactions" do
  SyncJob.any_instance.expects(:call).returns([]).once

  assert_difference "@account.transactions.count", 2 do
    Account::Syncer.new(@account).sync
  end
end
```

**Example (BAD):**
```ruby
test "transaction model saves" do
  transaction = Transaction.new(amount: 100)
  assert transaction.save  # Testing ActiveRecord, not business logic
end
```

## 📋 PRE-COMMIT CHECKLIST

Before EVERY commit, verify:

- [ ] Code follows Rails/Shadcn conventions
- [ ] All tests pass: `bin/rails test`
- [ ] No lint issues: `bin/rubocop -f github -a`
- [ ] No security issues: `bin/brakeman --no-pager`
- [ ] Design system tokens used (not hardcoded colors)
- [ ] `icon` helper used (not `lucide_icon`)
- [ ] `Current.user` and `Current.family` used (not `current_user`)
- [ ] No hardcoded values (use env vars or constants)
- [ ] No commented-out code
- [ ] No console.log or puts statements
- [ ] Commit message is clear and descriptive
- [ ] No temporary workarounds
- [ ] Complex logic has inline comments
- [ ] ViewComponents used for reusable UI
- [ ] Stimulus controllers kept lightweight (<7 targets)

## 🚨 WHEN YOU'RE STUCK

**NEVER:**
- ❌ Disable the feature
- ❌ Suggest "simple workaround"
- ❌ Give up
- ❌ Leave code in broken state

**ALWAYS:**
- ✅ Take a step back and analyze
- ✅ Use Context7/Firecrawl to research
- ✅ Break problem into smaller parts
- ✅ Try different approaches systematically
- ✅ Document what you've tried
- ✅ Ask for clarification if needed
- ✅ Work incrementally and test after each step
- ✅ Be patient - good solutions take time

## 📚 REQUIRED KNOWLEDGE

Every AI Agent MUST know:
- Rails 8.1 conventions and best practices
- Shadcn/UI latest component patterns
- PostgreSQL 18.x features
- Hotwire (Turbo + Stimulus) architecture
- ViewComponent design patterns
- Minitest testing patterns
- Tailwind CSS design system usage
- Security best practices (XSS, CSRF, etc.)
- Performance optimization guidelines
- Indonesian finance context (Islamic finance, personal lending)

## 🎓 CONTINUOUS LEARNING

For EACH task:
1. Read AGENTS.md thoroughly
2. Check existing patterns in codebase
3. Verify with Context7/Firecrawl MCP
4. Check official documentation
5. Review similar implementations
6. Plan solution before coding
7. Implement incrementally
8. Test comprehensively
9. Document if needed

## ✅ SUCCESS CRITERIA

Code is "done" ONLY when:
1. ✅ Solves the actual problem (root cause)
2. ✅ Follows all project conventions
3. ✅ Has comprehensive tests
4. ✅ Passes all linting/security checks
5. ✅ Uses latest stable versions
6. ✅ Is properly documented
7. ✅ Doesn't create technical debt
8. ✅ Follows Rails/Shadcn best practices
9. ✅ Ready for production
10. ✅ Future-proof

---

**Remember:** Speed is secondary to QUALITY. A perfect solution takes longer, saves time long-term.
