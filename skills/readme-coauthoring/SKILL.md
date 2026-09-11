---
name: readme-coauthoring
description: Co-author a comprehensive, polished README for a software project. Use when the user wants to write, rewrite, or seriously improve a README — for a library, CLI, web app, data project, portfolio piece, take-home assignment, monorepo, or fork. Auto-discovers project context, adapts structure to project type, and embeds GitHub-native Markdown features (badges, admonitions, collapsibles, Mermaid, accessible headings). Skip for one-off doc edits or non-README writing — use `doc-coauthoring` for those.
version: 0.1.0
tools: Read, Glob, Grep, Bash, Edit, Write, WebFetch
---

# README Co-Authoring Workflow

This skill walks the user through a project-aware, polish-driven workflow for producing a README that holds up under scrutiny. It is a README-specific specialization of `doc-coauthoring`. The differences worth knowing:

- **Stage 0 auto-discovery** — inspect the project before asking anything. Read manifest files, detect the project type, scan for CI/license/demo signals, and surface findings as a brief inventory.
- **Project-type-aware section recipes** — pull the canonical section list from `references/project-type-matrix.md` and the matching template in `assets/templates/<type>.md`.
- **Polish layer (Stage 3)** — badges, GitHub-native Markdown features (Alerts, `<details>`, Mermaid), accessibility audit, anti-pattern scrub.
- **README reader-test personas (Stage 4)** — evaluating-dev, contributor, recruiter/reviewer.

## When to offer this workflow

**Trigger phrases:** "write a README", "fix my README", "rewrite the README", "make this README better", "polish my README", "draft a README for X", "README for my [library / CLI / take-home / portfolio]".

**Do not offer for:** one-off section edits ("fix the install command"), non-README docs (use `doc-coauthoring`), CHANGELOG / CONTRIBUTING / CODE_OF_CONDUCT files (those have their own conventions — write directly).

**Initial offer:** Tell the user this workflow has four stages — Project Discovery (you, silent) → Context Gathering → Section-by-Section Build → Polish & Reader-Test — and ask whether to proceed.

If they decline, write freeform. If they accept, go straight to Stage 0 without further questions.

## Stage 0 — Project Discovery

**Goal:** Close the context gap before the user has to explain anything. Do not ask the user questions in this stage. Inspect the repo and surface a brief inventory at the end.

### Discovery sweep

Run these checks. Use `Glob`, `Grep`, `Read`, and quick `Bash` (`ls`, `wc -l`) calls. Stay read-only.

**Existing README:**
- `Glob` for `README*` at repo root and one level deep.
- If found, `Read` it. Note: current section list, line count, badges present, last-modified hint (`git log -1 --format=%cs README.md` if available).

**Project-type signals (detect in this order; first strong match wins, but record overlapping signals):**

| Signal file / pattern | Indicates |
|---|---|
| `package.json` with `"bin"` field, or `bin/` dir with executables | **CLI** |
| `package.json` with `"main"` / `"exports"` / `"module"`, no `"bin"` | **Library** (JS/TS) |
| `setup.py` / `pyproject.toml` with `[project.scripts]` / `entry_points` | **CLI** (Python) |
| `setup.py` / `pyproject.toml` without scripts, has `src/` or top-level package | **Library** (Python) |
| `Cargo.toml` with `[[bin]]` | **CLI** (Rust) |
| `Cargo.toml` with `[lib]` only | **Library** (Rust) |
| `go.mod` + `cmd/` dir | **CLI** (Go) |
| `go.mod` + no `cmd/`, exported pkg | **Library** (Go) |
| `index.html` + `vite.config.*` / `next.config.*` / `src/App.*` | **Web app** |
| `vercel.json`, `netlify.toml`, `_redirects` | **Web app** (deployed) |
| `*.duckdb`, `*.parquet`, `dbt_project.yml`, `notebooks/`, `model/cubes/`, `airflow/`, `sql/` | **Data project** |
| `workspaces` in `package.json`, `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`, top-level `packages/` + `apps/` | **Monorepo** (apply on top of base type) |
| `.github/template/` or `template: true` in `.github/repository.yml`, or README says "template" | **Fork / template repo** |
| Directory shape suggests demo (single small script + `README` + `screenshots/` or `media/`) | **Portfolio** |
| `CHALLENGE.md`, `INSTRUCTIONS.md`, take-home phrasing in existing README, or operator says so | **Take-home** |

