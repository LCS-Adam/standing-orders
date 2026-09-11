---
name: verify-unexecuted
description: Syntax-gate and body-flow smoke for scripts that ship UNEXECUTED by construction (NEEDS-claw / LIVE-VM / operator-run-later boundary verifiers whose preconditions do not exist in the build env). Use before committing such scripts. Not for scripts you can actually run end-to-end (just run them).
---

# verify-unexecuted

## Purpose
The one artifact carrying a security boundary's verification is often the one with zero verification, because its preconditions (a second UID, a live VM, an admin account) do not exist at build time. A syntax error in it first surfaces as the privileged user on the live box (learned rule #31). This skill makes such scripts PARSE and body-FLOW at build time without their preconditions.

## Procedure
1. **Enumerate the script set** — the top-level script AND every file it `source`s. `bash -n` does NOT follow `source` at runtime, so each sourced lib must be checked directly.
   ```bash
   grep -nE '^[[:space:]]*(source|\.)[[:space:]]+' "$SCRIPT"   # discover sourced libs; confirm by reading
   ```
2. **Syntax gate every file.**
   ```bash
   FAIL=0
   for f in "$SCRIPT" $SOURCED_LIBS; do
     case "$f" in
       *.py) python3 -m py_compile "$f" && echo "PASS py_compile $f" || { echo "FAIL py_compile $f"; FAIL=1; } ;;
       *)    bash -n "$f"            && echo "PASS bash-n $f"        || { echo "FAIL bash-n $f"; FAIL=1; } ;;
     esac
   done
   ```
3. **Forced-guard body-flow smoke.** The refusal/guard path passing proves NOTHING about the body (learned rule #31). Force past the guard on an EDITED COPY (never the real script) with a stub so inner privileged sections run to completion or correctly SKIP:
   ```bash
   TMP=$(mktemp -d); cp "$SCRIPT" "$TMP/smoke.sh"
   # shim id() so guards think we are the privileged user but the real uid keeps cross-UID sections SKIPping:
   printf '#!/bin/bash\ncase "$1" in -un) echo claw;; -u) echo 502;; *) exec /usr/bin/id "$@";; esac\n' > "$TMP/id"
   chmod +x "$TMP/id"
   PATH="$TMP:$PATH" bash "$TMP/smoke.sh"; echo "EXIT=$?"
   ```
   Confirm each body region prints its PASS/RUN marker (or an intentional SKIP), not a runtime error.
4. **Report** which sections RAN vs SKIPPED and why.

## Output contract
```
VERIFY-UNEXECUTED: PASS | FAIL
files: [ {path, gate: bash-n|py_compile, status} ... ]
body_flow: reached-completion | errored-at:<marker>
sections: [ {name, RAN|SKIPPED, reason} ... ]
```
FAIL if any file fails its gate OR the forced-guard body errors (vs intentionally skips). A smoke that sourced a MISSING lib and silently no-oped every assert is itself a FAIL — the harness must fail loud on absence, never print "all passed" over a vanished lib (learned rule #37).

## Invocation
Interactive `/verify-unexecuted <script>`, or as a build/commit-time step feeding the commit gate (the E3 adoption fix). Not scheduled.

## Relationship / rules
Companion to learned rules #20 (a silent success path can't be verified — here the success path exists but was never reached) and #37 (prove exploit fixes both directions on runnable proxy code).

## Residual risk
A forced-guard stub can mask a real environmental dependency the smoke does not model; this proves the script PARSES and FLOWS, not that it does the right thing on the live box. The operator's real run as the privileged user remains the final gate.
