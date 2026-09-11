# README Anti-Patterns

Concrete bad / good pairs. Reference this during the Stage 3 anti-pattern scrub.

## Generic feature bullet-list

**Bad:**

```markdown
## Features

- Fast
- Easy to use
- Lightweight
- Modern
- Production-ready
```

These are claims without evidence. Worse, they're indistinguishable from every other project's bullet list.

**Good:**

```markdown
## Features

| Feature | What it does for you |
|---|---|
| 50KB gzipped | Loads in under 1s on 3G. |
| Streaming parser | Process files larger than RAM. |
| Zero dependencies | One install, no transitive surprises. |
| TypeScript-first | Strict types, no `any` in the public API. |
```

Each entry has a verifiable benefit.

## Hype phrases

**Bad:**

- "Blazing fast"
- "State-of-the-art"
- "Industry-leading"
- "Revolutionary"
- "Just a few lines of code!"
- "Production-ready" (without evidence)
- "Battle-tested" (without evidence)

**Good:** Replace with specifics.

- "Blazing fast" → "Parses 1GB in 2.3s on M2 MacBook (`bench/parse.ts`)."
- "State-of-the-art" → "Implements RFC 8259 with full spec compliance (see [`tests/spec/`](tests/spec/))."
- "Just a few lines of code" → show the code instead of describing how short it is.

## Vague install

**Bad:**

```markdown
## Install

Follow the installation guide in the docs.
```

**Good:**

````markdown
## Install

```bash
npm install @org/package
```

Requires Node 18+.
````

The reader is already in your README. Don't bounce them to docs for the install command.

## Missing the "Why"

**Bad:**

```markdown
# my-router

A router for JavaScript applications.
```

(What kind of router? Why would I use it over the others?)

**Good:**

```markdown
# my-router

A 1KB client-side router for vanilla JS apps. Unlike the 50KB framework routers, it has zero dependencies and no opinions about state management — drop it into an existing HTML page and intercept clicks.
```

Three jobs in two sentences: position (what), differentiate (vs alternatives), motivate (why I'd pick it).

## Wall-of-text install

**Bad:**

```markdown
## Install

First make sure you have Node.js installed. If you don't, go to nodejs.org and download the latest LTS version. Then clone this repository to your local machine. After that, navigate into the directory and run npm install. This will install all the dependencies. Once that's done, you can run the project with npm start. If you have any issues, check the troubleshooting section below.
```

**Good:**

````markdown
## Install

**Prerequisites:** Node 18+.

```bash
git clone https://github.com/user/repo
cd repo
npm install
npm start
```

Hit a snag? See [Troubleshooting](#troubleshooting).
````

## No Table of Contents on long files

If your README is >150 lines, readers need to skim. GitHub auto-renders an Outline button (top-right), but a manual TOC near the top:

1. Signals "this is organized."
2. Lets readers Cmd-F + jump.
3. Surfaces a section list before they decide to keep reading.

## Monorepo without "Why"

**Bad:**

```markdown
## Packages

- `packages/ui`
- `packages/api`
- `packages/cli`
- `apps/web`
- `apps/admin`
```

(Just an inventory. The reader still doesn't know why this structure.)

**Good:**

```markdown
## Workspace structure

```
packages/    ← reusable libraries published to npm
  ui/        ← shared component library
  api-client/ ← typed API SDK
apps/        ← deployable products consuming the packages
  web/       ← marketing site
  admin/     ← internal dashboard
```

**Why this shape:** `packages/` are versioned and shipped externally; `apps/` are private and deployed. Internal-only utilities live in `packages/` only if shared by ≥2 apps.
```

## Outdated examples

**Bad:** Code samples written against version 1.x while the README claims version 4.x.

**Good:**
- Test examples in CI (e.g., extract to `examples/`, run them on PR).
- Or: pin sample code to a tagged version and note `// requires v2+`.

## "Click here" links

**Bad:** `[click here](docs)` / `[here](api.md)` / `[read more](#)`.

**Good:** `[API reference](api.md)` / `[Configuration guide](docs/config.md)`.

## Wall of badges

**Bad:** 14 badges across 3 rows including visitor count, "made with love", stars, forks, watchers, sponsors, awesome-badge, and a discord widget.

**Good:** 3–6 badges, max 2 rows, grouped semantically (trust → adoption → license).

## Long License section

**Bad:**

```markdown
## License

MIT License

Copyright (c) 2026 ...

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
... [60 more lines pasted verbatim]
```

**Good:**

```markdown
## License

[MIT](LICENSE) © 2026 Your Name.
```

The full text belongs in the LICENSE file. The README links to it.

## Empty Contributing section

**Bad:**

```markdown
## Contributing

Contributions welcome!
```

**Good:** Either fill it with specifics (`npm test`, `npm run format`, link to CONTRIBUTING.md, DCO or CLA note), or omit the section entirely. Empty stubs erode trust.

## Hidden requirements

**Bad:** Install command works, but at runtime fails because Python 3.11 is required and the README didn't mention it.

**Good:** List runtime + dev prerequisites under Install. Match what your CI actually tests.

## "Coming soon" / "TODO" markers in published READMEs

Move to a Roadmap section (with task list) or a separate issues tracker. "TODO" in a README signals abandonment.

## Inconsistent terminology

If you call it a "plugin" in one section, "extension" in another, and "module" elsewhere — pick one. Use the same noun throughout.

## Multiple H1s

Only one `#` per file. Subsections are `##` and below. Multiple H1s break Outline rendering and screen-reader navigation.