If none match clearly, default to **library** and ask in Stage 1 to confirm.

**Infrastructure signals (feed the polish layer):**
- `.github/workflows/*.yml`, `.travis.yml`, `.circleci/`, `.gitlab-ci.yml` → **CI detected** → propose build-status badge.
- `LICENSE`, `LICENSE.md`, `COPYING`, or `license` field in manifest → **License detected** → propose license badge + section.
- `coverage/`, `.coveragerc`, `codecov.yml`, coverage-related GH Actions → **Coverage tooling** → propose coverage badge.
- Published-package fingerprint: `package.json` + `"name"` (npm), `pyproject.toml` `[project] name` + classifiers, `Cargo.toml` `[package] name` → propose version + downloads badges.
- Live URL: grep existing README for `https://*.vercel.app`, `*.netlify.app`, `*.github.io`, or a `homepage` field in `package.json` → flag as demo link candidate.

**Architecture-diagram opportunities:**
- Count top-level dirs and significant subsystems. If ≥3 distinct components (e.g., `frontend/` + `backend/` + `worker/`, or multiple cubes/views/agents), flag Mermaid suggestion for Stage 3.

**Existing assets:**
- `Glob` for `screenshots/`, `media/`, `assets/`, `docs/`, `*.gif`, `.github/IMAGE.*`. Note count.

**Internal-doc signals (if internal planning repos or `docs/` are co-located):**
- Note that `docs/` files may contain prose ready to harvest. Don't read them yet — surface as a Stage-1 follow-up.

### Inventory output

After the sweep, output one terse paragraph:

```
DETECTED: <project type> (<language>). <CI tool> CI present. <license name>
license. <N> screenshots in <path>. <published / unpublished>.
<Existing README: M lines, missing K canonical sections / No existing README.>
PROPOSING: <project-type> template + badges (<list>) + Mermaid for <reason>.
Confirm or correct in Stage 1.
```

Then proceed to Stage 1.

## Stage 1 — Context Gathering

**Goal:** Confirm project type, surface audience + impact + constraints. Keep this short — Stage 0 already did the heavy lifting.

### Questions to ask (numbered, expect shorthand answers)

1. Project type detected as `<X>`. Correct? (Y / N — and override)
2. Who reads this README? (evaluating dev / contributor / recruiter or reviewer / OSS reviewer / internal team / interview grader — pick all that apply)
3. Desired impact when someone reads this? (install adoption / PR contributions / interview score / team onboarding / star-bait / archival)
4. Constraints? (org style guide / badge policy / length limit / branding / non-English / license restrictions)
5. Anything in the repo (e.g., `docs/`, planning notes, ADR files) I should harvest for content?

After answers, show the proposed section list from `references/project-type-matrix.md` for the confirmed project type. Ask: keep, add, remove, reorder?

When the user accepts the section list, copy the matching `assets/templates/<type>.md` as the working scaffold for the README at the project root (or wherever they specify). Use `Write` to create / overwrite, but confirm overwrite of an existing README first.

## Stage 2 — Section-by-Section Build

**Goal:** Fill each section through brainstorm → curate → draft → refine.

### Section ordering

Start with the section that has the most unknowns — usually **Hook / Description** for libraries/CLIs, **Live Demo + Why** for web apps, **Dataset + Approach** for data projects, **Assumptions + Tradeoffs** for take-homes. Save **Table of Contents**, **License**, **Authors / Acknowledgments**, and the final **Hook polish** for last.

### Per-section loop

For each section:

1. **Announce** the section by name. Show the template scaffold content currently in the file for that section.
2. **Clarifying questions** — 5–10 numbered questions specific to the section. Examples below.
3. **Brainstorm** 5–20 candidate bullets, grounded in Stage-0 findings and the user's Stage-1 answers. At the bottom: "Want more? Say so."
4. **Curate** — ask which to keep / remove / combine. Accept numbered selections or freeform feedback.
5. **Gap check** — "Anything important missing for this section?"
6. **Draft** — use `Edit` (str_replace) to replace the placeholder block in the file with the drafted section.
7. **Iterate** — user feedback → `Edit`. Never reprint the whole file. After 3 no-change iterations, ask: "Anything we can remove without losing signal?"

### Section-specific clarifying questions

Use the appropriate set when you reach each section. Pull additional patterns from `references/section-templates.md`.

