## [0.18.9](https://github.com/hendripermana/permoney/compare/v0.18.8...v0.18.9) (2026-05-24)

### Other Changes

- ci: enhance pipeline to pnpm node24 and fix dependabot validations (4db3bda6)

## [0.18.8](https://github.com/hendripermana/permoney/compare/v0.18.7...v0.18.8) (2026-02-08)

### Other Changes

- Merge pull request #113 from hendripermana/feature/ui-ux-overhaul (f616370e)
- Harden asset load paths (d87b43c3)
- Fix Tailwind asset precompile (111b58c4)

## [0.18.7](https://github.com/hendripermana/permoney/compare/v0.18.6...v0.18.7) (2026-02-08)

### Other Changes

- Merge pull request #112 from hendripermana/feature/ui-ux-overhaul (05606961)
- chore: remediate false positive secret detection in template (834d6239)
- chore: update brakeman to 8.0.2 to fix CI failure (b33eb006)
- chore: fix linting and formatting issues (1fc70264)
- feat(ui): complete UI/UX overhaul with modern design system (0ff95609)

## [0.18.6](https://github.com/hendripermana/permoney/compare/v0.18.5...v0.18.6) (2026-01-30)

### Other Changes

- Merge pull request #111 from hendripermana/feature/community-updates-jan2026 (fdbcbf6f)
- Use entry date in reports breakdown (ec9a729f)
- Fix lint whitespace and update Brakeman (e8808b25)
- Implement community updates (AI cache, mobile chat, UX) (84569be7)

## [0.18.5](https://github.com/hendripermana/permoney/compare/v0.18.4...v0.18.5) (2026-01-25)

### Other Changes

- Merge pull request #110 from hendripermana/feat/perf-optimizations-jan2026 (1c751387)
- Performance optimizations: N+1 fixes, cache improvements, composite index, safe testing (34a91be4)

## [0.18.4](https://github.com/hendripermana/permoney/compare/v0.18.3...v0.18.4) (2026-01-25)

### Other Changes

- Merge pull request #109 from hendripermana/feat/gold-fx-valuation (5f9a3de3)
- Fix precious metal ledger entries (ef307d5d)
- Fix precious metals create and 4-decimal precision (2332cef9)

## [0.18.3](https://github.com/hendripermana/permoney/compare/v0.18.2...v0.18.3) (2026-01-25)

### Bug Fixes

- fix: resolve syntax error in precious metals controller test (9cb23d31)
- fix: address code review issues for precious metals (24621f5d)

### Refactoring

- refactor: consolidate form initialization and add missing validations (40f2abc4)

### Other Changes

- Merge pull request #108 from hendripermana/feat/gold-fx-valuation (a1563da5)
- style: auto-correct linting issues with rubocop (314698a8)
- test: add comprehensive error message verification for precious metals controller (32837fc9)
- test: add error message verification for precious metals controller (a029bba0)
- fix(security): upgrade lodash from 4.17.21 to 4.17.23 to resolve prototype pollution vulnerability (b903e4fb)
- Fix provider form and gold initial purchase flow (e881a756)

## [0.18.2](https://github.com/hendripermana/permoney/compare/v0.18.1...v0.18.2) (2026-01-24)

### Other Changes

- Merge pull request #107 from hendripermana/feat/gold-fx-valuation (2a529b80)
- Fix form state controller lint (c39853f5)
- Add complete precious metal and provider directory system implementation (8816d8b6)
- Harden gold valuation edge cases and tests\n\n- Add comprehensive tests for FX conversions with multiple currencies\n- Test nil-safe behavior when FX rates are missing\n- Test validation for invalid currency codes\n- Verify no FX call when currencies match (optimization)\n- Handle ConversionError and UnknownCurrencyError gracefully\n- Edge case: blank manual_price returns nil estimated value\n- Edge case: missing target currency defaults to family currency\n- All edge cases tested and verified (6b67eefc)
- Add FX-backed gold valuation using shared Money exchange (396b1cd1)

## [0.18.1](https://github.com/hendripermana/permoney/compare/v0.18.0...v0.18.1) (2026-01-13)

### Other Changes

- Merge pull request #106 from hendripermana/fix/floating-ai-chat-layout-and-cable (c7f4161e)
- Harden ActionCable config and docs (11c397f5)
- Fix floating chat layout and interactions (f8a420b2)

## [0.18.0](https://github.com/hendripermana/permoney/compare/v0.17.5...v0.18.0) (2026-01-12)

### Features

- feat: prefill rules from category prompt (92b570e1)
- feat: highlight current month in trends table (6b9e5544)
- feat: add API categories and sync endpoints (89352f14)
- feat: store account institution details (e4e8eb4c)
- feat: add rules import/export support (97a4b216)
- feat: reconcile pending syncs and improve market data (6523af99)

### Bug Fixes

- fix: align exchange rate provider lookback (8a2706d0)
- fix: harden rule import JSON parsing (65f11581)

### Documentation

- docs: log rule prefill integration (1a5bbe65)
- docs: mark print stylesheet integration (98328a4c)
- docs: mark mobile UX and trends highlight integrations (08e73952)
- docs: log API categories and sync integration (2e8d6b4b)
- docs: update Sure integration progress (6f21093b)
- docs: refresh Sure integration latest commit (8f10d34a)
- docs: update Sure integration progress (876ee752)
- docs: map Sure integration commits (382298b9)

### Other Changes

- Merge pull request #105 from hendripermana/sure-community-catchup (aaf7dfca)
- Add local Docker build support for testing before merge (749b5ede)
- Fix rubocop linting errors (a788f19e)
- Fix security vulnerabilities and bugs from code review feedback (ed271959)
- Record Sure catch-up commit mapping (6006a616)
- Complete Sure community catch-up (916e6ff2)
- Update Sure integration summary for rule enhancements (e1a8dda8)
- Cover rule enhancements in tests (198694d6)
- Add rule filters and exclude action (4cafca0d)
- Catch up Sure community integration work (b216e662)
- Document Sure integration commit mapping (3fdcf8f5)
- Enhance SimpleFIN relink UI and balances sync (ebfee9c4)
- Fix import confirmation product name interpolation (6eb63a82)
- fix(currency): resolve linked account balance currency mismatch issue (d4f7d735)
- fix(rules): prevent disabled rules from executing during automatic sync (f1d9655c)
- feat(rules): implement run all rules with execution history tracking (3d04421a)
- feat(simplefin): integrate Sure community Phase 1 - critical stability fixes (09829b47)

