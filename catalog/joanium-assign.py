# Regenerates joanium-assignment.tsv from the clone at .upstream/joanium-skills.
# Run it explicitly:  python3 catalog/joanium-assign.py
# No shebang and not executable on purpose: this repo is bash-only by rule
# (rules/shell-portability.md), and the scrub gate refuses a shebanged script
# in another language. This is a data generator, not part of the harness runtime.
"""Assign every skill in skills.jsonl to a (level1, level2) folder pair.

How it works
- The corpus is a cartesian product of a topic STEM and a modifier SUFFIX ("Abuse Triage" x
  "Governance", "API Incident Triage" x "Retry Discipline"). The stem carries the business use
  case; the suffix is interchangeable across domains. So rules are matched against the stem:
  the name minus its last two words for the "Expert-level guidance" template, minus its last
  word for the "Practical guidance" template, and the whole name (plus the camel-split filename)
  for hand-written singletons.
- Rules are an ordered list of (regex, level1, level2); the first match wins. Anchored family
  rules for the generated blocks (cloud providers, backend and frontend frameworks, languages,
  data stores, product-management topics) sit first so a shared modifier word cannot pull a
  file out of its family. FILE_OVERRIDES handles singletons whose name says nothing useful.

Run:  python3 assign.py [--l2] [--stems]
  writes assignment.tsv, prints level-1 counts, optional level-2 counts and a stem table, and
  lists anything unmatched (must be empty).
"""
import json, re, sys, collections, os

HERE = os.path.dirname(os.path.abspath(__file__))

SEC = "security-and-trust"
REL = "reliability-and-incident-response"
PLAT = "platform-and-cloud-infrastructure"
DATA = "data-platform-and-analytics"
AI = "ai-and-agent-systems"
BACK = "backend-and-api-engineering"
CRAFT = "software-engineering-craft"
TEST = "testing-and-quality-assurance"
FE = "frontend-and-user-experience"
MOB = "mobile-and-desktop-apps"
GROW = "product-growth-and-marketing"
PM = "product-and-project-management"
CUST = "customer-and-revenue-operations"
CONT = "content-and-communication"
PEOPLE = "people-and-engineering-management"
SPEC = "specialized-and-systems-engineering"

R = []  # (regex, l1, l2)
def rule(pat, l1, l2):
    R.append((re.compile(r"\b(?:" + pat + r")\b", re.I), l1, l2))
def head(pat, l1, l2):
    """Anchored at the start of the stem: for generated families whose first word is the topic."""
    R.append((re.compile(r"(?:^|\| )(?:" + pat + r")\b", re.I), l1, l2))

# =============================================================================================
# 1. Security override: a security-specific MODIFIER on a platform or data stem moves the file
#    to security. The reader is the security owner, not the platform owner (P1, P5, P8 agree).
#    This is the only rule where a modifier crosses a level-1 boundary.
# =============================================================================================
rule(r"secrets management|security controls", SEC, "secrets-and-key-management")

# =============================================================================================
# 2. Generated families, anchored on their first word so modifiers cannot move them.
# =============================================================================================
# Cloud providers x {AutomationSafety, CapacityForecasting, CostGovernance, DeploymentRollouts,
# EnvironmentPromotion, FailureRecovery, IncidentTriage, ObservabilityDesign, PolicyAutomation}
CLOUD = r"aws|azure|gcp|kubernetes|docker|terraform|github actions|platform engineering|service mesh|linux operations"
head(rf"(?:{CLOUD}) (?:capacity forecasting|cost governance)", PLAT, "capacity-and-cost-governance")
head(rf"(?:{CLOUD}) (?:deployment rollouts|environment promotion)", PLAT, "ci-cd-and-release-pipelines")
head(rf"(?:terraform|platform engineering|service mesh)", PLAT, "platform-engineering-and-tenancy")
head(r"github actions", PLAT, "ci-cd-and-release-pipelines")
head(rf"(?:{CLOUD})", PLAT, "cloud-and-kubernetes-operations")

