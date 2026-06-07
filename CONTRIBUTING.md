# Contributing to Sure

It means so much that you're interested in contributing to Sure! Seriously. Thank you. The entire community benefits from these contributions!

## Getting Started

Before contributing, please read our [Project Conventions Rule](https://github.com/hendripermana/Sure/blob/main/.cursor/rules/project-conventions.mdc), which is intended for LLMs, but is also an excellent primer on how we write code for Sure.

- Before contributing, please check if it already exists in [issues](https://github.com/hendripermana/Sure/issues) or [PRs](https://github.com/hendripermana/Sure/pulls)
- If you're not sure where to start, check out our [good first issues](https://github.com/hendripermana/Sure/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)

As we are still in the early days of this project, we recommend [heading over to the Wiki](https://github.com/hendripermana/Sure/wiki) to get a better idea of _what_ to contribute.

In general, _full features_ that get us closer to [our 🔜 Vision](https://github.com/hendripermana/Sure/wiki/Vision) are the most valuable contributions at this stage.

## Development Setup

### Prerequisites

- Ruby (see `.ruby-version`)
- PostgreSQL
- Node.js (for frontend tooling)

### Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/Sure.git`
3. Set up the development environment:
   ```bash
   cd Sure
   cp .env.local.example .env.local
   bin/setup
   bin/dev
   ```
4. Visit http://localhost:3000

### Setup Guides

- [Mac Setup Guide](https://github.com/hendripermana/Sure/wiki/Mac-Dev-Setup-Guide)
- [Linux Setup Guide](https://github.com/hendripermana/Sure/wiki/Linux-Dev-Setup-Guide)
- [Windows Setup Guide](https://github.com/hendripermana/Sure/wiki/Windows-Dev-Setup-Guide)

## Making Changes

1. Create a new branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Run tests: `bin/rails test`
4. Run linters: `bin/rubocop` and `npm run lint`
5. Create new Pull Request, and be sure to check the [Allow edits from maintainers](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/allowing-changes-to-a-pull-request-branch-created-from-a-fork) checkbox
6. Fill out the PR template completely
7. Before requesting a review, please make sure that all [Github Checks](https://docs.github.com/en/rest/checks?apiVersion=2022-11-28) have passed and your branch is up-to-date with the `main` branch. After doing so, request a review and wait for feedback.

## Code Style

- Follow the existing code style and conventions
- Use meaningful commit messages
- Write tests for new features
- Update documentation as needed

## Questions?

If you have questions, feel free to:
- Open a [Discussion](https://github.com/hendripermana/Sure/discussions)
- Join our [Discord](https://discord.gg/36ZGBsxYEK)
- Open an [Issue](https://github.com/hendripermana/Sure/issues)

Thank you for contributing to Sure! 🎉
