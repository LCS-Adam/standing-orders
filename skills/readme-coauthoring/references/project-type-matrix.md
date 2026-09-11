# Project-Type Matrix

Section recipes per project type. Used during Stage 1 to propose a section list grounded in the detected project type. Each row shows required, optional, and omitted sections, plus a "lead-with" recommendation.

## Library / SDK

**Lead with:** Hook → Install → Smallest usage example.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | One-sentence pitch. |
| Badges row | required | CI, version, downloads, license, coverage. |
| Description / Why | required | Problem solved, what it competes with. |
| Install | required | All supported package managers + version range. |
| Quick start | required | Smallest working example + expected output. |
| API reference | required | Top 5–10 public surface entries; link to full docs if separate. |
| Examples / Recipes | optional | 2–3 real-world patterns. |
| TypeScript / Types | optional | If TS-typed; show one type signature. |
| Compatibility | optional | Browser / Node / Python version matrix. |
| Contributing | recommended | Issue triage + test command + code style. |
| Roadmap | optional | GFM task list if active. |
| Changelog | optional | Link to CHANGELOG.md. |
| License | required | SPDX + LICENSE link. |
| Acknowledgments | optional | Prior art, inspirations. |

**Omit:** Live demo (not applicable), Deploy to X.

## CLI Tool

**Lead with:** Hook → Install → First terminal command.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | |
| Badges row | required | CI, version (npm/PyPI/cargo/brew), downloads, license. |
| Description / Why | required | |
| Install | required | Global vs. local install paths. `brew`, `npm i -g`, `pipx`, `cargo install`. |
| Quick start | required | One terminal command + output. |
| Command reference | required | Subcommands table: name → 1-line description. |
| Flags / Options | required | Global flags. Per-command flags in `<details>` if long. |
| Environment variables | optional | If config can come from env. |
| Configuration file | optional | If a YAML/TOML config is supported. |
| Examples | recommended | 3–5 realistic invocations. |
| Shell completions | optional | If supported. |
| Contributing | recommended | |
| License | required | |

**Omit:** Live demo, API reference.

## Web App / SPA

**Lead with:** Live demo link → Screenshot or GIF → Tech stack.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | |
| Live demo | required | URL at the very top. |
| Screenshot / GIF | required | Above the fold. Alt text mandatory. |
| Badges row | recommended | CI, deploy status (Vercel/Netlify), license. |
| Description / Why | required | |
| Tech stack | required | Framework, state mgmt, hosting, key libs. |
| Features | recommended | Table format, not bullet list. |
| Run locally | required | Clone → install → dev command. |
| Deploy to X | optional | Vercel / Netlify / Cloudflare one-click. |
| Architecture | optional | Mermaid if ≥3 components. |
| Roadmap | optional | |
| Contributing | optional | |
| License | required | |

**Omit:** API reference (unless backend), Command reference.

## Data Project

**Lead with:** Dataset description → Approach → Reproducibility.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | |
| Badges row | optional | CI + license if applicable. |
| Description / Why | required | What question does this answer? |
| Dataset | required | Source, size, format, license, time range. |
| Methodology | required | Approach, key choices, models used. |
| Results | required | Key metrics, ideally with tables. |
| Reproducibility | required | Exact commands to regenerate. Ideally Docker / `make all`. |
| Assumptions & tradeoffs | required | What's known to be approximate. |
| Architecture / Pipeline | recommended | Mermaid flowchart. |
| Data dictionary | optional | If schema is non-obvious. |
| Validation | optional | Reconciliation, tests, sanity checks. |
| Future work | optional | |
| License | required | Data + code license, may differ. |
| Acknowledgments | recommended | Data providers. |

**Omit:** Install (replaced by Reproducibility), API reference.

## Portfolio Piece

**Lead with:** Live demo + screenshot → Problem solved → What I learned.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | |
| Live demo / Screenshot | required | Top of file. |
| Description / Why | required | Problem + your motivation. |
| Tech stack | required | |
| Key features | recommended | Table or short list. |
| How it works | recommended | Brief architecture explanation. |
| Run locally | recommended | Even if hosted, allow tinkering. |
| What I learned / Tradeoffs | required | Differentiator from a generic project. |
| Future work | optional | |
| Author | required | Link to portfolio site / LinkedIn / other work. |
| License | recommended | |

**Omit:** Contributing (rarely solicited), API reference.

## Take-Home / Interview Submission

**Lead with:** How to run → Assumptions → Tradeoffs.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | Match the prompt's framing. |
| Summary | required | What you built, in 2–4 sentences. |
| How to run | required | Exact commands. Docker ideal. Reproducible setup is the #1 grading signal. |
| Assumptions | required | List explicitly. Demonstrates judgment. |
| Tradeoffs | required | What you considered, what you chose, why. |
| Architecture | required | Mermaid or ASCII. |
| Decisions | recommended | Short ADR-style log of key choices. |
| What I'd do differently | recommended | Self-aware reflection. |
| Validation / Testing | recommended | How you verified correctness. |
| Out of scope | optional | What the prompt asked for and you deferred, with reason. |
| Author | required | Your name + contact. |

**Omit:** Badges (usually), License (unless required), Contributing.

## Monorepo

Apply on top of base project type. Adds:

| Section | Status | Notes |
|---|---|---|
| Workspace structure | required | `packages/` vs. `apps/` explained. Show ASCII or tree. |
| Why this structure | required | Don't just describe — justify. |
| Per-package READMEs | required | Link to each. |
| Cross-package commands | required | How to install, build, test all. |
| Dependency management | optional | Where devDeps vs. regular deps live. |
| Release process | optional | Changesets / Lerna / standard-version. |

**The "why" section is the differentiator.** Monorepo READMEs without rationale read like inventory lists.

## Fork / Template Repo

**Lead with:** Original author credit → What changed → How to use this template.

| Section | Status | Notes |
|---|---|---|
| Title + tagline | required | |
| Origin / Credit | required | Link to original, license inheritance noted. |
| What's different | required | If a fork, the divergence summary. |
| Use this template | required | Steps to clone / customize / deploy. |
| Customization | recommended | Files to edit first. |
| License | required | Original + your additions. |

**Omit:** Long usage docs (the template's purpose is to be edited, not studied).

## Quick lookup

| Project type | Top section | Distinct required |
|---|---|---|
| Library | Hook → Install → Quick start | API reference |
| CLI | Hook → Install → First command | Command reference |
| Web app | Live demo → Screenshot | Tech stack, Run locally |
| Data project | Dataset → Methodology → Results | Reproducibility, Assumptions |
| Portfolio | Demo → Problem | What I learned |
| Take-home | How to run → Assumptions | Tradeoffs, Decisions |
| Monorepo | (base) + Workspace structure | Why this structure |
| Fork / template | Origin credit → What changed | Use this template |
