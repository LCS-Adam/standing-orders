# Accessibility Checklist

README files must be readable by screen readers, color-blind users, low-vision users, and keyboard-only users. The bar isn't WCAG-compliant — it's "no one bounces because they can't parse this."

## Heading hierarchy

- One `#` per file (the title).
- Then `##`, `###`, `####`. **Never skip levels.** (`## A` → `#### B` confuses screen readers.)
- Heading text describes the section, not "Section 3.2".

**Bad:**

```markdown
# Title
### Install            ← skips H2
```

**Good:**

```markdown
# Title
## Install
### macOS              ← H3 under H2 is fine
### Linux
```

## Alt text on images

Every image needs descriptive alt text:

```markdown
![Alt: Project logo — stylized fox curled around a leaf](docs/logo.png)
![Alt: Architecture diagram showing client, API gateway, cache, and database](docs/arch.png)
![Alt: Build passing](https://img.shields.io/...)
```

**Rules:**
- Describe what's shown, not what it is (`Architecture diagram showing X, Y, Z` beats `architecture`).
- For decorative-only images, use `alt=""` to skip screen-reader announcement.
- For badges, the badge's text is the alt (`Alt: Build passing` for a green build badge).
- Never use the filename as alt text (`![logo.png](logo.png)`).

**Bad:** `![image](logo.png)` — useless to a screen reader.
**Good:** `![Alt: Stylized fox logo on white background](logo.png)`

## Link text

Use descriptive link text. A screen-reader user scanning links should know where each goes.

**Bad:**

```markdown
For more info, [click here](docs/).
[Read more](api.md).
[Link](https://example.com).
```

**Good:**

```markdown
See the [API reference](api.md).
[Configuration guide](docs/config.md) explains all options.
Compare to the [original benchmark methodology](https://example.com/method).
```

## Color is not signal

Never communicate status with color alone. Pair color with text or emoji-with-text.

**Bad:**

```markdown
🟢 Production
🟡 Staging
🔴 Down
```

(A color-blind user sees three identical dots.)

**Good:**

```markdown
✅ Production — operational
⚠️ Staging — degraded
❌ Down — under maintenance
```

Even with emoji, the text after is what carries the meaning.

## Code fences with language tags

````markdown
```bash
npm install
```
````

Not:

````markdown
```
npm install
```
````

Language tags enable syntax highlighting (helpful for sighted users) and let screen readers announce "code block, language bash" instead of just "code block."

## Tables with headers

Always include a header row:

```markdown
| Command | Description |
|---|---|
| `init` | Create a project. |
```

Screen readers use the header row to announce each cell as "Command: init" rather than just "init".

## Relative links over absolute when possible

```markdown
See [CONTRIBUTING.md](CONTRIBUTING.md).
```

Better than:

```markdown
See [CONTRIBUTING.md](https://github.com/user/repo/blob/main/CONTRIBUTING.md).
```

Relative links survive forks, mirrors, and branch renames. Use absolute URLs only for external resources.

## Avoid walls of text

Long paragraphs are hard for everyone. Break into:
- Short paragraphs (≤4 lines each).
- Bullet lists for parallel items.
- Tables for comparisons.
- Headings every 1–2 screens of text.

## Language clarity

- Define jargon on first use.
- Spell out acronyms first time: "Continuous Integration (CI)" → use "CI" after.
- Avoid metaphors that don't translate (idioms, sports references).
- Keep sentences ≤25 words where possible.

## Final pass

Before declaring done:

1. Render the README in GitHub's preview.
2. Tab through every link with keyboard — order should make sense.
3. Read aloud the first paragraph. If you stumble, rewrite.
4. View with browser zoom at 200%. Layout still works?