# Data stores x {AccessPatterns, ConsistencyRules, CostGuardrails, DataObservability, MigrationCutovers,
# QueryProfiling, ReplicationRecovery, SchemaEvolution} and the pipeline engines in the same block.
head(r"(?:airflow|kafka|spark)", DATA, "pipelines-and-ingestion")
head(r"(?:snowflake|dbt|postgresql|mysql|mongodb|redis|sqlite) (?:schema evolution)", DATA, "schema-and-data-contracts")
head(r"(?:snowflake|dbt|postgresql|mysql|mongodb|redis|sqlite) (?:data observability)", DATA, "data-quality-and-governance")
head(r"(?:snowflake|dbt|postgresql|mysql|mongodb|redis|sqlite)\b", DATA, "databases-and-warehouses")

# Backend frameworks x {AuthenticationFlows, CacheInvalidation, ContractEvolution, ErrorModeling,
# IdempotencyControls, MultiTenantIsolation, ObservabilityContracts, PaginationSystems, Background, Rate}
head(r"(?:django|express|fastapi|nestjs|rails|asp\.net core|spring boot|grpc|graphql|rest api) (?:authentication flows|cache invalidation|contract evolution|error modeling|idempotency controls|multi-tenant isolation|observability contracts|pagination systems|background|rate)", BACK, "backend-framework-patterns")
head(r"(?:asp\.net core|spring boot)$", BACK, "backend-framework-patterns")

# Frontend frameworks x {AccessibilityFlows, BuildPipelines, ComponentTesting, FormSystems, HydrationRecovery,
# RenderingPerformance, RoutingBoundaries, StateArchitecture, Design (System Adoption), Error (Recovery UX)}
FEFW = r"react|vue|angular|svelte|nuxt|next\.js|remix|astro|solidjs|web components"
head(rf"(?:{FEFW}) accessibility flows", FE, "accessibility")
head(rf"(?:{FEFW}) (?:build pipelines|component testing|form systems|hydration recovery|rendering performance|routing boundaries|state architecture|design|error)", FE, "frontend-frameworks-and-performance")

# Languages x {BuildToolchains, ConcurrencyPatterns, DebugWorkflows, ErrorSemantics, InteropBoundaries,
# PackagePublishing, PerformanceProfiling, RefactorMechanics, TypeArchitecture, Test (Harness Design)}
LANG = r"java|python|typescript|javascript|kotlin|swift|rust|go|c#|c\+\+|c sharp|cpp"
head(rf"(?:{LANG}) (?:build toolchains|package publishing|build tools)", CRAFT, "version-control-and-builds")
head(rf"(?:{LANG}) (?:refactor mechanics|clean code|design patterns)", CRAFT, "code-quality-and-refactoring")
head(rf"(?:{LANG}) (?:test)\b", CRAFT, "languages")
head(rf"(?:{LANG}) (?:concurrency|debug workflows|error semantics|interop boundaries|performance profiling|type architecture|collections|generics|streams|records|reflection|memory|exception handling|logging|performance tuning|advanced|config mastery)", CRAFT, "languages")

# Systems "lab" families x {APIDesign, ArchitecturePatterns, DebuggingTactics, FailureAnalysis, MemorySafety,
# OptimizationPlaybooks, PerformanceModels, StateMachines, TestStrategies, ToolingWorkflows}
head(r"algorithms?", CRAFT, "algorithms-and-fundamentals")
head(r"(?:compiler|operating systems|networking)", SPEC, "compilers-os-and-networking")
head(r"(?:embedded|robotics)", SPEC, "embedded-iot-and-robotics")
head(r"(?:game|graphics)", SPEC, "graphics-games-and-media-engineering")
head(r"distributed systems", BACK, "service-architecture-and-decomposition")
head(r"bioinformatics", SPEC, "scientific-and-emerging-computing")
head(r"computer vision", AI, "machine-learning-and-vision")