## [0.17.5](https://github.com/hendripermana/permoney/compare/v0.17.4...v0.17.5) (2025-12-20)

### Other Changes

- Merge PR #104: Apply community updates and refresh Permoney icons (0d63490f)
- Apply community updates and refresh icons (dbbe1d43)

## [0.17.4](https://github.com/hendripermana/permoney/compare/v0.17.3...v0.17.4) (2025-12-16)

### Other Changes

- Merge pull request #103 from hendripermana/fix/security-compliance-v2 (317037ed)
- fix(security): upgrade dompurify to 3.2.4 to resolve CVEs [skip ci] (435be9d4)

## [0.17.3](https://github.com/hendripermana/permoney/compare/v0.17.2...v0.17.3) (2025-12-16)

### Bug Fixes

- fix: chat reliability, navigation and formatting [skip ci] (23d878d1)

### Other Changes

- Merge pull request #102 from hendripermana/fix/security-compliance-v2 (44bb3d02)
- fix(js): robust controller refactor (scoping, null checks, crash prevention) [skip ci] (8a7c29ad)
- fix(security): switch to dompurify for sanitization and robustify timeout [skip ci] (c91551b8)
- fix(security): enabling sanitize:true, fixing timeout logic and simplifying ui toggle [skip ci] (de6fc9ed)

## [0.17.2](https://github.com/hendripermana/permoney/compare/v0.17.1...v0.17.2) (2025-12-15)

### Bug Fixes

