---
skill: verification
version: 1.0
when_to_use: every substantial task
when_not_to_use: trivial one-liner edits with no meaningful failure modes
---

# Verification

## Purpose
Enforce the Implement → Review → Resolve loop.
Substantial work must not be self-approved.

## Verification Levels

### Standard
Use for: normal features, routine automation, low-to-medium risk code, plans, file generation.
Default: 1 review cycle. Second pass only if issues are found.

### Critical
Use for: auth, payments, migrations, security-sensitive code, deployment infrastructure, high-impact production changes.
Default: 2 full loops. Explicit residual-risk section. Operator approval gate if not self-executable.

## Review Rubric
Check in this order:
1. correctness against contract
2. completeness
3. edge cases
4. security and risk
5. simplification opportunities
6. consistency with canonical plan and project instructions
7. quality of evidence or justification

## Severity Scale
- **critical** — correctness, security, data integrity, or policy failure
- **major** — meaningful contract mismatch or strong risk of incorrect output
- **minor** — should be fixed but does not invalidate the core result
- **nit** — style only or optional cleanup

## Verdicts
- **PASS** — no material issues
- **ISSUES_FOUND** — non-critical issues remain
- **CRITICAL** — severe issue or unsafe state; escalate immediately

## Review Output Schema

```markdown
## Verification Review

VERDICT: PASS | ISSUES_FOUND | CRITICAL

ISSUES:
- severity:
- location:
- problem:
- recommended fix:

SIMPLIFICATIONS:
- [what can be simplified or removed]

SUMMARY:
- [overall assessment]
```

## Resolution Rules
- fix all critical issues
- fix all major issues
- fix minor issues unless the fix adds disproportionate complexity
- ignore nits unless trivial
- do not add unrelated features during resolution

## Final Status Schema

```markdown
## Verification Status
Level: standard | critical
Verdict: PASS | FIXED | CRITICAL | PARTIAL
Evidence:
- what was checked
- what changed after review
Residual Risk: none | low | medium | high
- explain any unverifiable points
```

## Security Gates
Every verification pass must check:
- exposed secrets or unsafe credential handling
- missing auth or authorization controls
- missing input validation
- hallucinated or typosquatted packages
- unsafe migrations or destructive scripts
- `.env` and secret files properly ignored
- RLS or data access controls when a database is involved
- missing rollback notes for critical changes

## Escalation Rule
Escalate instead of pretending closure when:
- a critical issue remains unresolved
- a required approval has not been granted
- the result depends on facts or files not available
- the contract cannot be satisfied with current information