# Product-management family x {DecisionMemos, FeedbackTaxonomy, MetricTrees, OperatingCadence,
# PostLaunchAnalysis, PrioritizationModels, ProblemFraming, RiskReviews, RolloutPlanning, StakeholderAlignment}
head(r"experimentation", GROW, "experimentation")
head(r"pricing", GROW, "pricing-and-packaging")
head(r"roadmapping", PM, "roadmaps-and-prioritization")
head(r"onboarding documentation", PEOPLE, "employee-onboarding-and-training")
head(r"onboarding (?:post-launch|stakeholder|decision|feedback|metric|operating|prioritization|problem|risk|rollout)", GROW, "onboarding-activation-and-retention")
head(r"customer research", GROW, "market-and-customer-insight")
head(r"platform product", PM, "strategy-and-business-planning")

# AI-product family x {CostControl, DataContracts, EvaluationRubrics, ExperimentTracking, FailureAnalysis,
# LatencyBudgets, ProductionRollouts, SafetyDesign, ToolReliability, Human (Review Loops)}
head(r"agents?", AI, "agents-and-tool-use")
head(r"embeddings", AI, "retrieval-search-and-embeddings")
head(r"rag", AI, "retrieval-search-and-embeddings")
head(r"prompting", AI, "prompting-and-context")
head(r"guardrails", AI, "safety-and-guardrails")
head(r"tool use", AI, "agents-and-tool-use")
head(r"fine tuning|fine-tuning", AI, "model-serving-and-cost")
head(r"synthetic data", AI, "evaluation-and-labeling")
head(r"model routing", AI, "model-serving-and-cost")

# =============================================================================================
# 3. Topic rules, most specific first. Comments name the group's business problem.
# =============================================================================================

# --- security-and-trust: keeping systems, data, and users safe from attackers and abuse -------
rule(r"brand identity", FE, "design-systems-and-visual-design")
rule(r"identity graph|identity resolution", DATA, "data-quality-and-governance")
rule(r"secrets?\b|key management|key rotation|credential rotation|data encryption", SEC, "secrets-and-key-management")
rule(r"abuse|fraud|bot mitigation", SEC, "abuse-and-fraud-defense")
rule(r"access review|access control|permission boundary|permission drift|permission lifecycle|identity|oauth|jwt|sso|auth flow|auth recovery|authentication|auth security|session management|session hijack|device trust|zero trust|zero-trust|trust boundary", SEC, "identity-and-access")
rule(r"compliance|gdpr|data privacy|audit trail|secure audit|vendor risk|legal contract", SEC, "compliance-privacy-and-audit")
rule(r"application security|api security|container security|supply chain|tls|threat|vulnerability|penetration|security audit|security engineering|secure defaults|secure file upload|xss|csrf|ssrf|sql injection|command injection|buffer overflow|brute force|ddos|dns spoofing|mitm|man-in-the-middle|phishing|ransomware|social engineering|privilege escalation|zero-day|zero day|prompt injection defense|electron security|java security|memory forensics|reverse engineering|webhook security", SEC, "attack-defense-and-hardening")

# --- testing-and-quality-assurance: proving software works before and after it ships ----------
rule(r"a/b testing|experiment guardrail", GROW, "experimentation")
rule(r"flaky|flake|test determinism|test data factories", TEST, "flaky-tests-and-determinism")
rule(r"browser test|browser state|end-to-end|e2e|visual diff|session replay|extension behavior|auth popup|form interaction recovery|form autofill|multi-tab coordination|cross browser support|exploratory qa|load testing|accessibility testing|clipboard workflow|download flow automation|failure injection lab", TEST, "browser-and-end-to-end-testing")
rule(r"bug reproduction|repository audit|triage issue", TEST, "bug-reproduction-and-triage")
rule(r"design qa", FE, "design-systems-and-visual-design")
rule(r"contract testing|integration testing|property testing|snapshot testing|unit testing|component testing|testing strategy|tdd|test-driven|test driven|database testing|test harness|junit", TEST, "test-strategy-and-harnesses")