- fix: Authenticate WebSocket connection with session cookie (#99) (672445e3)

## [0.17.1](https://github.com/hendripermana/permoney/compare/v0.17.0...v0.17.1) (2025-12-15)

### Other Changes

- Merge pull request #98 from hendripermana/fix/chat-deployment-lint (8fa2d194)
- style: Fix Biome formatting in chat_streaming_controller (4c841cdd)

## [0.17.0](https://github.com/hendripermana/permoney/compare/v0.16.26...v0.17.0) (2025-12-15)

### Features

- feat: Chat AI Modernization & Fixes (4a619bd8)

### Bug Fixes

- fix: Address PR feedback (dd6a25a4)

### Other Changes

- Merge pull request #97 from hendripermana/feature/chat-ai-modernization (ccd19d82)

## [0.16.26](https://github.com/hendripermana/permoney/compare/v0.16.25...v0.16.26) (2025-12-14)

### Other Changes

- Merge pull request #96 from hendripermana/fix/chat-response-flow (dbcc4f24)
- Fix linting errors and format code with Biome (45146e84)
- Implement AI Review suggestions: MutationObserver, Security fixes, and Polish (d4589078)
- Fix AI chat response flow: resolve DOM conflicts between JS streaming and Turbo Morphing (e5f833ae)

## [0.16.25](https://github.com/hendripermana/permoney/compare/v0.16.24...v0.16.25) (2025-12-07)

### Bug Fixes

- fix: Handle missing profile images gracefully after R2 migration (087a8047)

### Performance

- perf: Use .url instead of .processed.url for avatar (af71633f)

### Other Changes

- Merge pull request #95 from hendripermana/fix/profile-image-file-not-found (6368dc4f)

## [0.16.24](https://github.com/hendripermana/permoney/compare/v0.16.23...v0.16.24) (2025-12-07)

### Other Changes

- Merge pull request #94 from hendripermana/fix/menu-turbo-morph-cleanup (e2837bef)
- refactor(ui): Address AI code review suggestions for menu controller (83c5109c)
- fix(ui): Resolve menu button regression after transaction creation in Rails 8.1 (2430ee71)

## [0.16.23](https://github.com/hendripermana/permoney/compare/v0.16.22...v0.16.23) (2025-12-07)

### Documentation

- docs: Simplify R2 initializer comments (abf53ba5)

### Other Changes

- Merge pull request #93 from hendripermana/feature/cloudflare-r2-integration (9f7405f5)
- fix(security): Address AI code review suggestions (3636bab2)
- feat(storage): Enable Cloudflare R2 for Active Storage with receipt attachments (ab0d5ff4)

## [0.16.22](https://github.com/hendripermana/permoney/compare/v0.16.21...v0.16.22) (2025-12-07)

### Other Changes

- Add Redis memory monitoring and guard streaming assistant with test (6954ffdc)

## [0.16.21](https://github.com/hendripermana/permoney/compare/v0.16.20...v0.16.21) (2025-12-07)

### Other Changes

- Guard streaming assistant messages against blank content (6292679f)
- Document connection_pool compatibility shim (749a0c6a)

## [0.16.20](https://github.com/hendripermana/permoney/compare/v0.16.19...v0.16.20) (2025-12-06)

### Other Changes

- Harden connection_pool shim for Sidekiq/Redis compatibility (01b6a666)

## [0.16.19](https://github.com/hendripermana/permoney/compare/v0.16.18...v0.16.19) (2025-12-06)

### Other Changes

- Fix connection_pool shim recursion and support positional args (e4e8b382)

## [0.16.18](https://github.com/hendripermana/permoney/compare/v0.16.17...v0.16.18) (2025-12-06)

### Other Changes

- Guard connection_pool patch to prevent recursion (3d3bb3fb)

## [0.16.17](https://github.com/hendripermana/permoney/compare/v0.16.16...v0.16.17) (2025-12-06)

### Other Changes

- Patch connection_pool init early during boot (fb82eecf)

## [0.16.16](https://github.com/hendripermana/permoney/compare/v0.16.15...v0.16.16) (2025-12-06)

### Other Changes

- Fix connection_pool keyword compatibility for Redis cache (3199d84b)

## [0.16.15](https://github.com/hendripermana/permoney/compare/v0.16.14...v0.16.15) (2025-12-06)

### Other Changes

- Merge pull request #86 from hendripermana/chore/test-db-docs (1664cad9)
- Stabilize loan payable tests with fixed dates (5242f716)
- Document isolated test DB flow and harden subscriptions (bed7be89)

## [0.16.14](https://github.com/hendripermana/permoney/compare/v0.16.13...v0.16.14) (2025-12-06)

### Other Changes

- Fix DS::Menu controller - store direct element references (48dc4f26)

## [0.16.13](https://github.com/hendripermana/permoney/compare/v0.16.12...v0.16.13) (2025-12-06)

### Other Changes

- Fix subscription table menu stacking and add clickable rows (a74161fe)

## [0.16.12](https://github.com/hendripermana/permoney/compare/v0.16.11...v0.16.12) (2025-12-06)

### Other Changes

- Fix edit subscription 500 error - add to_combobox_display to ServiceMerchant (a01407f7)

## [0.16.11](https://github.com/hendripermana/permoney/compare/v0.16.10...v0.16.11) (2025-12-06)

### Other Changes

- Improve subscription dashboard UI inspired by shadcnstudio (#85) (a7301830)

## [0.16.10](https://github.com/hendripermana/permoney/compare/v0.16.9...v0.16.10) (2025-12-05)

### Other Changes

- Add subscription analytics dashboard with wave charts and utility categories (a43de58a)

## [0.16.9](https://github.com/hendripermana/permoney/compare/v0.16.8...v0.16.9) (2025-12-05)

### Other Changes

- Fix service avg_monthly_cost currency display (#84) (2edcf4c0)

## [0.16.8](https://github.com/hendripermana/permoney/compare/v0.16.7...v0.16.8) (2025-12-05)

### Other Changes

- Improve subscription manager: alphabetical sorting, currency fix, duplicate detection (#83) (c4eae297)

## [0.16.7](https://github.com/hendripermana/permoney/compare/v0.16.6...v0.16.7) (2025-12-05)

### Other Changes

- Improve service dropdown to show all services with pagination (#82) (420f1c50)

## [0.16.6](https://github.com/hendripermana/permoney/compare/v0.16.5...v0.16.6) (2025-12-03)

### Other Changes

- Fix subscription service dropdown and add searchable combobox with logos (#81) (a2c9f124)

## [0.16.5](https://github.com/hendripermana/permoney/compare/v0.16.4...v0.16.5) (2025-12-01)

### Other Changes

- Merge pull request #80 from hendripermana/subscription-manager-manual-payments-20251201 (7527df90)
- Enhance subscription payment linking with grace period, confirmation dialogs, and comprehensive tests (72ce40b0)
- Tighten subscription payment linking with amount tolerance (3f8519cf)
- Link subscriptions with manual transactions and improve subscription manager UI (8ac0d022)

## [0.16.4](https://github.com/hendripermana/permoney/compare/v0.16.3...v0.16.4) (2025-11-30)

### Bug Fixes

- fix: Make service_id nullable on subscription_plans (e492f6c4)

## [0.16.3](https://github.com/hendripermana/permoney/compare/v0.16.2...v0.16.3) (2025-11-30)

### Bug Fixes

- fix: Subscription form FK violation and services category title wrapping (8dc5a0cc)

## [0.16.2](https://github.com/hendripermana/permoney/compare/v0.16.1...v0.16.2) (2025-11-30)

### Bug Fixes

- fix: Currency defaulting and modal UX for services (8d4e9276)

## [0.16.1](https://github.com/hendripermana/permoney/compare/v0.16.0...v0.16.1) (2025-11-30)

### Bug Fixes

- fix: Use DS::Dialog instead of non-existent DS::Modal for services views (5847f9a6)

## [0.16.0](https://github.com/hendripermana/permoney/compare/v0.15.0...v0.16.0) (2025-11-30)

### Features

- feat: Merge Service into Merchant, fix Brandfetch logos, remove recurring remnants (139282c4)
- feat: Improve subscription form consistency and add Services management (b54b6448)

## [0.15.0](https://github.com/hendripermana/permoney/compare/v0.14.0...v0.15.0) (2025-11-30)

### Features

- feat: Add Subscription Manager to navigation (c1064117)

## [0.14.0](https://github.com/hendripermana/permoney/compare/v0.13.13...v0.14.0) (2025-11-30)

### Features

- feat: Add subscription manager feature (6a04cbea)

### Bug Fixes

- fix: Address security and null safety issues from PR review (c0c24569)

### Other Changes

- Merge pull request #79 from hendripermana/feature/subscription-manager (418036be)

## [0.13.13](https://github.com/hendripermana/permoney/compare/v0.13.12...v0.13.13) (2025-11-28)

### Other Changes

- Auto-heal stale syncs and clear sync banner cache on refresh (62b359c6)

## [0.13.12](https://github.com/hendripermana/permoney/compare/v0.13.11...v0.13.12) (2025-11-28)

### Other Changes

- Force full rebuild start from opening anchor; retry if calc empty (e91ede2e)

## [0.13.11](https://github.com/hendripermana/permoney/compare/v0.13.10...v0.13.11) (2025-11-23)

### Other Changes

- Merge pull request #78 from hendripermana/feature/balance-audit-and-mocks (7e8a4358)
- Namespace advisory lock for balance materializer (ef58edfb)
- Add balance audit job and harden sync safeguards (4cd3b4da)

## [0.13.10](https://github.com/hendripermana/permoney/compare/v0.13.9...v0.13.10) (2025-11-23)

### Other Changes

- Guard windowed balance materialization when anchor missing (1e174c4f)

## [0.13.9](https://github.com/hendripermana/permoney/compare/v0.13.8...v0.13.9) (2025-11-23)

### Other Changes

- HOTFIX: Fix blank content validation error in streaming job (984e5960)

## [0.13.8](https://github.com/hendripermana/permoney/compare/v0.13.7...v0.13.8) (2025-11-23)

### Other Changes

- HOTFIX: Fix importmap paths for Action Cable - CRITICAL #3 (21fca680)

## [0.13.7](https://github.com/hendripermana/permoney/compare/v0.13.6...v0.13.7) (2025-11-23)

### Other Changes

- HOTFIX: Add @rails/actioncable to importmap - CRITICAL (cf27a232)

## [0.13.6](https://github.com/hendripermana/permoney/compare/v0.13.5...v0.13.6) (2025-11-23)

### Other Changes

- HOTFIX: Fix Action Cable import - CRITICAL PRODUCTION BUG (7c834498)

## [0.13.5](https://github.com/hendripermana/permoney/compare/v0.13.4...v0.13.5) (2025-11-23)

### Other Changes

- Merge pull request #77 from hendripermana/fix/onboarding-loop-and-streaming-chat-improvements (e0bf3c3a)
- Fix linting: Add missing semicolons in channels files (bdbd7458)
- Fix 4 critical issues from code review (research-based) (d8758b5c)
- Add conditional console logging for production security (30016ead)
- Fix onboarding loop, floating chat z-index, and enable real-time streaming (d2c5705e)

## [0.13.4](https://github.com/hendripermana/permoney/compare/v0.13.3...v0.13.4) (2025-11-22)

### Other Changes

- Merge pull request #76 from hendripermana/feature/enhance-floating-ai-chat (de48bf65)
- Fix broadcast methods with async and null safety (2789887f)
- Enhance floating AI chat with real-time streaming and mobile UX improvements (f040cb8b)

## [0.13.3](https://github.com/hendripermana/permoney/compare/v0.13.2...v0.13.3) (2025-11-22)

### Other Changes

- Fix Chat Production Errors: 400 Bad Request & Turbo Frame Issues (#75) (ab401f09)

## [0.13.2](https://github.com/hendripermana/permoney/compare/v0.13.1...v0.13.2) (2025-11-22)

### Other Changes

- Improve Chat AI Feature: Error Handling & Generic Provider Support (#74) (1acbf905)

## [0.13.1](https://github.com/hendripermana/permoney/compare/v0.13.0...v0.13.1) (2025-11-22)

### Other Changes

- Merge pull request #73 from hendripermana/feature/dashboard-period-sync-and-ui-improvements (3e9f4aa7)
- Apply code review feedback: optimize redundant method calls and add safe navigation (3ac7f1b9)
- Implement community improvements: dashboard period sync and UI enhancements (b2348d93)

## [0.13.0](https://github.com/hendripermana/permoney/compare/v0.12.1...v0.13.0) (2025-11-22)

### Features

- feat: Add UI for linking/unlinking providers and locale updates (b542670c)
- feat: Add unlink accounts functionality (Controllers & Models) (fe89c4f0)
- feat: Ruby 3.4.7 compatibility and PWA overflow fix (ad00b8db)

### Other Changes

- Merge pull request #72 from hendripermana/feature/community-improvements (5dc8b90e)
- test: Update flash notice expectation for account deletion (21896b22)

## [0.12.1](https://github.com/hendripermana/permoney/compare/v0.12.0...v0.12.1) (2025-11-21)

### Other Changes

- chore: Remove temporary diff file (7ed50997)

## [0.12.0](https://github.com/hendripermana/permoney/compare/v0.11.8...v0.12.0) (2025-11-21)

### Features

- Feat: Manual Recurring Transactions (#71) (0a58664d)

## [0.11.8](https://github.com/hendripermana/permoney/compare/v0.11.7...v0.11.8) (2025-11-21)

### Other Changes

- Merge pull request #70 from hendripermana/fix/recurring-cleanup-turbo (f79ab46b)
- Add compose override for local hotfix builds (49e1b2cb)
- Ensure DS::Link uses turbo method for non-GET links (c081e276)

## [0.11.7](https://github.com/hendripermana/permoney/compare/v0.11.6...v0.11.7) (2025-11-21)

### Other Changes

- Reduce sync health cache TTL for fresher banner (cc5757c3)

## [0.11.6](https://github.com/hendripermana/permoney/compare/v0.11.5...v0.11.6) (2025-11-21)

### Other Changes

- Merge pull request #69 from hendripermana/fix-sync-refresh-and-posthog (bb2c4414)
- Fix sync-all refresh UX and stabilize version checker (2000059f)

## [0.11.5](https://github.com/hendripermana/permoney/compare/v0.11.4...v0.11.5) (2025-11-21)

### Other Changes

- Fix sync health refresh button and restore PostHog require (2d86df3a)

## [0.11.4](https://github.com/hendripermana/permoney/compare/v0.11.3...v0.11.4) (2025-11-20)

### Other Changes

- Implement PostHog proxy to bypass ad blockers (#68) (611a5904)

## [0.11.3](https://github.com/hendripermana/permoney/compare/v0.11.2...v0.11.3) (2025-11-20)

### Other Changes

- Fix HTML escaping in PostHog partial (#67) (d4bc8158)

## [0.11.2](https://github.com/hendripermana/permoney/compare/v0.11.1...v0.11.2) (2025-11-19)

### Other Changes

- Fix PostHog initializer: require gem and use correct client instantiation (#66) (30850f57)

## [0.11.1](https://github.com/hendripermana/permoney/compare/v0.11.0...v0.11.1) (2025-11-19)

### Other Changes

- Implement Sure Commits (Nov 19) (#65) (8a12a960)

## [0.11.0](https://github.com/hendripermana/permoney/compare/v0.10.1...v0.11.0) (2025-11-19)

### Features

- feat: implement commits from we-promise/sure (#279 #307) and setup Biome+Ultracite (1ceea4f6)

### Bug Fixes

- fix: biome linting and formatting issues (73ccd947)
- fix: set fetch-depth to 0 in publish workflow to ensure git describe finds tags (96d1484f)

### Other Changes

- Merge pull request #64 from hendripermana/feature/implement-we-promise-sure-commits (f52b7da3)
- Merge pull request #63 from hendripermana/fix/publish-fetch-depth (6d179029)

## [0.10.1](https://github.com/hendripermana/permoney/compare/v0.10.0...v0.10.1) (2025-11-19)

### Bug Fixes

- fix: sync version.rb with release v0.10.0 and fix release workflow regex (66a6b49d)

### Other Changes

- Merge pull request #62 from hendripermana/fix/version-sync-and-regex (4f5bdc35)

## [0.10.0](https://github.com/hendripermana/permoney/compare/v0.9.7...v0.10.0) (2025-11-19)

### Features

- feat: implement auto-versioning and changelog generation (8a201947)
- feat: Support name-based recurring transactions - upstream 3611413 (e0720c4f)
- feat: Add admin-only settings sections and role-based access (a8f5afc) (7c02ed7a)
- feat: PWA - Responsive menu positioning for desktop/mobile (b533a9b) (a9f0e5ac)
- feat: Move Plaid test env vars to test setup/teardown (e065c98) (506f3551)
- feat: Implement dynamic fields batch update to fix race condition (a0c28c20)
- feat: Add change password functionality in settings (0ef06459)

### Bug Fixes

- fix: Transaction UI responsive layout and merchant display (b284508) (c686e7d7)
- fix: prevent double render in turbo redirects (cb588d64)
- fix: clean manual sync script lint (6cf6f3ae)
- fix: Add optimistic balance update to DELETE to prevent stale balance (5fca35ad)
- fix: CRITICAL - Remove invalid turbo_stream.action(:refresh) causing 500 error (207e68de)
- fix: Use turbo:refresh instead of redirect to prevent stale balance flicker (025614ae)
- fix: Remove optimistic updates, match Sure community approach (best practice) (92f597d4)
- fix: Simplify sync to Sure community approach - remove cache-based debouncing (230b96b4)
- fix: CRITICAL - Valuations must SET balance, not apply as flow (Sure community approach) (0d0e35d2)
- fix: Sync debouncing race condition and modal glitch on transaction create (b4f0ea30)
- fix: Use proper Turbo redirect for instant transaction list update (d77a3212)
- fix: CRITICAL - Correct entry amount sign convention in optimistic balance updates (4fa18825)
- fix: Correct flows_factor convention in optimistic balance updates (2f0f72b2)
- fix: Remove PostgreSQL generated column updates from optimistic balance code (041a33d4)
- fix: Remove trailing whitespace from entryable_resource.rb (7ffc065b)
- fix: Remove trailing whitespace from transactions_controller.rb (28f747c8)
- fix: Complete optimistic balance updates for all transaction operations (7dc5f0f7)
- fix: Make expand_window_if_needed public to fix NoMethodError (55ea7c6d)
- fix: Implement sync debouncing and optimistic balance updates (0d53cd78)
- fix: Remove trailing whitespace from entryable_resource.rb (3d03920e)

### Documentation

- docs: Add critical fix verification and deployment guide (e1775132)
- docs: Add deployment instructions for v0.9.7 release (311298dc)

### Other Changes

- Merge pull request #61 from hendripermana/feat/auto-versioning-and-changelog (076ddffb)
- chore: enhance security and compliance for release workflows (6dbc9abb)
- Merge pull request #60 from hendripermana/sync-health-and-ux-guard (d179e417)
- Fallback to full balance recalculation when no anchor for windowed sync (2d9606f4)
- Merge pull request #59 from hendripermana/sync-health-and-ux (4f783e39)
- Improve sync stability, UX feedback, and dashboard health banner (bed868be)
- Merge pull request #58 from hendripermana/feature/csv-dedup-enhancements (fe40d1a0)
- Limit non-cash flows to loan accounts and update CSV duplicate names (a992b2db)
- Integrate CSV dedup and stabilize tests (3d07ff4f)
- Merge pull request #57 from hendripermana/feature/upstream-sync-4-commits (f35cf899)
- Merge pull request #56 from hendripermana/feature/reports-dashboard (b7737973)
- Fix google_sheets_instructions route path in transactions breakdown view (f7c5176f)
- Merge pull request #55 from hendripermana/feature/reports-dashboard (ad0ba210)
- Fix hash access in transactions breakdown view (462bff77)
- Merge pull request #54 from hendripermana/feature/reports-dashboard (8493c3ac)
- Fix reports view data structure - use category objects as keys (a0dc36cc)
- Merge pull request #53 from hendripermana/feature/reports-dashboard (b265d53c)
- Security hardening: CSV injection protection, HTTPS API enforcement, rate limiting, and secret leakage warnings (894395d7)
- feat(reports): implement comprehensive reporting dashboard with budget tracking (8d37ffab)
- Enable Sentry cron monitoring patches (f981a422)
- Improve balance sync safety and monitoring config (9e667e5f)
- Fix change password link on profile page (8313f78e)
- Remove outdated optimization and testing documentation for server performance and balance calculation fixes (3de018ec)
- Delete BACKGROUND_JOB_OPTIMIZATION_2025_11_09.md (01672281)

# Changelog

## [0.9.7](https://github.com/hendripermana/permoney/compare/v0.9.6...v0.9.7) (2025-11-09)


### Features

* Implement optimistic balance update for instant transaction deletion UX ([#optimistic-update](https://github.com/hendripermana/permoney/commit/COMMIT_HASH))
  - Transaction deletion now updates balance instantly (< 100ms) without flickering
  - Async sync job ensures accurate final balance
  - Improves user experience with smooth, professional UI updates
* Optimize server configuration for 4 CPU 24GB RAM production environment ([#server-optimization](https://github.com/hendripermana/permoney/commit/COMMIT_HASH))
  - Reduce RAILS_MAX_THREADS from 8 to 5 (industry best practice for stability)
  - Adjust DB_POOL from 52 to 45 (right-sized for new thread configuration)
  - Separate Redis databases: Sidekiq (db=1) and Cache (db=2) for better isolation
  - Result: Better stability, resource efficiency, and predictable performance


### Bug Fixes

* Fix CacheMonitoringJob Redis::ConnectionPool class reference error ([#cache-monitoring-fix](https://github.com/hendripermana/permoney/commit/COMMIT_HASH))
  - Correct `Redis::ConnectionPool` to `ConnectionPool` (connection_pool gem)
  - Cache monitoring now works properly, providing metrics every 5 minutes
* Update production.rb SSL configuration for Caddy reverse proxy ([#ssl-config](https://github.com/hendripermana/permoney/commit/COMMIT_HASH))


### Documentation

* Add comprehensive background job optimization guide (BACKGROUND_JOB_OPTIMIZATION_2025_11_09.md)
* Add detailed server configuration analysis for 4 CPU 24GB RAM (SERVER_OPTIMIZATION_4CPU_24GB_RAM.md)


### Performance

* Transaction deletion: 2-3 second delay → <100ms instant update (95% improvement)
* Cache monitoring: Fixed (was broken)
* Server thread contention: Reduced (8 threads → 5 threads)
* Memory efficiency: 7.8GB/24GB usage (excellent headroom)
* Sidekiq health: 99.67% success rate (maintained)

## [0.9.6](https://github.com/hendripermana/permoney/compare/v0.9.5...v0.9.6) (2025-11-08)


### Features

* Add privacy toggle to KPI cards so sensitive metrics can be hidden on shared screens ([a331143](https://github.com/hendripermana/permoney/commit/a331143e5860ee7b36a60d5bbbb1d2f0a32054c4))
* Add fluid typography to KPI card values for better readability across breakpoints ([f627588](https://github.com/hendripermana/permoney/commit/f627588a09393a6c05befc578f4c50add94b20a3))
* Deliver F1-level performance tuning on Rails 8.1 (faster queries, leaner Turbo) ([8c57ef9](https://github.com/hendripermana/permoney/commit/8c57ef9334dc9fdf1f1b5b8deb0a7b0c9773e0ee))
* Comprehensive Docker + Tailwind v4.1.8 optimizations for production builds ([33dc785](https://github.com/hendripermana/permoney/commit/33dc78576d4f9c62c731fc2fd302dd25a9819f27))


### Bug Fixes

* Ensure Pagy 43 pagination helpers load correctly on Rails 8.1 ([bd50a56](https://github.com/hendripermana/permoney/commit/bd50a56c7bead410aeb495701a6e23827bab3af9))
* Upgrade Pagy integration and controllers to the new API to unblock /transactions ([996b643](https://github.com/hendripermana/permoney/commit/996b6436c24022f43a154583f606860cf00e62fb))
* Fix API namespace autoloading / lint issues that broke CI ([d511cd4](https://github.com/hendripermana/permoney/commit/d511cd46caa844b4db87837022159d64fc467522))
* Harden Docker logging, cleanup, and image pinning for stable deploys ([ef80cf3](https://github.com/hendripermana/permoney/commit/ef80cf369c664b038c391c820f41210fa332621c), [5a9d117](https://github.com/hendripermana/permoney/commit/5a9d117ecfd9de0b5b6b5d76488ab8f2c0eedc25))
* Resolve lint/security noise (Rubocop, Brakeman, build warnings) to keep CI green ([fb93039](https://github.com/hendripermana/permoney/commit/fb9303925a5079304cb6fa94bb9573ad710a4623), [2431fa2](https://github.com/hendripermana/permoney/commit/2431fa2e5937fb560ea87aaef06c3cc51656fe49))

## [0.9.5](https://github.com/hendripermana/permoney/compare/v0.9.4...v0.9.5) (2025-11-04)


### Bug Fixes

* Resolve production blockers for Rails 8 + Puma 6 ([c102840](https://github.com/hendripermana/permoney/commit/c1028407e7023260255c0ab4fcde800a2487a510))

## [0.9.4](https://github.com/hendripermana/permoney/compare/v0.9.3...v0.9.4) (2025-11-04)


### Bug Fixes

* Simplify Docker build and fix asset precompilation ([785bc83](https://github.com/hendripermana/permoney/commit/785bc83cacb18cede7a7b3375f7bdfbfc03af432))
* Suppress database warnings during asset precompilation ([892d1cd](https://github.com/hendripermana/permoney/commit/892d1cd18371b74fece285defc775e6a3dfc359c))

## [0.9.3](https://github.com/hendripermana/permoney/compare/v0.9.2...v0.9.3) (2025-11-04)


### Bug Fixes

* Update Ruby to 3.4.7 and Bundler to 2.7.2 in Dockerfile ([e0eecde](https://github.com/hendripermana/permoney/commit/e0eecdec74144e2d02b244161bf06d5333cd5150))

## [0.9.2](https://github.com/hendripermana/permoney/compare/v0.9.1...v0.9.2) (2025-11-04)


### Bug Fixes

* Add missing Sentry mock methods and loan validations ([e00b485](https://github.com/hendripermana/permoney/commit/e00b485f4901efa1cd6f779ccabbf9f7a167472e))
* Correct syntax error in loan form component test ([6fa9cad](https://github.com/hendripermana/permoney/commit/6fa9cada2fe0d6e76e4207ab5876a078b05d4eca))
* Decouple Docker build from test suite ([dcdfd13](https://github.com/hendripermana/permoney/commit/dcdfd13fa95e3c57d7f00253aae05fbe3907bfe4))
* Use hardcoded Node version instead of node-version-file ([538eeb9](https://github.com/hendripermana/permoney/commit/538eeb97379eccb284a26d667f329a6646d0d31f))

## [0.9.1](https://github.com/hendripermana/permoney/compare/v0.9.0...v0.9.1) (2025-11-04)


### Bug Fixes

* Apply linting fixes for CI/CD pipeline ([ba7b28f](https://github.com/hendripermana/permoney/commit/ba7b28f707da1b27db517c610a245748c862bd88))
* Update brakeman ignore and fix Sentry mock for tests ([03f5978](https://github.com/hendripermana/permoney/commit/03f5978a39add0c6b70d4fc9cf8588dd797db58b))

## [0.9.0](https://github.com/hendripermana/permoney/compare/v0.8.2...v0.9.0) (2025-11-04)


### Features

* Add comprehensive PayLater/BNPL system with Indonesian provider support ([da0d923](https://github.com/hendripermana/permoney/commit/da0d923feb4d176c50017830d722942387783e83))
* Add comprehensive PayLater/BNPL system with Indonesian provider… ([c002b42](https://github.com/hendripermana/permoney/commit/c002b429685c34f1e6d1a1fd53cc150bf34987a5))


### Bug Fixes

* Address Kodus AI bot review feedback for PayLater system ([3c1809e](https://github.com/hendripermana/permoney/commit/3c1809edb27bd7df3d669a0c9c706748cf36276f))

## [0.8.2](https://github.com/hendripermana/permoney/compare/v0.8.1...v0.8.2) (2025-11-03)


### Bug Fixes

* Correct database names from 'sure' to 'permoney' ([1793119](https://github.com/hendripermana/permoney/commit/1793119edad4a07bbd3f1c9036c724699c291fca))
* database setup and migrations ([baadad5](https://github.com/hendripermana/permoney/commit/baadad5fca7dc7745210c4b87c7d689d1d6873fc))
* mass assignment security warnings in PayLaterController ([3a70bcc](https://github.com/hendripermana/permoney/commit/3a70bcc0f494ef62564a008fc92d1ef82818920d))
* Replace deprecated Windows platforms with :windows ([0e5f747](https://github.com/hendripermana/permoney/commit/0e5f747dd7902314b78b8c4434ba4e5ea7ed5fd4))
* Replace deprecated Windows platforms with :windows ([f04f62f](https://github.com/hendripermana/permoney/commit/f04f62fa360bce3c40aa0e3989a509f81c2255f9))
* Update database schema after running migrations ([23feb9c](https://github.com/hendripermana/permoney/commit/23feb9cedd593fabce2016f50b5f93b42c3b3a52))

## [0.8.1](https://github.com/hendripermana/permoney/compare/v0.8.0...v0.8.1) (2025-11-03)


### Bug Fixes

* Remove empty matrix strategy from reusable workflows ([a2a862e](https://github.com/hendripermana/permoney/commit/a2a862e6c93ec8871e55a3d7a0f3b90d3ca3d30a))

## [0.8.0](https://github.com/hendripermana/permoney/compare/v0.7.0...v0.8.0) (2025-11-03)


### Features

* Add modern Breadcrumb component with icon support ([c001bbe](https://github.com/hendripermana/permoney/commit/c001bbeec2b4f1e3f831a533e2bc15c0fefee1d0))
* Add modern KPI cards to dashboard with real-time metrics ([937ea76](https://github.com/hendripermana/permoney/commit/937ea767663555df7030203378ec4b8ac2a4421f))
* Enhance breadcrumb navigation with icon support ([b049316](https://github.com/hendripermana/permoney/commit/b0493169756663eb40002e25dc2175387ae302c3))
* Sync upstream sure updates and configure CI/CD ([bd67e61](https://github.com/hendripermana/permoney/commit/bd67e613e4e8a08cc078530c9703e6e804530ed0))


### Bug Fixes

* Improve import system security and personal loan handling ([559d0f6](https://github.com/hendripermana/permoney/commit/559d0f602c0e37d9c4032c5c9792d02eb6d652a9))

## [0.7.0](https://github.com/hendripermana/permoney/compare/v0.6.0...v0.7.0) (2025-10-31)


### Features

* implement comprehensive performance optimization ([a1d0b3c](https://github.com/hendripermana/permoney/commit/a1d0b3ca1cc1f0263d4b25a9d8984ff2bd988dec))


### Bug Fixes

* resolve Rails 8 compatibility issues ([7de44e7](https://github.com/hendripermana/permoney/commit/7de44e792b747ebfd4d8b9a290cfbe109780fc18))
* use Puma single mode in development to avoid macOS fork issues ([3a5f2df](https://github.com/hendripermana/permoney/commit/3a5f2dffe4647c60620e2027650c08b1f4822d69))
* use system jemalloc instead of deprecated gem ([bf15343](https://github.com/hendripermana/permoney/commit/bf15343f2df1a8c39ab2fcb9ee482e637f7fdf37))

## [0.6.0](https://github.com/hendripermana/permoney/compare/v0.5.0...v0.6.0) (2025-10-19)


### Features

* add database restore script and documentation ([29e6991](https://github.com/hendripermana/permoney/commit/29e6991a82bac3e3fd1daba8e9a308ab781a0947))


### Bug Fixes

* Check user's theme preference during page load ([#156](https://github.com/hendripermana/permoney/issues/156)) ([6a5c85f](https://github.com/hendripermana/permoney/commit/6a5c85f109939368a0a22588526df3c61819c72b))

## [Unreleased]

### Added - Upstream Sync v0.6.4

- **Langfuse AI Tracking Integration** - Track AI chat sessions and users for better monitoring
- **Account Reset with Sample Data** - Quick demo setup and testing workflow
- **Invite Codes Deletion** - Ability to delete unused invite codes
- **New Date Format Options** - Added 10-year period view and new date formats
- **AI Debug Mode** - Exposed AI_DEBUG_MODE for better development experience
- **Codex Environment Script** - Added bin/codex-env for Codex integration
- **Docker Image Tagging** - Tag latest image on release for better versioning

### Improved - Upstream Sync v0.6.4

- **Password Reset UX** - Added back button for better user flow
- **Theme Preference** - Fixed theme check on page load to prevent flash
- **Selection Bar Styles** - Improved contrast and semantic token usage
- **Plaid Configuration** - Added dummy credentials for better onboarding
- **LLM Context** - Cleaned up cursor rules for better AI context

### Security - Upstream Sync v0.6.4

- **rexml** - Bumped from 3.4.1 to 3.4.2 (security vulnerability patch)

### Documentation - Upstream Sync v0.6.4

- **Upstream Sync Strategy** - Comprehensive integration documentation
- **Interactive Tools** - Added bin/upstream-sync and bin/analyze-upstream-commits
- **Integration Guides** - Detailed manual integration and quick start guides
- **Completion Report** - Full analysis and results documentation

### Maintenance - Upstream Sync v0.6.4

- **Code Quality** - Auto-fixed 414 rubocop offenses
- **Orphaned Assets** - Removed unused SVG assets for cleaner repository

### Notes

This release integrates 16 upstream improvements from we-promise/sure (v0.6.4) while preserving ALL Permoney features:

- ✅ Loan Management System (fully preserved)
- ✅ Personal Lending System (fully preserved)
- ✅ Pay Later/BNPL System (fully preserved)
- ✅ Indonesian Finance Features (fully preserved)
- ✅ Permoney Branding (fully preserved)

See `docs/UPSTREAM_SYNC_COMPLETION_REPORT.md` for detailed integration report.

## [0.5.0](https://github.com/hendripermana/permoney/compare/v0.4.1...v0.5.0) (2025-10-19)

### Features

- add loan reminders job and enhance loan schedule options in forms ([f1624c7](https://github.com/hendripermana/permoney/commit/f1624c771b5bd44d8827fd74e779a5b04a6ca139))
- add rate suggestion text and logic for display based on sharia, personal, or institutional modes ([cfe82d2](https://github.com/hendripermana/permoney/commit/cfe82d28347c1f03cd1b3d9f56560dc95662a7f4))
- add tooltips and helper for loan form fields, and existing loan toggle in the form component. ([fbb209d](https://github.com/hendripermana/permoney/commit/fbb209dd0e3e07a628800e2c5e57456b294e393c))
- enhance loan feature with comprehensive improvements ([4fc6631](https://github.com/hendripermana/permoney/commit/4fc66311f587f4604592ac71d61d2b71071a14a4))
- enhance loan form with smart UX improvements ([939d7e6](https://github.com/hendripermana/permoney/commit/939d7e6069c87ee6bcc837b691910eb5b8d151bf))
- enhance select and collection_select methods with better config handling and include_blank support ([ef622d8](https://github.com/hendripermana/permoney/commit/ef622d8676fe69957fe63dcef3f689ef1a069de8))

### Bug Fixes

- correct data-action attribute in loan form ([09460c1](https://github.com/hendripermana/permoney/commit/09460c12729f1a4c56c0ff3f9ced23923e0fac76))
- show rate suggestion only on 'terms' step ([ef98463](https://github.com/hendripermana/permoney/commit/ef98463bf1a4c463fae0dc1abef3fff2b20ca220))
- update loan form tooltips and modify loan wizard behavior to streamline next/submit actions. ([0d39ef2](https://github.com/hendripermana/permoney/commit/0d39ef23359efa5c1f794c432202e5435cca0730))

## [0.4.1](https://github.com/hendripermana/permoney/compare/v0.4.0...v0.4.1) (2025-09-20)

### Bug Fixes

- **data_cleaner:** remove when cleaning demo data ([1213da1](https://github.com/hendripermana/permoney/commit/1213da1c16f70b5efad825dc5d067f84805012bc))
- **data_cleaner:** remove when cleaning demo data ([6286ff0](https://github.com/hendripermana/permoney/commit/6286ff04d3229763a3aa44e558da72acdeeb10ab))

## [0.4.0](https://github.com/hendripermana/permoney/compare/v0.3.1...v0.4.0) (2025-09-20)

### Features

- adding IDR demo data ([47e4c40](https://github.com/hendripermana/permoney/commit/47e4c40af994caa8ba67b99294b0d5796893ccab))
- adding IDR demo data ([a26b1b9](https://github.com/hendripermana/permoney/commit/a26b1b9b3e3149355a771c12fa9e00a96059e315))
- **demo:** add loan proceeds, use transfers for investments, ([2eed0b2](https://github.com/hendripermana/permoney/commit/2eed0b276f23448ad46029e546d09c579e13265a))
- **demo:** generate realistic IDR demo data and fix amounts ([dcc81d5](https://github.com/hendripermana/permoney/commit/dcc81d50e3eb559ce9f106b754b9a373c876460d))

### Bug Fixes

- **demo:** use transfers for loan originations and improve data cleanup ([12a6693](https://github.com/hendripermana/permoney/commit/12a6693f1f3190a322442bda8b57ca35be9cec59))

## [0.3.1](https://github.com/hendripermana/permoney/compare/v0.3.0...v0.3.1) (2025-09-19)

### Bug Fixes

- **auth:** remove redundant redirect-loop checks in auth controllers ([6045193](https://github.com/hendripermana/permoney/commit/60451935d542925d36cbc0db06dc002b67a1298f))
- **onboarding:** prevent redirect loops and tidy ([ba47c90](https://github.com/hendripermana/permoney/commit/ba47c90be7c3bc1534e48bbd311bed0e706cdc95))
- **onboarding:** prevent redirect loops and tidy ([daced15](https://github.com/hendripermana/permoney/commit/daced1526399d86af3cf0ddf8d5aed278a9f5266))

## [0.3.0](https://github.com/hendripermana/permoney/compare/v0.2.1...v0.3.0) (2025-09-18)

### Features

- Comprehensive Borrowed Loans Enhancement with Schedule Management ([89942f3](https://github.com/hendripermana/permoney/commit/89942f399b5810d979426f7805c5de49722ead34))
- Comprehensive Borrowed Loans Enhancement with Schedule Management ([4bbe830](https://github.com/hendripermana/permoney/commit/4bbe8308365061b38c3f9844e83fcfbcec6e4e2d))
- Enhance loan management with accurate balance calculations and improved UX ([426ed05](https://github.com/hendripermana/permoney/commit/426ed05b5efad74ef98eab9b4d93f6f316806558))
- **loan:** create transfer-driven entries and adjust tests ([f9ea6d9](https://github.com/hendripermana/permoney/commit/f9ea6d9881dc68f8418e26c56b50ca261eb37837))
- **loans:** add balloon support and normalize rates; improve posting ([e28c596](https://github.com/hendripermana/permoney/commit/e28c596af4b54e274c3d465f1af625904d516a98))
- **loans:** enhance schedule preview UI and loan form behavior ([1272e0f](https://github.com/hendripermana/permoney/commit/1272e0f3db70f6859c4fed4b0bf4ea358e476210))

### Bug Fixes

- Add defensive programming to API controller ([d6d12f0](https://github.com/hendripermana/permoney/commit/d6d12f067378d599beac95a688af8cbc8f6df2e3))
- Address all PR code review suggestions ([a951bdb](https://github.com/hendripermana/permoney/commit/a951bdbf6b5474f35b3718e3de370e5142964ab6))
- Address all PR code suggestions for improved robustness ([6ba7ced](https://github.com/hendripermana/permoney/commit/6ba7cedc7b40e4d5eeba2d66a46c34390a52dae0))
- Address all PR code suggestions for improved robustness ([d49491b](https://github.com/hendripermana/permoney/commit/d49491b9039a934237e8f9a871e2cd3636f85e60))
- Address HTTP verb confusion warning ([8a998c2](https://github.com/hendripermana/permoney/commit/8a998c23b96df835d020cb8480cef956c4400a6e))
- Correct borrowing transaction amount for proper balance calculation ([c97af3d](https://github.com/hendripermana/permoney/commit/c97af3d14ffb2a033ebbb04a4fb64c1981ab9c66))
- Force synchronous account sync for immediate balance update ([3e45c0f](https://github.com/hendripermana/permoney/commit/3e45c0f829cbbfbe9b6589f2aaf77bdee7f6bca4))
- Resolve loan creation test failures ([f4516ca](https://github.com/hendripermana/permoney/commit/f4516ca14756948292d84ebc40ebc8bf325049f4))
- Resolve test failures and route issues ([c586fa0](https://github.com/hendripermana/permoney/commit/c586fa0c412782ef0f677acc7fabd843a5cc91ff))
- **schema:** normalize array literal in virtual column expression ([bf0f0b8](https://github.com/hendripermana/permoney/commit/bf0f0b84183b22f3eac8ea4ab48f9ba631198c64))
- Update loan principal amount when additional borrowing occurs ([d50c2ef](https://github.com/hendripermana/permoney/commit/d50c2ef4e4db9bc5b4fb0dc80a968ebb2c53a81f))

## Unreleased

Added

- Borrowed Loans improvements:
  - New Loan subtypes: LOAN_PERSONAL and LOAN_INSTITUTION (display labels: Borrowed (Person) / Borrowed (Institution)).
  - Add-only loan metadata fields (principal, tenor, frequency, method, rate/profit, institution/contact details, notes, JSON extras).
  - Schedule preview endpoint and UI (feature-flagged).
  - Planned installments table with posting service that splits principal vs interest/profit using existing Transfer/Transaction engine.
  - System categories by key with fallback to name, seeded on demand.
  - Partial unique index preventing double-posting installments; plan regeneration replaces only future rows.
  - Optional extra payment service behind feature flag to recompute future schedule.
  - Late Fee/Admin Fee category keys and optional late fee posting support.
  - API endpoint to safely regenerate future schedule with concise payload.
