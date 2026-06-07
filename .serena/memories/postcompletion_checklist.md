# Post-Completion Checklist for Sure Tasks

## Before Committing Code

### 1. Testing
- [ ] Run `bin/rails test` - all tests pass
- [ ] Run system tests only if changes affect UI: `bin/rails test:system`
- [ ] No new test failures introduced
- [ ] New features have corresponding tests
- [ ] Edge cases are covered by tests

### 2. Code Quality

#### Ruby/Rails
- [ ] Run `bin/rubocop -f github -a` - fix linting issues
- [ ] Run `bundle exec erb_lint ./app/**/*.erb -a` - fix ERB issues
- [ ] Code follows Rails conventions (skinny controllers, fat models)
- [ ] Use `Current.user` and `Current.family` (not `current_user`/`current_family`)
- [ ] No hardcoded values or magic numbers
- [ ] Comments explain "why" not "what"

#### JavaScript/TypeScript
- [ ] Run `npm run lint:fix` - fix linting issues
- [ ] Run `npm run format` - format code
- [ ] Biome checks pass: `npm run style:check`
- [ ] No console.log statements left in code
- [ ] Stimulus controllers in `app/javascript/controllers/`
- [ ] All event listeners cleaned up in `disconnect()`

#### CSS/Styling
- [ ] Use design system tokens from `Sure-design-system.css`
- [ ] No custom styles added to design system files
- [ ] No hardcoded colors (use functional tokens)
- [ ] Responsive design works on mobile and desktop
- [ ] Dark mode support verified

### 3. Security
- [ ] Run `bin/brakeman --no-pager` - no security issues
- [ ] No secrets committed (use `.env.local`)
- [ ] Strong parameters enforced
- [ ] CSRF protection in place
- [ ] Input sanitization implemented
- [ ] No direct HTML injection without sanitization

### 4. Database Changes
- [ ] Migrations are idempotent
- [ ] Rollback tested: `bin/rails db:rollback`
- [ ] No destructive migrations without review
- [ ] Data migrations properly documented
- [ ] Schema comments added for complex columns

### 5. Performance
- [ ] No N+1 queries (use `includes`, `joins`)
- [ ] Appropriate caching implemented
- [ ] Background jobs used for slow operations
- [ ] Batch processing for large datasets
- [ ] Memory leaks addressed (blob URL cleanup, event listeners)

### 6. Documentation

#### Code Comments
- [ ] Complex logic has explanatory comments
- [ ] New public methods documented
- [ ] Edge cases noted
- [ ] Assumptions documented

#### AGENTS.md & README.md
- [ ] Update AGENTS.md if changes affect development workflow
- [ ] Update README.md if changes affect setup/usage
- [ ] Update existing docs, don't create new .md files
- [ ] ⚠️ **NEVER create new summary/completion documents**

### 7. Breaking Changes
- [ ] Backward compatibility maintained
- [ ] Deprecation warnings added for old APIs
- [ ] Migration guide provided if needed
- [ ] `find_referencing_symbols` used to update all usages

### 8. Component & View Conventions
- [ ] ViewComponents used for complex/reusable UI
- [ ] Partials used for static content only
- [ ] `icon` helper used (not `lucide_icon` directly)
- [ ] Semantic HTML generated
- [ ] Accessibility features included

### 9. Hotwire & Turbo
- [ ] Frames use `data-turbo-frame="_top"` to break out when needed
- [ ] Event listeners allow proper bubbling
- [ ] No `stopPropagation()` blocking navigation
- [ ] `turbo:before-visit` used for cleanup

### 10. API Changes
- [ ] Documented in inline code comments
- [ ] Version number updated if external API
- [ ] Tests updated to match new API
- [ ] Rate limiting considered
- [ ] Error handling improved

## Final PR Checklist

### Before Opening PR
1. [ ] `bin/rails test` - all green
2. [ ] `bin/rubocop -f github -a` - clean
3. [ ] `bundle exec erb_lint ./app/**/*.erb -a` - clean
4. [ ] `npm run lint:fix && npm run format` - clean
5. [ ] `bin/brakeman --no-pager` - no issues
6. [ ] Commit messages follow conventions
7. [ ] No debug code left (console.log, binding.pry, etc.)
8. [ ] Documentation updated (not created)

### When Opening PR
- Clear description of changes
- Link related issues with `Closes #123`
- Screenshots for UI changes
- Note any breaking changes
- Migration instructions if needed
- List of testing done

## Common Mistakes to Avoid

❌ **DON'T:**
- Create new .md files for task summaries
- Use `current_user` or `current_family`
- Add custom styles to design system files
- Leave `console.log` or `binding.pry` in code
- Use `stopPropagation()` in event handlers
- Test ActiveRecord functionality
- Use hardcoded colors instead of design tokens
- Create hardcoded solutions instead of proper implementations
- Skip the security scan (`bin/brakeman`)
- Run system tests unnecessarily (they're slow)

✅ **DO:**
- Update existing documentation files
- Use `Current.user` and `Current.family`
- Use design system tokens (`text-primary`, `bg-container`)
- Remove all debug statements
- Let events bubble properly
- Test critical business logic paths
- Use functional CSS classes
- Find and update all references when changing APIs
- Always run `bin/brakeman --no-pager`
- Run `bin/rails test` and `bin/rails test:system` only when needed

## Indonesian Finance Considerations

When working with Indonesian finance features:
- [ ] Islamic finance compliance respected
- [ ] Personal lending logic correct
- [ ] Pinjol/P2P lending features working
- [ ] IDR formatting correct
- [ ] Local category support working
- [ ] Cultural sensitivity in messages
