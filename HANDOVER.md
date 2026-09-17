# Handover

This repository is ready for a company to run against and test. It has not been used at that scale
yet, so this page says what is verified, what is not, and what to do first.

## Start here

```bash
git clone <this-repo> ~/projects/agent-harness
cd ~/projects/agent-harness
./bin/harness upstream           # clone the referenced repos into .upstream/
./bin/harness install --user     # deploy the core into ~/.claude
./bin/harness verify             # the scrub gate, fourteen checks
```

Clone before install. `install` deploys the upstream skills that `config/upstream.conf` marks with
`install=`, and it can only deploy what is already on disk.

Then read `README.md` and follow its reading map. A new engineer's first week is laid out at the end
of `docs/first-day.md`, and `docs/scenarios.md` shows the harness running end to end on five
differently shaped projects, including one where the right call is not to use it.

## What is verified, and what is not

**Verified by running it.** Everything on the Claude Code side: the installer, the scrub gate, the
model-pin hook, the tier resolver's self-test, the upstream clone and install path. The gate exits 0
at fourteen checks and each check has been shown to fail on a planted defect of the kind it claims
to catch.

**Verified only against vendor documentation.** Everything on the Augment side. Auggie has never
been installed on the machine this was built on, so every Augment claim in `adapters/README.md`,
`docs/augment-context.md` and `docs/augment-runbook.md` carries a label saying it came from a
documentation capture dated 2026-09-16, or says NOT FOUND. `docs/augment-runbook.md` is the
procedure that turns those into verified claims, and it names which cell of the status table each
step flips. Run it on a machine that has Auggie before trusting that half.

**Not built at all, and stated where it matters.** There is no deploy skill, no QA skill, no
whole-build red-team agent, and no CI mode that validates git index blobs rather than the working
tree. `docs/finishing-a-build.md` opens with a has and does-not-have table per stage rather than
implying coverage the harness does not have.

## Two things a reviewer should read before adopting it

`docs/operating-boundaries.md` is written for the person who has to approve this. Two disclosures in
it matter more than the rest.

The optional external-review step hands a third-party CLI, and the cloud model behind it, read
access to the repository for the duration of a review. It is not a one-file upload. If that is
unacceptable, the step is optional throughout and the gate stack works without it.

An `install=` entry in `config/upstream.conf` deploys another project's skills, which this gate does
not scan. The gate prints the count on every run. Remove the `install=` fields and the harness
works without them.

## Known gaps, in the order they are likely to bite

1. The Augment half is documentation-verified only. Runbook first.
2. The gate reads your working tree, not the index. Run it on a clean tree.
3. The Augment tool-permission rules are regex over shell text. They stop the mistakes people type,
   and an outside reviewer defeated an earlier version of them in minutes. They are not a sandbox,
   and `verify.sh` says so where the rules are checked.
4. Some of what sits under `skills/` is a pinned snapshot of upstream work. That upstream is now
   referenced and installed, so those copies are a no-network fallback. `skills/THIRD_PARTY.md`
   names them and records what retiring them costs.

## How this was built, since it affects how much to trust it

The documentation set was written from research passes that read the code, then handed to writers,
then reviewed. Two independent adversarial reviews ran against the result: one from the same model
family, one from a different vendor. Between them they found four blockers, and every one was a
guard that reported success while doing nothing. Both reports are worth reading if you want to
calibrate: they are not in this repository, because agent output belongs under `runtime/`, which is
gitignored.

The gate is the thing to trust most, and only as far as its stated ceilings. Each one is written
next to the check it limits rather than collected here.
