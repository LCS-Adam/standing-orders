# Joanium skills: a two-level taxonomy

`config/upstream.conf` references github.com/Joanium/Skills: over six thousand markdown skills in
one flat directory. This is the structure that makes it browsable, and `joanium-assignment.tsv`
places every file in it.

One file is deliberately absent. `GrillMe.md` was adopted into this repository as
`skills/grill-me/` and is recorded in `skills/THIRD_PARTY.md`; listing it here as well would count
it twice. The synthesis had also filed it alongside a pair of interview-preparation entries on the strength of
its name, which reading the file disproves: it interrogates a plan or design. That is the failure
mode the hand-written files are most exposed to, since the rules key off name stems.

The corpus itself is NOT in this repository. It is 42 MB of someone else's Apache-2.0 work, so what
is committed here is the taxonomy and the per-file assignment, which are small and reviewable.
`harness upstream` clones the corpus; `joanium-assign.py` regenerates the assignment from that
clone, so the mapping is reproducible rather than a one-off judgment.

How it was built: eight agents each read a hash-partitioned sample of the whole corpus and proposed
a taxonomy independently, then one synthesis pass merged the eight and wrote the rules that assign
every file. The proposals are not committed; the merge below records where they disagreed and which
way it went.

## What the corpus actually is

The eight proposals converged on a structural fact that decides how the merge has to work: the
corpus is a cartesian product. 5,000 rows carry the description template "Expert-level guidance
for X" and are a 2-3 word topic STEM plus a 2-3 word MODIFIER drawn from a family of ten
("Abuse Triage" x {Governance, Diagnostics, ...}; "API Incident Triage" x {Retry Discipline,
Backpressure Signals, ...}). 600 rows are "Practical guidance for X" with one modifier word. Only
484 rows are hand-written. (`assign.py` treats 1,050 rows as singletons: the 484 plus 566
Expert-template rows of fewer than four words, such as "Onboarding Post-Launch Analysis", where
the modifier cannot be stripped safely and the whole name is matched instead. That is why the
anchored onboarding rule and the cost-guardrails rule exist.)

That means the stem carries the business use case and the modifier is noise for level 1. Every
proposal that grouped by the modifier ("Governance", "Cost", "Testing", "Incident") produced a
folder that cut across every domain. The synthesis matches rules against the stem only, and the
modifier is allowed to choose a level-2 folder within the same level-1 group, never to cross one
(with a single exception, rule B2 below).

## Level-1 count: 16

The proposals estimated 10-16 (P1 12-16, P2 12-16, P3 10-14, P4 10-14, P5 10-14, P6 14-16,
P7 10-14, P8 12-15). The intersection is 12-14. The merge lands at 16 because three groups the
smaller batches called thin are real at corpus scale: mobile-and-desktop-apps (273 files),
specialized-and-systems-engineering (288), and product-and-project-management (287), which has
a product-manager reader distinct from both people management and documentation. Going down to
14 means fusing mobile into frontend (600 to 873 files) and specialized systems into
software-engineering-craft (359 to 647), which is the "2,000-file folder that organises nothing"
failure. Going up to 18 or more starts splitting on technology (cloud vs Kubernetes, docs vs
video) rather than on who reaches for the folder.

The distribution is uneven and left that way: the largest group is 650 files (10.7%), the
smallest 135 (2.2%). Forcing an even split would require moving hiring skills into a folder
nobody hiring would open.

## Level-1 groups

Counts are files; percentages are of 6,084. Level-2 folders are listed largest first.

### security-and-trust (465, 7.6%)
Keeping systems, data, and users safe from attackers, misuse, and audit failure.

| level 2 | files |
|---|---|
| identity-and-access | 174 |
| attack-defense-and-hardening | 111 |
| secrets-and-key-management | 94 |
| abuse-and-fraud-defense | 62 |
| compliance-privacy-and-audit | 24 |

Converged: all eight (P1 security-and-trust, P2 trust-and-safety, P3 security-and-identity,
P4 security-risk-and-compliance, P5 application-security-and-compliance, P6/P7/P8
security-and-trust). Overruled P2's separate `policy-governance-and-audit`: it was built on the
modifier words Governance and Audit, which contradicts P2's own "topic noun wins" rule. Its
audit-trail examples land in compliance-privacy-and-audit here; its community-moderation example
goes to content-and-communication and its cross-browser-policy example to testing.

### reliability-and-incident-response (273, 4.5%)
Keeping a live service healthy and recovering fast when it breaks.