# --- mobile-and-desktop-apps: shipping and running software on end-user devices ---------------
rule(r"ios release|android lifecycle|app store|store listing|mobile release|install attribution|install funnels|permission prompt|crash forensics", MOB, "release-and-app-store-delivery")
rule(r"offline sync|offline conflict|offline-first|mobile network|battery|device capability|cross-device|cross device|background execution|sync engines", MOB, "device-connectivity-and-offline")
rule(r"push notifications?|push messaging|push reliability|deep link|in-app messaging|in-app upsell", MOB, "notifications-and-deep-links")
rule(r"desktop|electron|tauri", MOB, "native-and-desktop-development")
rule(r"swiftui|android development|mobile cross platform|mobile app design|react native", MOB, "native-and-desktop-development")

# --- ai-and-agent-systems: building, evaluating, and operating LLM and ML systems -------------
rule(r"claude|gpt-4o|gpt4o|gemini|gemma|grok|groq|mistral|deepseek|qwen|kimi|llama|command r|phi-4|phi4|perplexity|ollama|openai", AI, "model-provider-guides")
rule(r"guardrail|safety escalation|safety guardrails|prompt attack|prompt safety|ai hallucination|responsible ai|llm guardrail", AI, "safety-and-guardrails")
rule(r"eval\w*|human review queues?|synthetic judge|model quality|model drift|human label|review queue design|annotation guideline|dataset label|synthetic dataset|prompt dataset|embedding drift|ai model", AI, "evaluation-and-labeling")
rule(r"agent|multi-agent|tool calling|tool policies|tool schema|tool selection|tool failure|prompt chaining", AI, "agents-and-tool-use")
rule(r"prompt|context window|context compression|ai chat context|structured output|ai response", AI, "prompting-and-context")
rule(r"retrieval|vector databases?|search architectures|search implementation|search index recovery|ranking system|recommender", AI, "retrieval-search-and-embeddings")
rule(r"model fallback|llm|cost latency governance|ml ?ops|edge inference|gpu workload|production ai|multi-provider ai|ai integration|multimodal ai", AI, "model-serving-and-cost")
rule(r"machine learning|nlp|feature store|forecast backtesting|neuro-symbolic|ai agent architecture", AI, "machine-learning-and-vision")

# --- data-platform-and-analytics: moving, modeling, and trusting data ------------------------
rule(r"ci/cd|cicd|ci cd|devops", PLAT, "ci-cd-and-release-pipelines")
rule(r"etl|csv ingestion|batch import|cron pipeline|cdc recovery|backfill|stream processing|file processing pipelines|batch freshness|data pipeline|pipeline design", DATA, "pipelines-and-ingestion")
rule(r"data quality|data catalog|data product|data retention|data observability|entity resolution", DATA, "data-quality-and-governance")
rule(r"metric governance|metric lineage|metric review|metrics definition|metric definition|semantic layer|semantic contracts|analytical sla|cohort analysis|sql analytics|dashboard operations|analytics instrumentation|forecast modeling|data visualization|attribution analysis|funnel attribution|data warehouse", DATA, "metrics-and-analytics")
rule(r"event schema|message schema|schema registry|schema evolution|schema cutover|data schema|data contract|event taxonomy|event version|slowly changing|temporal data|data model design|domain modeling|contract evolution|fact modeling", DATA, "schema-and-data-contracts")
rule(r"database|warehouse|lakehouse|query plan|query repair|sql window|time series|time-series|replication lag|graph databases|prisma|index lifecycle|geospatial|spatial queries|cost guardrails|debug — postgresql|debug — redis", DATA, "databases-and-warehouses")