**Hook / Description:**
- One sentence: what does this do?
- One sentence: why does it exist? (problem solved, gap filled, alternative compared to)
- Is there a memorable phrase that conveys the differentiator?
- For a 5-second skim, what's the ONE thing the reader should take away?

**Install / Setup:**
- All supported install paths? (npm, yarn, pnpm, pip, uv, brew, cargo, docker)
- Any prerequisites (Node 18+, Python 3.11+, OS-specific)?
- Is there an env-var or config setup step?
- Reproducible smoke test that confirms install worked?

**Usage / Quickstart:**
- Smallest possible working example?
- Expected output (paste it verbatim)?
- Common gotcha first-timers hit?

**API / Configuration / Commands:**
- What's the primary public surface? (top 5–10 entries)
- Defaults vs. configurables?
- Is there a separate full reference (link to it)?

**Examples / Advanced:**
- 2–3 realistic use cases the reader would actually have?
- Any pattern that shows depth (composition, edge case, integration)?

**Contributing:**
- How to file an issue?
- How to run tests locally?
- Code style / linter / commit format?
- DCO or CLA?

**License:**
- SPDX identifier?
- Year + copyright holder?
- Any exceptions (assets under different license)?

### Quality gates per section

Before marking a section done, check:

- **Hook**: a fresh reader in 5 seconds learns what + why?
- **Install**: copy-paste-ready, language-tagged code fence, no "follow the guide" phrasing?
- **Usage**: example runs as written, output shown?
- **API / Config**: anchors set so TOC links land correctly?
- **Examples**: real, runnable, not toy?
- **License**: links to `LICENSE` file, not just a string?

If a gate fails, loop back to refinement.

### Near completion

When 80%+ of sections are drafted, read the whole file. Check:
- Flow across sections.
- Redundancy or contradictions.
- Generic filler ("blazing fast", "easy to use") — flag for the anti-pattern scrub in Stage 3.
- Every sentence carries weight.

Surface findings to the user. Refine before moving to Stage 3.

## Stage 3 — Polish Layer

**Goal:** Apply badges, GitHub-native Markdown, accessibility, anti-pattern scrub.

### Badges pass

1. Read `references/badges-cheatsheet.md`.
2. Propose a badge row grounded in Stage-0 findings:
   - CI detected → build-status badge (GitHub Actions URL pattern).
   - License detected → license badge.
   - Published package → version + downloads.
   - Coverage tooling → coverage badge.
3. Recommend `flat-square` style as default. Group semantically (CI / coverage → version / downloads → license). Avoid noise: no visitor counters, no "made with love", no star-count badges (GitHub shows those).
4. Show copy-paste markdown. User picks which to keep.
5. Insert into the README directly under the title via `Edit`.

### GitHub-Markdown pass

Open `references/github-markdown-features.md` only if proposing a feature the user hasn't seen before. Otherwise propose inline:

