# Exemplary READMEs

Reference these for inspiration. Annotated with what each does well.

## Libraries

### [axios/axios](https://github.com/axios/axios)
Logo + tagline + badges row + feature list + install + usage in 30 lines. API reference is comprehensive but uses anchored sections so the TOC works. Good model for: tightly-scoped JavaScript libraries.

### [pallets/flask](https://github.com/pallets/flask)
Minimal opening (hook + install + 6-line code example) then links out. Demonstrates: a mature project that trusts external docs and keeps the README a landing page.

### [psf/requests](https://github.com/psf/requests)
Hook leads with a "compare to alternatives" code snippet. Effective when your differentiator is ergonomics.

### [sveltejs/svelte](https://github.com/sveltejs/svelte)
Strong "Why" section — explains what makes Svelte different (compiler vs runtime) in two paragraphs. Good model for: opinionated frameworks.

## CLIs

### [cli/cli (GitHub CLI)](https://github.com/cli/cli)
Top-of-README install table covers brew/apt/scoop/winget/etc. Demonstrates: serving heterogeneous OS / package-manager audiences.

### [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
Opens with a real benchmark vs the standard tool (`grep`). Shows: how to justify "fast" claims with numbers.

### [astral-sh/uv](https://github.com/astral-sh/uv)
Performance claims backed by chart. Demonstrates: visuals + receipts > prose claims.

## Web apps / Examples

### [gothinkster/realworld](https://github.com/gothinkster/realworld)
Demo-first layout. Architecture diagram explains the "Conduit" pattern that ties all the implementations together. Good model for: demo / educational projects.

### [vercel/next.js](https://github.com/vercel/next.js)
Logo + quick-start + features grid + documentation links + sponsors. Shows: a polished mature-product README without bloat.

## Data / analytics

### [duckdb/duckdb](https://github.com/duckdb/duckdb)
Project description nails the differentiator ("DuckDB is an analytical in-process SQL database management system") in the first sentence. Demonstrates: precise positioning beats marketing.

### [dbt-labs/dbt-core](https://github.com/dbt-labs/dbt-core)
"What is dbt?" section directly addresses the reader's first question. Architecture image with alt text. Good accessibility model.

## Portfolio / personal

### [matiassingers/awesome-readme](https://github.com/matiassingers/awesome-readme)
Self-referentially well-organized. The structure of the awesome list itself is the demo. Browse the list to find domain-specific exemplars (data science, mobile, game dev, etc.).

### [othneildrew/Best-README-Template](https://github.com/othneildrew/Best-README-Template)
Template / scaffold to copy. Has every standard section, all placeholder-filled. Good starting point if you want a checklist.

## Take-home / interview

(Strong public take-home READMEs are rare — most ship privately. Patterns to model:)

- Lead with **How to run** (Docker-compose ideal — reduces grader friction).
- **Assumptions** section explicit and bulleted.
- **Tradeoffs** in their own section, not buried.
- **What I'd do differently** at the end — self-aware reflection.
- **Architecture** as ASCII or Mermaid, not prose.

## Monorepos

### [nrwl/nx](https://github.com/nrwl/nx)
Workspace structure section explains the "why" — not just what's in each dir, but the philosophy. Good model for: justifying complex repo shape.

### [vercel/turbo](https://github.com/vercel/turbo)
Per-package READMEs under the main one. Top-level README is a landing page that orients you to the workspace.

## Patterns to steal

- **Demo GIF above the fold** (Next.js, gothinkster/realworld) — earns attention in 2 seconds.
- **Tagline as comparative claim** (ripgrep: "ripgrep is a line-oriented search tool that recursively searches your current directory for a regex pattern.") — positions vs known alternatives without naming them.
- **Architecture image with paragraph caption** (dbt-core) — accessible + scannable.
- **Install table for OS / manager heterogeneity** (GitHub CLI) — replaces 30 lines of prose with one grid.
- **`<details>` for full reference** (most polished libraries) — keeps the README scannable while preserving depth.
- **Sponsor / used-by section near the top** (Svelte, Next.js) — social proof when relevant.
- **Roadmap as GFM task list** — visible progress, no inline bug-tracker bloat.

## Patterns to avoid (seen in well-known repos)

- Some popular READMEs have grown so long they're untenable. Don't model after sheer length — model after their early commits if you want their original clarity.
- Marketing-heavy READMEs from VC-backed companies often optimize for star-bait. The underlying product may be excellent, but the README isn't a model for technical communication.

## How to use this list

When stuck on a section, find an exemplar of the same project type and study how they handled that section. Borrow structure, not phrasing.
