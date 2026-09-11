# project-name

> One-sentence pitch. What does it do, who is it for.

[![Build](https://img.shields.io/github/actions/workflow/status/USER/REPO/test.yml?branch=main&style=flat-square)](https://github.com/USER/REPO/actions)
[![Coverage](https://img.shields.io/codecov/c/github/USER/REPO?style=flat-square)](https://codecov.io/gh/USER/REPO)
[![npm version](https://img.shields.io/npm/v/PACKAGE?style=flat-square)](https://www.npmjs.com/package/PACKAGE)
[![Downloads](https://img.shields.io/npm/dm/PACKAGE?style=flat-square)](https://www.npmjs.com/package/PACKAGE)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

## Why this exists

[2–3 sentences: problem solved, what alternatives exist, what makes this different.]

## Install

```bash
npm install @org/package
# or
pnpm add @org/package
# or
yarn add @org/package
```

Requires Node 18+.

## Quick start

```ts
import { thing } from '@org/package'

const result = thing('input')
console.log(result)
// → "expected output"
```

## API

### `functionA(arg: string, options?: OptionsA): Result`

[1-sentence purpose.]

- `arg` — [description]. Required.
- `options.x` — [description]. Default: `…`.

```ts
functionA('example')
```

### `functionB(input: T[]): U[]`

[…]

## Examples

### Use case 1: [scenario]

[Brief context.]

```ts
// realistic code
```

### Use case 2: [scenario]

```ts
// realistic code
```

## TypeScript

Types are bundled. Strict-mode safe.

```ts
import type { OptionsA, Result } from '@org/package'
```

## Compatibility

| Runtime | Status |
|---|---|
| Node ≥18 | ✅ Tested in CI |
| Bun ≥1.0 | ✅ Tested in CI |
| Deno ≥1.30 | ⚠️ Untested but should work |
| Browsers (ESM) | ✅ Modern browsers |

## Contributing

Issues and PRs welcome. Before submitting:

```bash
npm test
npm run lint
npm run format
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## License

[MIT](LICENSE) © 2026 Your Name