- **GitHub Alerts** (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`) — propose for callouts that currently use bold or italics.
- **`<details>` collapsibles** — propose for: full API tables, OS-specific install variations, troubleshooting sections, advanced configuration, multiple screenshots. Keeps the top-level scannable.
- **Mermaid** — propose if Stage 0 flagged an architecture-diagram opportunity (≥3 components). Offer flowchart or sequence depending on whether it's structural or temporal.
- **GFM tables** — convert feature bullet-lists to feature/benefit tables.
- **GFM task lists** — propose for explicit roadmaps only.
- **Anchor-linked TOC** — propose if README is >150 lines. GitHub auto-renders the Outline button, so a manual TOC is optional — recommend only if the user wants explicit cross-section navigation.
- **Footnotes** — propose for citing external claims without breaking flow.

Apply via `Edit` after user accepts each proposal.

### Accessibility pass

Read `references/accessibility-checklist.md` once. Run the checklist:

- Heading hierarchy: only one `#`, no skipped levels.
- Every image has descriptive alt text (`![Alt: …](path)`).
- No `[click here]` / `[link]` / `[read more]` — use descriptive link text.
- No color-only status signals — pair color with text or emoji-with-text (✅ Pass / ❌ Fail).
- Every code fence has a language tag.
- Prefer relative links for repo-internal targets.

Apply fixes via `Edit`.

### Anti-pattern scrub

Read `references/anti-patterns.md`. Sweep the file:

- Replace "state-of-the-art", "industry-leading", "revolutionary", "blazing fast", "just a few lines of code".
- Convert generic feature bullet-lists ("Fast / Easy / Lightweight") into benefit-stated tables.
- Replace vague install prose with copy-paste commands.
- Add a "why this exists" line to the hook if missing.
- Break walls of text in install/usage into list + code.

Apply fixes via `Edit`. Surface borderline cases for the user to decide.

## Stage 4 — Reader Testing

**Goal:** Test the README against fresh-context reader personas. Catch blind spots the authors can't see.

### Personas to run

Run sub-agents in parallel where possible. Each gets ONLY the README content and the persona prompt — no context from this conversation.

**Evaluating-dev persona** (always run):

> You are a developer considering using this project. You found this README via search. Answer these questions using ONLY the README content. For each answer, also report: (a) ambiguities, (b) assumed prior knowledge.
>
> 1. What does this project do?
> 2. Why should I use this instead of alternative X?
> 3. What's the install command?
> 4. What's the smallest working example?
> 5. What's the license?
> 6. Where do I report bugs?

**Contributor persona** (run if Contributing section exists):

> You are a developer who wants to contribute. Answer from the README only.
>
> 1. How do I set up a local dev environment?
> 2. How do I run the tests?
> 3. What's the code style / commit format?
> 4. Where do I file issues vs. submit PRs?
> 5. Is there a CLA or DCO?

**Recruiter / reviewer persona** (run for portfolio or take-home projects):

> You are reviewing this project for technical hiring or a take-home grading. Skim the README in 60 seconds, then answer.
>
> 1. What problem does this solve?
> 2. What's impressive or distinctive about the approach?
> 3. What tradeoffs did the author acknowledge?
> 4. What would you ask in a follow-up interview?
> 5. Did the author surface assumptions and constraints?

### Process

1. Spawn the relevant persona sub-agents via the Agent tool (subagent_type: `general-purpose`). Pass the README content inline.
2. Collect each agent's answers + ambiguity reports.
3. Summarize per persona: what landed, what was ambiguous, what was missing.
4. Loop back to Stage 2 refinement for any persona-specific failures.
5. Re-run only the failing persona on the second pass.

Exit Stage 4 when each persona answers cleanly with no new ambiguities.

## Final Review

Before declaring done:

1. **Markdown lint** — run `Bash` to scan for broken anchor links, unclosed `<details>`, malformed badge URLs. If `markdownlint` or `prettier` is installed in the repo, suggest running it; otherwise do a visual check.
2. **Render-check** — render any Mermaid diagrams mentally: do they communicate the architecture?
3. **Size check** — `wc -c README.md`. GitHub truncates above 500 KiB. Warn if approaching.
4. **Ownership** — remind the user: "You own this README. Do one read-through, verify links, verify the install command actually works as written, verify any version/license claims."

End with: "Document complete. Two reminders: (1) test the install command in a clean environment before you publish, (2) update badges and version numbers as the project evolves."

## Tips for effective guidance

- **Stay procedural.** Each stage has a defined exit condition. Don't skip stages even if the user signals impatience — instead, compress within each stage.
- **Cite Stage 0 findings.** When proposing a badge, name the file that triggered it (`.github/workflows/test.yml` → CI badge). When proposing Mermaid, name the components.
- **Use `Edit`, never reprint the whole file.** Surgical changes preserve the rest of the user's work.
- **Surface tradeoffs explicitly.** "A TOC at 150 lines is borderline — I'd add one. Your call." beats "Adding a TOC."
- **Honesty wins.** If a section feels generic and the user can't articulate why it exists, suggest removing it.
- **Respect existing voice.** If the user's existing README has a distinctive tone, match it. Don't standardize toward bland.

## Reference index

When a stage references a file, read it then; don't preload.

- `references/project-type-matrix.md` — section recipes per project type (Stage 1).
- `references/section-templates.md` — canonical section scaffolds (Stage 2).
- `references/badges-cheatsheet.md` — shields.io taxonomy + copy-paste markdown (Stage 3).
- `references/github-markdown-features.md` — Alerts, `<details>`, Mermaid, tables, TOC syntax (Stage 3).
- `references/accessibility-checklist.md` — WCAG-adjacent README checks (Stage 3).
- `references/anti-patterns.md` — bad-vs-good concrete pairs (Stage 3).
- `references/exemplary-readmes.md` — annotated examples for inspiration (any stage).
- `assets/templates/<type>.md` — starter scaffolds, one per project type (Stage 1 → Stage 2).
