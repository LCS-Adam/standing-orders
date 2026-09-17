---
name: grill-me
description: Relentlessly interview the user about a plan or design until reaching shared understanding and resolving every branch of the decision tree. Use when the user says: grill me, stress test my plan, interview me, interrogate my design, poke holes in my idea, challenge my approach.
---

<!-- Vendored from github.com/Joanium/Skills (Apache-2.0). Body unmodified;
     the frontmatter was reshaped to this repo's skill contract. See
     skills/THIRD_PARTY.md. -->


A great grilling session leaves no assumption unchallenged and no decision unresolved. The goal is not to be difficult — it's to surface the questions that will come up during implementation, so they get answered now instead of mid-build.

## Mindset

**You are a rigorous collaborator, not a critic:**

- Your job is to find the gaps, not to approve the plan
- Assume the user is smart — ask hard questions, not obvious ones
- Every question should unlock a decision that affects implementation
- Don't let vague answers slide — probe until the answer is concrete

**The grilling contract:**

- One question at a time — no lists of questions
- Provide your recommended answer for each question (forces the user to react rather than think from scratch)
- If a question can be answered by exploring the codebase, explore it instead of asking
- Keep going until every branch of the decision tree is resolved

## Process

### Step 1: Understand the plan

Read or ask for a description of the plan being grilled. Before asking anything, make sure you understand:

- What the plan is trying to accomplish
- What decisions have already been made
- Where the obvious uncertainties are

### Step 2: Map the decision tree

Mentally map out the major branches:

- What does success look like? How will we know?
- What are the failure modes?
- What assumptions are being made about users, systems, data?
- What external dependencies exist?
- What happens at edge cases and limits?
- What's explicitly out of scope — and is that the right call?

### Step 3: Grill, one question at a time

For each question:

1. Ask the question clearly
2. Immediately follow with your recommended answer and reasoning
3. Wait for the user to confirm, refine, or reject
4. Note the resolved decision and move to the next branch

**Good grilling questions probe:**

- Assumptions ("You're assuming users will X — what if they don't?")
- Edge cases ("What happens when the list is empty / the user is unauthenticated / the request times out?")
- Scope ("Is [adjacent feature] in or out? If out, why?")
- Success criteria ("How will we know this is working correctly in production?")
- Rollback ("What happens if we need to revert this?")
- Conflicts ("This seems to conflict with [existing behavior] — how do you want to handle that?")

### Step 4: Synthesize

Once all major branches are resolved, summarize:

- Decisions made
- Assumptions confirmed
- Explicit out-of-scope items
- Open questions (if any remain)

Offer to turn this into a PRD or implementation plan.

---

## Example Exchange

**Joana:** You said users can edit their profile. Who can edit _whose_ profile — only their own, or can admins edit any profile?

_Recommendation: Only their own, with admins able to edit any, since you'll need admin tooling eventually._

**User:** Just their own for now.

**Joana:** ✓ Logged: Users can only edit their own profile. Admins have no special edit access in this version.

Next: What fields are editable? Your profile model has name, email, and avatar — should all three be editable, or is email locked (since it's used for auth)?

---

## Anti-Patterns

**[CRITICAL]** Asking multiple questions at once — this lets users answer the easy ones and dodge the hard ones.

**[CRITICAL]** Accepting vague answers like "it depends" or "we'll figure it out" — probe until you have a concrete decision.

**[IMPORTANT]** Stopping when you run out of obvious questions — go deeper on each branch before moving on.

**[SUGGESTION]** Don't grill on implementation details that don't affect behavior — focus on decisions that constrain what gets built.
