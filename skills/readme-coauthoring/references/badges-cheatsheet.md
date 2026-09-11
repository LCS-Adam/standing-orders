# Badges Cheatsheet

Shields.io is the canonical source. Default style: `flat-square`. Group semantically (trust → adoption → metadata). Skip noise.

## Trust signals (recommend)

### Build status (GitHub Actions)

```markdown
[![Build](https://img.shields.io/github/actions/workflow/status/USER/REPO/test.yml?branch=main&style=flat-square)](https://github.com/USER/REPO/actions)
```

Replace `test.yml` with your workflow filename. Use the `branch` query if the project has multiple long-lived branches.

### Build status (other CI)

- Travis CI: `https://img.shields.io/travis/com/USER/REPO`
- CircleCI: `https://img.shields.io/circleci/build/github/USER/REPO`
- GitLab: `https://img.shields.io/gitlab/pipeline-status/USER/REPO`

### Test coverage

```markdown
[![Coverage](https://img.shields.io/codecov/c/github/USER/REPO?style=flat-square)](https://codecov.io/gh/USER/REPO)
```

Coveralls: `https://img.shields.io/coveralls/github/USER/REPO`.

### License

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
```

Or auto-detect from a file: `https://img.shields.io/github/license/USER/REPO`. Link target should be the LICENSE file in the repo, not opensource.org.

## Adoption signals (recommend if applicable)

### npm version + downloads

```markdown
[![npm version](https://img.shields.io/npm/v/PACKAGE?style=flat-square)](https://www.npmjs.com/package/PACKAGE)
[![npm downloads](https://img.shields.io/npm/dm/PACKAGE?style=flat-square)](https://www.npmjs.com/package/PACKAGE)
```

Use `dm` (downloads/month). `dt` (total) inflates for old packages; `dw` is too noisy.

### PyPI

```markdown
[![PyPI version](https://img.shields.io/pypi/v/PACKAGE?style=flat-square)](https://pypi.org/project/PACKAGE/)
[![PyPI downloads](https://img.shields.io/pypi/dm/PACKAGE?style=flat-square)](https://pypistats.org/packages/PACKAGE)
```

### crates.io (Rust)

```markdown
[![Crates.io](https://img.shields.io/crates/v/CRATE?style=flat-square)](https://crates.io/crates/CRATE)
[![Downloads](https://img.shields.io/crates/d/CRATE?style=flat-square)](https://crates.io/crates/CRATE)
```

### RubyGems

```markdown
[![Gem Version](https://img.shields.io/gem/v/GEM?style=flat-square)](https://rubygems.org/gems/GEM)
[![Downloads](https://img.shields.io/gem/dt/GEM?style=flat-square)](https://rubygems.org/gems/GEM)
```

### Docker Hub

```markdown
[![Docker Pulls](https://img.shields.io/docker/pulls/USER/IMAGE?style=flat-square)](https://hub.docker.com/r/USER/IMAGE)
[![Docker Image Size](https://img.shields.io/docker/image-size/USER/IMAGE?style=flat-square)](https://hub.docker.com/r/USER/IMAGE)
```

## Compatibility signals (optional)

### Minimum Node / Python version

```markdown
[![Node](https://img.shields.io/node/v/PACKAGE?style=flat-square)](https://nodejs.org/)
[![Python](https://img.shields.io/pypi/pyversions/PACKAGE?style=flat-square)](https://pypi.org/project/PACKAGE/)
```

### TypeScript / type definitions

```markdown
[![Types](https://img.shields.io/npm/types/PACKAGE?style=flat-square)](https://www.typescriptlang.org/)
```

## Hosting / deploy (web apps)

### Vercel / Netlify deploy status

Vercel: use their built-in badge from project settings.
Netlify:

```markdown
[![Netlify Status](https://api.netlify.com/api/v1/badges/PROJECT-ID/deploy-status)](https://app.netlify.com/sites/SITE-NAME/deploys)
```

### Live demo (custom badge)

```markdown
[![Live demo](https://img.shields.io/badge/demo-live-success?style=flat-square)](https://demo.example.com)
```

## Style guidance

- **Default style:** `flat-square`. Modern, low-decoration.
- **Bold variant:** `for-the-badge` — use sparingly (max 1 per row, usually for "Sponsor" or a single hero badge).
- **Avoid:** `plastic` (dated), default round-rect-shadow (noisy).
- **Color:** Shields.io picks semantic colors automatically (green = pass, red = fail, blue = info). Override only when needed.
- **Grouping:** 2–6 badges per row. More than 6 looks like a Christmas tree. If you have more, split into rows by category.
- **Order within a row:** trust → adoption → compatibility → license.

## Noise (avoid)

- Visitor counters (`hits`, `views`) — no signal value.
- "Made with ❤️" / "Built with love" — cliché.
- Star / fork count badges — GitHub already shows these in the repo header.
- "Awesome" badge — only if the project is genuinely listed on an Awesome list, and link it.
- Outdated CI badges (e.g., Travis after you migrated to GitHub Actions) — verify each badge resolves.

## Verification

Before shipping a badge row:

1. Open each badge URL in a browser. Confirm it renders (no 404 / broken SVG).
2. Click each badge. Confirm the link target makes sense.
3. If a badge shows "unknown" or stale data, fix or remove.