# --- platform-and-cloud-infrastructure: running the infrastructure and shipping changes to it --
rule(r"linux|windows (?:event|filesystem|registry)|macos|shell profiles|dotfiles|package managers|environment variables|process management|disk & storage|temp files|user directories|dangerous os paths|autostart|network configuration files|bash scripting", PLAT, "systems-administration-reference")
rule(r"capacity forecasting|cost governance|cloud cost|gpu capacity|gpu orchestration|runtime capacity", PLAT, "capacity-and-cost-governance")
rule(r"deployment rollouts|environment promotion|config promotion|deployment safeguards|client-side feature|rollback readiness|release readiness|release channel|release train|blue green|canary|continuous deployment|cloud deployment|feature flags?|rollout coordination|upgrade wave|infrastructure changes|infrastructure drift", PLAT, "ci-cd-and-release-pipelines")
rule(r"platform paved|platform standards|platform adoption|multi-tenant platforms|cluster tenancy|tenant provisioning|tenant isolation|internal api gateway|infrastructure as code|configuration management|nginx|cloud architecture|edge computing|multi-region architecture|multi region traffic|traffic shaping|serverless", PLAT, "platform-engineering-and-tenancy")
rule(r"container orchestration|dockerfile|debug — docker", PLAT, "cloud-and-kubernetes-operations")

# --- reliability-and-incident-response: keeping a live service healthy and recovering fast ----
rule(r"api incident triage", BACK, "api-design-and-lifecycle")
rule(r"supply chain incident", SEC, "attack-defense-and-hardening")
rule(r"incident|postmortem|post-mortem|on-call|crisis management|crash signal|change failure|error budget|slo|reliability review", REL, "incident-response-and-postmortems")
rule(r"backup|disaster recovery|regional failover", REL, "backup-and-disaster-recovery")
rule(r"account health monitoring", CUST, "customer-success-and-retention")
rule(r"frontend observability|client observability|frontend telemetry", FE, "frontend-frameworks-and-performance")
rule(r"observability|logging instrumentation|structured logging|distributed tracing|multi-service tracing|opentelemetry|monitoring|application performance", REL, "observability-and-slos")
rule(r"memory leak|performance triage|service timeout|debugging production|concurrency bug|memory management|network path analysis|performance optimization", REL, "production-diagnostics-and-triage")
rule(r"chaos|failure domain|queue backpressure|queue latency|background job recovery|error handling|error resiliency", REL, "resilience-and-failure-isolation")

# --- frontend-and-user-experience: building interfaces people can see, use, and trust --------
rule(r"accessibility|aria|a11y", FE, "accessibility")
rule(r"design systems?|design tokens?|color|typography|motion|animation|icon design|layout and composition|visual hierarchy|graphic design|illustration|photography|creative direction|creative thinking|component composition|component apis|component library|ui design|design critique|design review|design to code|figma|design an interface", FE, "design-systems-and-visual-design")
rule(r"ux|user experience|interaction design|interaction copy|interaction states|information architecture|empty state|microcopy|form validation|navigation flow|journey mapping|customer journey|onboarding experience|dashboard experience|service blueprint|user interview|mobile experience design|design documentation", FE, "ux-research-and-interaction-design")
rule(r"css|frontend|web performance|web vitals|bundle budget|code splitting|rendering|hydration|client state|state management|browser storage|pwa|micro-frontend|internationalization|webgl|progressive enhancement|interaction latency|asset delivery|asset pipeline|browser extension|webassembly|vue\.js|react|web components", FE, "frontend-frameworks-and-performance")

# --- product-and-project-management: deciding what to build and coordinating delivery --------
rule(r"launch", PM, "launch-coordination")
rule(r"roadmap|prioritization scoring|technical roadmapping|product roadmapping|assumption mapping", PM, "roadmaps-and-prioritization")
rule(r"product strategy|startup strategy|fundraising|pitch deck|financial modeling|scenario planning|okr|tech stack selection|competitive analysis", PM, "strategy-and-business-planning")
rule(r"decision memo|decision log|rfc|adr|architecture decision|prd|product requirements|requirements discovery|jobs to be done|ubiquitous language", PM, "decisions-rfcs-and-memos")
rule(r"weekly planning|work intake|cross-team dependency|delegation|async status|agile|project planning|change management|meeting facilitation|stakeholder|change risk|task queue prioritization|inbox triage|follow-up reminder", PM, "planning-cadence-and-delivery")