| level 2 | files |
|---|---|
| incident-response-and-postmortems | 98 |
| production-diagnostics-and-triage | 54 |
| resilience-and-failure-isolation | 53 |
| observability-and-slos | 37 |
| backup-and-disaster-recovery | 31 |

Converged: all eight name it. Overruled P4 and P8, which fused it with platform operations into
an 18-19% bucket: the on-call reader and the platform-engineering reader are different people.
Overruled P4, P6, and P7, which put ETL repair and API incident triage here; those go to data and
backend per the domain-owner rule B3, which is a minority position (P1's) chosen deliberately.
Queue backpressure stays (it is unscoped). This group is smaller than the proposals estimated
(they said 8-20%) precisely because B3 sends every technology-scoped incident skill to its
technology.

### platform-and-cloud-infrastructure (410, 6.7%)
Running the infrastructure under products and shipping changes to it safely.

| level 2 | files |
|---|---|
| ci-cd-and-release-pipelines | 155 |
| platform-engineering-and-tenancy | 128 |
| capacity-and-cost-governance | 54 |
| cloud-and-kubernetes-operations | 53 |
| systems-administration-reference | 20 |

Converged: P1, P3, P5, P6, P7 as a standalone group; P4/P8 fused with reliability. Overruled P2's
`cost-and-resource-governance`: cost content is always attached to a system in this corpus (P1
said so explicitly), so cloud cost stays here, warehouse cost guardrails go to data, battery and
bundle budgets go to mobile and frontend, and LLM cost goes to AI. Overruled P3's
`os-and-tooling-reference` at 1%: P3 itself recommended folding it, so the 20 linux-/windows-/macos-
reference files sit here as systems-administration-reference. The GitHub Actions and Platform
Engineering stem families stay whole (they are Expert-template rows, so the modifier is
stripped), while the AWS/Azure/GCP/Docker/Kubernetes/Terraform blocks are singletons and split
by modifier across the level-2 folders; that asymmetry is at level 2 only.

### data-platform-and-analytics (624, 10.3%)
Moving, modeling, and trusting data at scale, from ingestion to metrics.

| level 2 | files |
|---|---|
| databases-and-warehouses | 183 |
| pipelines-and-ingestion | 152 |
| metrics-and-analytics | 126 |
| schema-and-data-contracts | 103 |
| data-quality-and-governance | 60 |

Converged: all eight. Standalone database engines (PostgreSQL, MySQL, MongoDB, Redis, SQLite,
Snowflake, dbt, Spark, Kafka, Airflow blocks) live here per P3's rule; framework cache
invalidation (DjangoCacheInvalidation) stays with the backend framework. Data retention
(enforcement and policy) is here, not compliance: its modifier family is the data-governance one
(Lineage Records, Migration Windows), so a data engineer acts on it.

### ai-and-agent-systems (650, 10.7%)
Building, evaluating, and operating LLM- and ML-backed products and agents.

| level 2 | files |
|---|---|
| evaluation-and-labeling | 154 |
| agents-and-tool-use | 115 |
| model-serving-and-cost | 107 |
| retrieval-search-and-embeddings | 94 |
| safety-and-guardrails | 63 |
| prompting-and-context | 56 |
| machine-learning-and-vision | 44 |
| model-provider-guides | 17 |

Converged: all eight. The 17 provider prompting guides (Claude, GPT-4o, Llama, Qwen, ...) that P3
and P4 called homeless are given their own level-2: they are prompting references and the AI
reader is who wants them. Ranking, recommender, and forecast-backtesting skills come here rather
than data because their modifier family is the ML-evaluation one (Gold Set Curation, Model Card
Signals), which P4 and P8 both used as the tiebreak ("the object under review is a model").

### backend-and-api-engineering (440, 7.2%)
Designing the services, APIs, and integrations that other systems consume.

| level 2 | files |
|---|---|
| service-architecture-and-decomposition | 127 |
| integrations-and-webhooks | 103 |
| backend-framework-patterns | 103 |
| api-design-and-lifecycle | 57 |
| messaging-queues-and-realtime | 29 |
| payments-and-billing | 21 |

Converged: P1 api-and-service-architecture, P2 api-and-integration-design, P3
api-and-service-design, P5 api-integration-and-contracts, P6 backend-and-application-engineering.
Overruled P4 and P8, which folded this into a 22-30% software-engineering bucket. The backend
framework block (Django, Express, FastAPI, NestJS, Rails, ASP.NET Core, Spring Boot, gRPC,
GraphQL, REST x pagination, idempotency, multi-tenant isolation, contract evolution, auth flows,
cache invalidation, observability contracts, rate limiting, background jobs) is P6's call over
P3's "framework idiom belongs with the language": every modifier in that block is a
service-design concern, and the reader is building a service. Payments and billing (P7 put
PaymentIntegration in infrastructure) get a small level-2 here because the Billing Workflow Repair
family uses the same incident-family modifiers as API Incident Triage.

### software-engineering-craft (359, 5.9%)
Writing, reviewing, building, and maintaining code in a given language.

| level 2 | files |
|---|---|
| version-control-and-builds | 118 |
| languages | 107 |
| code-quality-and-refactoring | 86 |
| developer-tooling-and-experience | 25 |
| algorithms-and-fundamentals | 23 |

Converged: P1 language-and-platform-specific-engineering, P2 software-engineering-fundamentals,
P3/P5 language-and-framework-engineering, P4 software-engineering-craft, P7
language-and-framework-reference, P8 software-engineering-practice. Overruled P4 and P8 on
scope: they also put testing and service architecture here; those are separate groups (P1, P3, P5,
P6, P7 all kept testing apart). The language block (Java, Python, TypeScript, JavaScript, Kotlin,
Swift, Rust, Go, C#, C++ x concurrency, debug workflows, error semantics, interop, profiling, type
architecture, test harness design) stays whole in `languages`, including the test-harness rows,
by rule B4. The 17 esoteric single-language files (Zig, Odin, Haxe, Gleam, Janet, Racket, ...) the
proposals left unhomed are in `languages` too: "I am working in this language" is the entry point
regardless of the language's popularity.

### testing-and-quality-assurance (272, 4.5%)
Proving software behaves, as a process independent of any one language.

| level 2 | files |
|---|---|
| browser-and-end-to-end-testing | 154 |
| test-strategy-and-harnesses | 57 |
| flaky-tests-and-determinism | 40 |
| bug-reproduction-and-triage | 21 |

Converged: P1, P3, P5, P6, P7 standalone; P2, P4, P8 folded it into engineering. Kept standalone
because five of eight did and because the corpus has a 270-file block whose reader is a QA
engineer (browser orchestration, flake triage, exploratory QA, contract and property testing).
Language and framework test-harness rows are NOT here (rule B4), which is why this group is
smaller than P1's 7% estimate.

### frontend-and-user-experience (600, 9.9%)
Building interfaces people can see, use, and trust.

| level 2 | files |
|---|---|
| frontend-frameworks-and-performance | 214 |
| ux-research-and-interaction-design | 188 |
| design-systems-and-visual-design | 135 |
| accessibility | 63 |

Converged: all eight under varying names (frontend-ux-and-design-systems,
accessibility-and-design-systems, frontend-and-ux-engineering, ux-design-and-content,
frontend-and-product-engineering, design-and-frontend-craft, design-and-user-experience).
Overruled P4's fusion of microcopy with content: microcopy and UX writing stay here, editorial
goes to content-and-communication. The frontend framework block (React, Vue, Angular, Svelte,
Nuxt, Next.js, Remix, Astro, SolidJS, Web Components x accessibility flows, build pipelines,
component testing, form systems, hydration, rendering, routing, state) lives here rather than in
craft, per P6's split, because the reader is building a UI. The hyphenated design-fundamentals
pack (Color-Theory, Layout-Composition, Icon-Design, Graphic-Design-Print, Illustration-Style,
Photography-Direction, Creative-Direction) that P6 and P7 left unhomed sits in
design-systems-and-visual-design.

### mobile-and-desktop-apps (273, 4.5%)
Shipping and running software on end-user devices that the team does not control.

| level 2 | files |
|---|---|
| device-connectivity-and-offline | 95 |
| release-and-app-store-delivery | 84 |
| notifications-and-deep-links | 73 |
| native-and-desktop-development | 21 |

Converged: P3 mobile-and-cross-device-experience, P4 client-delivery-and-device-ops, P5
mobile-and-device-release-engineering, P6 mobile-app-delivery, P8 mobile-and-app-distribution.
P1, P2, P7 did not see enough rows to propose it; at 273 files the corpus supports it. Desktop
(Electron, Tauri, Desktop App Recovery, Clipboard, Download Flow) joins per P4's "client delivery"
framing. Crash Forensics comes here (P8) rather than reliability (P5): its modifier family is
Build Signing, Store Readiness, Rollback Channels, all release-train terms. Install Funnels and
App Store Optimization stay with mobile rather than growth by the stem rule (P8 had ASO in
marketing; noted as a judgment call).

### product-growth-and-marketing (441, 7.2%)
Acquiring, converting, activating, and retaining customers, and pricing what they buy.

| level 2 | files |
|---|---|
| acquisition-funnels-and-campaigns | 137 |
| onboarding-activation-and-retention | 112 |
| experimentation | 73 |
| pricing-and-packaging | 62 |
| market-and-customer-insight | 42 |
| social-media-marketing | 15 |

Converged: all eight (growth-lifecycle-and-marketing, product-growth-and-experimentation,
product-growth-and-marketing, product-growth-and-lifecycle, growth-and-customer-lifecycle).
Overruled P8's split of marketing campaigns into a separate 4% group: the campaign content in the
corpus is funnel content. Experimentation stays here rather than in testing (P3's reasoning: the
reader is a PM, not QA), including Experiment Guardrail Metrics, which the word "guardrail" would
otherwise have pulled into AI safety.

### product-and-project-management (287, 4.7%)
Deciding what to build, defending the tradeoffs, and coordinating delivery.

| level 2 | files |
|---|---|
| planning-cadence-and-delivery | 96 |
| decisions-rfcs-and-memos | 59 |
| roadmaps-and-prioritization | 53 |
| launch-coordination | 51 |
| strategy-and-business-planning | 28 |

Converged: P3 engineering-process-and-collaboration, P6 business-operations-and-strategy, P8
product-strategy-and-decisions, and half of P4's team-and-org-operations. The Launch, Roadmap,
Decision Memo, Prioritization, Work Intake, Weekly Planning, and RFC stem families (about 290
files) have a reader who is neither an engineering manager nor a technical writer. Adopted P8's
placement of RFCs, ADRs, and decision memos here rather than in documentation ("the artifact's
purpose is a decision, not durable reference"). Startup strategy, fundraising, pitch decks, and
financial modeling (P2's business-and-career leftovers) sit in strategy-and-business-planning.

### customer-and-revenue-operations (226, 3.7%)
Running the ongoing relationship with customers and buyers: support, success, sales.

| level 2 | files |
|---|---|
| support-operations | 91 |
| sales-and-partner-operations | 64 |
| customer-success-and-retention | 41 |
| feedback-and-voice-of-customer | 30 |

Converged: P3 customer-success-and-support, P4 customer-and-revenue-operations, P6 and P8
customer-support-and-success, plus P8's sales-and-revenue-operations. P8's separate sales group
at 2% is merged as a level-2 (64 files). Renewal risk, account health, and success playbooks are
here (an account owner acts on them); churn signals, retention programs, and winback are in growth
(product lifecycle mechanics). P3 and P6 put churn in customer success; P2, P4, P7, and P8 put
it in growth, and the growth majority wins.

### content-and-communication (341, 5.6%)
Producing documentation, media, and editorial material for a human audience.

| level 2 | files |
|---|---|
| video-and-media-production | 102 |
| technical-documentation | 97 |
| internal-knowledge-and-research | 71 |
| editorial-and-copywriting | 49 |
| community-and-creator-programs | 22 |

Converged: P1 content-docs-and-technical-writing, P2 documentation-and-technical-writing, P3 and
P4 content-and-media-production, P5 content-and-audience-communications, P7
content-comms-and-knowledge-ops, P8 content-and-documentation. Editorial production (calendars,
quality control, repurposing, copywriting, newsletters) is here; social-media distribution
(hashtags, carousels, thread writing) is in growth. That is the P8 split, applied by whether the
deliverable is the content or the audience. Community moderation and health are here, not in
trust-and-safety (P2 dissent): the corpus's community stems are about running a community, and
abuse handling has its own security folder.

### people-and-engineering-management (135, 2.2%)
Hiring, onboarding, developing, and leading the people who do the work.

| level 2 | files |
|---|---|
| hiring-and-interviewing | 63 |
| employee-onboarding-and-training | 31 |
| performance-and-team-health | 30 |
| leadership-and-career-growth | 11 |

Converged: P1, P3, P5, P7, P8 (people/hiring), P4 team-and-org-operations. P3 warned it might be
under 2% and worth folding; at 135 files it is the smallest group, but every alternative home
buries hiring under a reader who is not hiring. P2's career-development leftovers (interview
prep, resume writing, personal branding, GrillMe) sit in leadership-and-career-growth.

### specialized-and-systems-engineering (288, 4.7%)
Domain engineering outside the web and cloud stack: embedded, robotics, compilers, OS internals,
hardware, graphics, games, media pipelines, scientific computing.

| level 2 | files |
|---|---|
| embedded-iot-and-robotics | 114 |
| graphics-games-and-media-engineering | 75 |
| compilers-os-and-networking | 72 |
| scientific-and-emerging-computing | 16 |
| hardware-and-computer-architecture | 11 |

Converged: P3 specialized-and-embedded-systems, P5 hardware-embedded-and-robotics, P6
systems-and-specialized-engineering. Only three of eight, but the corpus holds 288 files here
(Robotics alone has 41 stems). Overruled P1, which filed embedded under
language-and-platform-specific, and P7/P8, which left DSP, register-file design, and quantum
computing unhomed. Stream encoding, stream quality adaptation, video transcode economics, and
WebRTC are media ENGINEERING and sit here, not in content production.

## Boundary rules

These are the rules `assign.py` applies, in the order they are tested. Stated as rules, not
instances, because they had to hold 6,084 times.

**B1. The stem decides level 1; the modifier decides at most level 2.** "Abuse Triage
Governance" is abuse (security), not governance. "Signup Funnel Repair Usability Testing" is a
funnel (growth), not testing. This is P2's rule, stated explicitly there and applied by example in
P1, P4, P6, P8. It dissolves P2's own cost and policy groups.

**B2. The only modifier that crosses a level-1 boundary is a security one.** A stem in the
cloud or data family with the modifier Secrets Management or Security Controls
(GCPSecretsManagement, AirflowSecurityControls, PlatformEngineeringSecretsManagement) goes to
security-and-trust/secrets-and-key-management. P1, P5, and P8 each chose this independently: the
reader is the security owner, not the platform owner. Nothing else in a modifier moves a file
across level 1.

**B3. A technology- or domain-scoped incident stays with its domain.** ETL Incident Repair is
data; Kubernetes Incident Triage is platform; API Incident Triage is backend; Supply Chain
Incident Response is security; iOS Release Triage is mobile. reliability-and-incident-response
keeps only unscoped incident practice (postmortems, on-call, comms, evidence) and infrastructure-
level failure isolation (backpressure, failure domains, chaos, backups). This is a minority
position: P1 stated it for data pipelines; P4, P6, and P7 put ETL and API incidents in
reliability ("everything incident/triage without an attacker", P6). The mobile and security
halves of the rule are majority positions (P3, P5, P8 for mobile release triage; P3, P6 for
security incidents). The data and API halves were chosen because fixing an ETL or API incident
requires that domain's knowledge, not on-call skills, and because a rule with two exceptions is
not a rule an assignment script can apply 6,084 times.

**B4. A generated technology family stays whole in one level-1 folder.**
Languages go to software-engineering-craft, frontend frameworks to frontend-and-user-experience,
backend frameworks to backend-and-api-engineering, data stores to data-platform-and-analytics,
cloud providers to platform-and-cloud-infrastructure, the systems "lab" families (Robotics,
Embedded, Compiler, Operating Systems, Networking, Graphics, Game) to specialized. Within the
level-1 group the modifier may choose the level-2 folder (React Accessibility Flows to
accessibility, Java Build Toolchains to version-control-and-builds). Java Test Harness Design and
Java Testing with JUnit therefore sit in craft/languages, not in testing; P3 and P4 placed them
that way, P6 did not. The rule covers the generated blocks. The hand-written Java pack is split by
topic where the topic is unmistakable: JavaSecurity.md is in security under the spirit of B2,
JavaMicroservices.md and JavaJPAHibernate.md are in backend.

**B5. Same word, two readers: the modifier family breaks the tie.** The corpus reuses
"Onboarding", "Case Study", "Demo", "Community", "Review Queue" across unrelated businesses. The
modifier family identifies the generator and therefore the reader: hiring-family modifiers (Bias
Mitigations, Calibration Sessions, Evaluation Packets) mark Onboarding Program Design and Case
Study Interviewing as people; PM-family modifiers (Decision Memos, Metric Trees, Problem Framing)
mark Onboarding Friction and Customer Research as growth; UX-family modifiers (Edge State
Coverage, Handoff Specs) mark Onboarding Experience as frontend; docs-family modifiers
(Searchability, Cross-Linking) mark Onboarding Documentation as employee onboarding docs (P4's
employee-vs-customer split). ML-evaluation modifiers (Gold Set Curation, Model Card Signals)
mark Ranking System Tuning and Human Review Queues as AI, not data or support.

**B6. Who acts on it decides between adjacent business groups.** Churn, retention programs,
activation, winback: a growth PM acts, so growth. Renewal risk, account health, success playbooks:
an account owner acts, so customer-and-revenue. Editorial calendar, copywriting, repurposing: a
content producer acts, so content. Hashtags, carousels, thread writing: a social marketer acts,
so growth. Cost attached to a named system: that system's owner acts, so cost stays with the
system (P1) rather than in a FinOps folder (P2).

**B7. Reference material with no workflow goes where its reader would already be looking.**
OS and shell reference to platform/systems-administration-reference; single-language references
to craft/languages; model-provider prompting guides to ai/model-provider-guides. No
"reference" or "miscellaneous" folder exists.

## Placements that are judgment calls

Every file has a defended home; these are the ones where a reviewer could reasonably disagree.

| file or stem | placed in | why, and the alternative |
|---|---|---|
| Narrative Testing Systems (10) | content/editorial-and-copywriting | Generic modifiers; read as audience narrative testing. Alternative: growth/experimentation. |
| Legal Contract Review | security/compliance-privacy-and-audit | Vendor MSAs and NDAs are a risk review. Alternative: product-and-project-management/strategy. |
| Persona & Character System Design | ai/prompting-and-context | Description says AI persona system prompts. P7 read it as creative and left it unhomed. |
| Financial Modeling, Fundraising, Pitch Deck, Startup Strategy | product-and-project-management/strategy-and-business-planning | P2's business-and-career group had no corpus support for a level 1; these are planning artifacts. |
| TechnicalInterviewPreparation, SystemDesignInterview | people/leadership-and-career-growth | Candidate-side interview prep; the hiring folder is employer-side. |
| WriteASkill, hook-writing, GitGuardrails (Claude Code) | craft/developer-tooling-and-experience, craft/version-control-and-builds | Tooling for the engineer's own workflow. GitGuardrails would otherwise match the "claude" provider rule. |
| Search Index Recovery, Search Architectures | ai/retrieval-search-and-embeddings | Search is grouped with retrieval; a data engineer might look in data first. |
| Install Funnels, App Store Optimization, Store Listing Experimentation | mobile/release-and-app-store-delivery | Stem rule (app store). A growth marketer might look in growth first. |
| Semantic Contracts (10) | data/metrics-and-analytics | Semantic-layer contracts. Alternative: schema-and-data-contracts. |
| Community Moderation (11) | content/community-and-creator-programs | P2 put it in trust-and-safety; the abuse folder covers the attacker side. |
| Rate Limit Negotiation (10) | backend/integrations-and-webhooks | Modifier family is the API-integration one (Backoff Policies, Token Refresh); the word "negotiation" would otherwise send it to sales. |
| Data Retention Policy Design | data/data-quality-and-governance | Kept with Data Retention Enforcement (same stem) rather than compliance. |
| Platform Adoption Operations (10) | platform/platform-engineering-and-tenancy | Internal platform adoption by engineering teams; the modifier family is the customer-feedback one. |
| Video Transcode Economics, Stream Quality Adaptation, Stream Encoding, WebRTC | specialized/graphics-games-and-media-engineering | Media engineering, not media production. |
| Debug Docker/Kubernetes, Debug PostgreSQL, Debug Redis | platform, data, data | The "Hyper-specific debugging guide" pack is split by the technology debugged (B4), not kept as one pack. |

## Reproducing and checking the assignment

    python3 assign.py            # writes assignment.tsv; prints level-1 counts; lists unmatched (none)
    python3 assign.py --l2       # adds level-2 counts
    python3 assign.py --stems    # one line per stem family: the review table used to catch misroutes

    wc -l assignment.tsv                                  # 6084
    cut -f1 assignment.tsv | sort -u | wc -l              # 6084
    cut -f2 assignment.tsv | sort | uniq -c | sort -rn    # 16 groups, 650 down to 135
    cut -f2,3 assignment.tsv | sort -u | wc -l            # 80 level-2 folders

The stem table is the check that matters: a stem family split across two level-1 groups is
either a rule-ordering bug or one of the B2/B5 cases named above. In the final run the only
Expert- or Practical-template stem that splits across level 1 is "Case Study" (Case Study
Interviewing to people, Case Study Development to content, a B5 case). The cloud and data-store
blocks are singletons, so their B2 moves (Secrets Management, Security Controls) do not appear as
a family split; they are the only other cross-group moves and are by design.
