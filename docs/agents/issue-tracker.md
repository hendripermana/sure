# Issue Tracker: GitHub

Issues and PRDs for this repository live in
[`hendripermana/sure`](https://github.com/hendripermana/sure). Use the `gh` CLI
from this repository for issue operations so the local `origin` selects the
correct tracker.

## Conventions

- Create an issue with `gh issue create --title "..." --body-file <file>`.
- Read an issue with `gh issue view <number> --comments`.
- List issues with `gh issue list` and request structured JSON when automation
  needs to inspect labels, bodies, or comments.
- Comment with `gh issue comment <number> --body "..."`.
- Apply or remove labels with `gh issue edit`.
- Close issues with `gh issue close`.

## Upstream Community

[`we-promise/sure`](https://github.com/we-promise/sure) is an active upstream
reference, not this repository's issue tracker. Compare its behavior, commits,
and architecture when planning catch-up work, but adapt changes to Sure's domain,
design system, and more advanced local features. Do not cherry-pick upstream
changes blindly.

## Skill Semantics

When a skill says "publish to the issue tracker," create an issue in
`hendripermana/sure`. When a skill says "fetch the relevant ticket," use
`gh issue view <number> --comments` from this repository.