# --- product-growth-and-marketing: acquiring, converting, and retaining customers -------------
rule(r"experiment\w*", GROW, "experimentation")
rule(r"pricing|packaging value", GROW, "pricing-and-packaging")
rule(r"onboarding program|internal training|developer onboarding", PEOPLE, "employee-onboarding-and-training")
rule(r"onboarding|activation|adoption barrier|retention programs|churn|winback|trial conversion|customer adoption|feature education", GROW, "onboarding-activation-and-retention")
rule(r"signup funnel|landing page|campaign|email lifecycle|email marketing|retargeting|referral|webinar funnels|webinar lifecycle|growth loops?|seo|conversion rate|audience segmentation|audience intent|brand messaging|creator programs|creator brief", GROW, "acquisition-funnels-and-campaigns")
rule(r"hashtag|instagram|linkedin|twitter|viral|trend hijacking|engagement optimization|personal brand voice|content calendar|visual content|community building & reply|cross-platform distribution|social media|hook writing|short-form video", GROW, "social-media-marketing")
rule(r"customer segment|competitor|market signal|voice of customer|persona", GROW, "market-and-customer-insight")

# --- customer-and-revenue-operations: the ongoing relationship with customers and buyers -----
rule(r"rate limit negotiation", BACK, "integrations-and-webhooks")
rule(r"sales|lead qualification|proposal assembly|partner|negotiation|demo preparation", CUST, "sales-and-partner-operations")
rule(r"support|faq deflection|customer escalation|playbook localization", CUST, "support-operations")
rule(r"account health|success playbook|renewal risk|customer success", CUST, "customer-success-and-retention")
rule(r"customer feedback|feedback triage|feedback taxonomy", CUST, "feedback-and-voice-of-customer")
rule(r"billing workflow|payment", BACK, "payments-and-billing")

# --- content-and-communication: producing material for a human audience ----------------------
rule(r"stream quality|stream encoding|video transcode|video streaming|webrtc", SPEC, "graphics-games-and-media-engineering")
rule(r"video|podcast|webinar|voiceover|storyboard|screen recording|thumbnail|slide deck|demo|asset review boards|course lesson", CONT, "video-and-media-production")
rule(r"api reference|api recipe|api documentation|tutorials?|troubleshooting guide|developer portal|changelog|release notes|change announcement|runbook authoring|on-call cheat|code documentation|technical writing|technical blog|technical diagramming|edit article", CONT, "technical-documentation")
rule(r"internal wiki|knowledge base|knowledge capture|meeting synthesis|research briefing|research synthesis|literature review|research & summarize", CONT, "internal-knowledge-and-research")
rule(r"case study development|email template|creative writing|copywriting|content strategy|content repurposing|newsletter|editorial|narrative testing", CONT, "editorial-and-copywriting")
rule(r"community", CONT, "community-and-creator-programs")

# --- people-and-engineering-management: running the human side of an engineering org ---------
rule(r"candidate pipeline|interview\w*|job description|reference check|offer review|hiring|case study", PEOPLE, "hiring-and-interviewing")
rule(r"performance feedback|skill matrix|team health", PEOPLE, "performance-and-team-health")
rule(r"engineering leadership|technical mentoring|soft skills|executive communication|engineering metrics", PEOPLE, "leadership-and-career-growth")
rule(r"resume|personal branding|grill me|career", PEOPLE, "leadership-and-career-growth")

# --- backend-and-api-engineering: designing services and APIs other systems consume ----------
rule(r"webhooks?|callback delivery|event bridge|notification pipeline|partner sandbox|third-party api|sdk compatibility|api change watch|rate limit negotiation|transactional email|file transfer", BACK, "integrations-and-webhooks")
rule(r"api|rest|graphql|grpc|rate limiting|idempotency|pagination|versioning|backward compatibility|interface versioning|sdk", BACK, "api-design-and-lifecycle")
rule(r"django|express|fastapi|nestjs|rails|asp\.net|spring|node\.?js|python async|java microservices|java jpa|java jdbc|background jobs|zod", BACK, "backend-framework-patterns")
rule(r"message queues|distributed queue|event-driven|event driven|event sourcing|websockets|streaming & server-sent|realtime|async|asynchronous communication|cron job|workflow automation", BACK, "messaging-queues-and-realtime")
rule(r"service|microservices|monoliths?|domain driven|domain-driven|domain event|system design|system architecture|backend architecture|architecture fitness|architectural patterns|caching|cache|consensus|multi-tenancy|legacy boundary|legacy system|codebase ownership|file storage|file & media|backend api", BACK, "service-architecture-and-decomposition")

# --- specialized-and-systems-engineering: domain engineering outside the web/cloud stack ------
rule(r"embedded|robotics|iot|mqtt|edge device|edge telemetry|fpga", SPEC, "embedded-iot-and-robotics")
rule(r"alu|bus and interconnect|control unit|isa design|register file|branch prediction|out-of-order|hazard detection|memory hierarchy|interrupt|gpu programming", SPEC, "hardware-and-computer-architecture")
rule(r"compiler|operating systems|network programming", SPEC, "compilers-os-and-networking")
rule(r"digital signal|dsp", SPEC, "graphics-games-and-media-engineering")
rule(r"computational geometry|quantum|blockchain|web3|zero-knowledge|formal verification", SPEC, "scientific-and-emerging-computing")

# --- software-engineering-craft: writing, reviewing, and maintaining code itself --------------
rule(r"code review|pull request|clean code|design patterns|static analysis|refactor|technical debt|code migration|improve codebase|migrate to shoehorn|business logic validation|dependency injection", CRAFT, "code-quality-and-refactoring")
rule(r"git|monorepo|dependency|merge conflict|release branch|conventional commits|trunk-based|package publishing|packaging|build|patch backporting|pre-commit|package scripts|npm", CRAFT, "version-control-and-builds")
rule(r"algorithm|functional programming|regex|data structures", CRAFT, "algorithms-and-fundamentals")
rule(r"cli|command line|developer experience|feature scaffolding|code search|write a skill|hook writing|open ?source|web scraping", CRAFT, "developer-tooling-and-experience")
rule(r"java|python|typescript|javascript|kotlin|swift|rust|go|c#|c\+\+|zig|odin|haxe|nim|crystal|gleam|janet|racket|raku|fennel|lobster|elvish|wren|vlang", CRAFT, "languages")

# Singletons whose name alone is ambiguous. Filename -> (l1, l2).
FILE_OVERRIDES = {
    "Red.md": (CRAFT, "languages"),
    "Io.md": (CRAFT, "languages"),
    "Hy.md": (CRAFT, "languages"),
    "Incident.md": (REL, "incident-response-and-postmortems"),
    "Service.md": (BACK, "service-architecture-and-decomposition"),
    "Motion.md": (FE, "design-systems-and-visual-design"),
    "Partner.md": (CUST, "sales-and-partner-operations"),
    "Stakeholder.md": (PM, "planning-cadence-and-delivery"),
    "UXHeuristicEvaluation.md": (FE, "ux-research-and-interaction-design"),
    "TechnicalInterviewPreparation.md": (PEOPLE, "leadership-and-career-growth"),
    "SystemDesignInterview.md": (PEOPLE, "leadership-and-career-growth"),
    "Copywriting.md": (CONT, "editorial-and-copywriting"),
    "CaseStudyDevelopment.md": (CONT, "editorial-and-copywriting"),
    "GitGuardrails.md": (CRAFT, "version-control-and-builds"),
    "ReactPerformance.md": (FE, "frontend-frameworks-and-performance"),
    "analytics-performance-optimization.md": (GROW, "social-media-marketing"),
    "APIErrorHandling.md": (BACK, "api-design-and-lifecycle"),
    "DebugFastAPIDjango.md": (BACK, "backend-framework-patterns"),
    "PythonAsyncFastAPI.md": (BACK, "backend-framework-patterns"),
    "MessageQueues.md": (BACK, "messaging-queues-and-realtime"),
    "PersonaSystemDesign.md": (AI, "prompting-and-context"),
    "JavaTestingJUnitMockito.md": (CRAFT, "languages"),  # B4: the Java pack stays whole
    "Refactoring.md": (CRAFT, "code-quality-and-refactoring"),
    "Docker.md": (PLAT, "cloud-and-kubernetes-operations"),
    "Kubernetes.md": (PLAT, "cloud-and-kubernetes-operations"),
    "Terraform.md": (PLAT, "platform-engineering-and-tenancy"),
    "GitHub.md": (CRAFT, "version-control-and-builds"),
    "GitLab.md": (CRAFT, "version-control-and-builds"),
    "React.md": (FE, "frontend-frameworks-and-performance"),
    "GraphQL.md": (BACK, "api-design-and-lifecycle"),
    "SpringBoot.md": (BACK, "backend-framework-patterns"),
    "SpringBootJava.md": (BACK, "backend-framework-patterns"),
}

MODS_E = re.compile(r"^Expert-level guidance for")
MODS_P = re.compile(r"^Practical guidance for")

def split_camel(f):
    s = f[:-3] if f.endswith(".md") else f
    s = re.sub(r"[-_&.]+", " ", s)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)
    return s

def stem(r):
    """Topic stem: name minus the template modifier. Singletons keep the whole name plus the
    camel-split filename, because some names have no spaces ('GameDevelopment')."""
    w = r["name"].split()
    if MODS_E.match(r["desc"]) and len(w) >= 4:
        return " ".join(w[:-2])
    if MODS_P.match(r["desc"]) and len(w) >= 2:
        return " ".join(w[:-1])
    return split_camel(r["file"]) + " | " + r["name"]

def classify(r):
    if r["file"] in FILE_OVERRIDES:
        return FILE_OVERRIDES[r["file"]]
    text = stem(r)
    for rx, l1, l2 in R:
        if rx.search(text):
            return l1, l2
    return None

def main():
    rows = [json.loads(l) for l in open(os.path.join(HERE, "skills.jsonl"))]
    out, missed = [], []
    for r in rows:
        c = classify(r)
        if c is None:
            missed.append(r)
        else:
            out.append((r["file"], c[0], c[1]))
    with open(os.path.join(HERE, "assignment.tsv"), "w") as f:
        for row in out:
            f.write("\t".join(row) + "\n")
    print(f"assigned {len(out)} / {len(rows)}; unmatched {len(missed)}")
    for k, v in collections.Counter(l1 for _, l1, _ in out).most_common():
        print(f"{v:5d}  {k}")
    if "--l2" in sys.argv:
        for k, v in sorted(collections.Counter((l1, l2) for _, l1, l2 in out).items()):
            print(f"{v:5d}  {k[0]}/{k[1]}")
    if "--stems" in sys.argv:
        assigned = {f: (l1, l2) for f, l1, l2 in out}
        fam = collections.defaultdict(collections.Counter)
        for r in rows:
            if r["file"] in assigned:
                fam[stem(r).split(" | ")[0]][assigned[r["file"]]] += 1
        for st in sorted(fam, key=lambda k: (sorted(fam[k])[0], k)):
            for (l1, l2), n in fam[st].items():
                print(f"{l1}/{l2}\t{n}\t{st}")
    if missed:
        print("UNMATCHED:")
        for r in missed:
            print("  ", r["file"], "|", r["name"])

if __name__ == "__main__":
    main()
