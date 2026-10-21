# Azure Landing Zone Factory — Wiki

This repository is a **Landing Zone Factory**: it produces a per-customer Azure
landing-zone repository from a configuration you build in a wizard. The wiki has
exactly two sections:

1. **[How to Get Started](#how-to-get-started)** — the operator guidebook.
   Follow it top to bottom to run one customer engagement end to end.
2. **[Source Material](#source-material)** — every other document: factory
   design records, stage readiness evidence, build docs, and historical
   planning material.

---

## How to Get Started

Written for a single L1 operator who holds the client's credentials. No other
people are required. Read the four pages in order:

| Order | Page | What it covers |
| --- | --- | --- |
| 1 | **[Getting-Started](Getting-Started)** | What the factory is, the per-customer motion (copy → initiate → wizard → generate → deploy → dispose), and the accounts and tools you need before you begin. |
| 2 | **[Credentials-Checklist](Credentials-Checklist)** | Every account, credential, API, secret, and permission — each with a placeholder value, where to get it, and what it is for. |
| 3 | **[Bootstrap-Walkthrough](Bootstrap-Walkthrough)** | Fork and clone, install and authenticate the CLIs, run the bootstrap (what it prompts for and what it creates: service principals, OIDC federated credentials, GitHub secrets and environments), verify OIDC, then run the configuration wizard and place its outputs. |
| 4 | **[Generate-and-Deploy](Generate-and-Deploy)** | Discovery, the bootstrap broker, rendering the customer repository, scaffolding it to GitHub, the first deployment (plan → merge → apply per layer), and disposing of the clone afterwards. |

Two companion documents live in the repository because tests and tools read
them from disk (the wiki carries mirrors):

- [`USER-CHECKLIST.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/docs/USER-CHECKLIST.md)
  — the authoritative Stage 9–14 operator checklist (mirror:
  [User-Checklist](User-Checklist)).
- [`TODO.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/TODO.md)
  — the production-readiness backlog: known blockers and hardening items,
  phase by phase.

> **Status honesty (updated 2026-08-27)**: the factory is at **v0.11.0**. The
> five release gates in `factory-version.json` are **not** all met, so treat a
> first deployment as a verification exercise, not a production cutover. The
> end-to-end generation proof has passed on GitHub-hosted runners for both
> topologies; `oidcTokenExchangeVerifiedLive` still lacks evidence until a
> first real instantiation runs. The current blocker list is in
> [`REVIEW.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/REVIEW.md)
> (six open entries) and [`TODO.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/TODO.md).

---

## Source Material

> ## ⚠ This wiki predates the generator-only refactor
>
> The wiki was last restructured **2026-08-01**. On **2026-08-15** the
> repository was refactored to be a **generator only**
> ([ADR 0013](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/docs/decisions/0013-generator-only-avm-architecture.md)):
> the bespoke `terraform/live/` and `terraform/modules/` trees, the numbered
> workflows (`010-terraform-init.yml`, `020-rbac-validation.yml`), and the
> self-deploying Stage 13 dogfood were **all deleted**. The factory now emits
> three AVM-referencing layers into a generated repository and deploys nothing
> itself.
>
> **Consequence for every page below**: any page naming `terraform/live/*`,
> `terraform/modules/*`, the numbered workflows, or the dogfood is describing
> a structure that no longer exists. Read it as history, not instruction.
>
> The authoritative current sources live in the repository, not here:
> [`README.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/README.md),
> [`TODO.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/TODO.md),
> [`REVIEW.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/REVIEW.md),
> [`docs/decisions/`](https://github.com/HybridCloudWorks/Template-LZDeployment/tree/main/docs/decisions),
> and [`docs/runbooks/go-live-opening.md`](https://github.com/HybridCloudWorks/Template-LZDeployment/blob/main/docs/runbooks/go-live-opening.md).

Everything below predates or supports the guidebook. Pages marked
**historical** describe the repository's earlier life as a self-deploying
landing zone (before the factory conversion) and are kept for reference — do
not follow them as instructions.

### Factory design and stage readiness (current)

- **[Factory-Design](Factory-Design)** — factory architecture and the 41-entry
  risk register (risk IDs like AR3/BR2/GH1 cited in code comments are defined
  here).
- **[Factory-Stage-7-Readiness](Factory-Stage-7-Readiness)** — workflow corpus.
- **[Factory-Stage-8-Readiness](Factory-Stage-8-Readiness)** — generated documentation corpus.
- **[Factory-Stage-9-Readiness](Factory-Stage-9-Readiness)** — bootstrap broker.
- **[Factory-Stage-10-Readiness](Factory-Stage-10-Readiness)** — scaffold builder.
- **[Factory-Stage-11-Readiness](Factory-Stage-11-Readiness)** — brownfield import generation.
- **[Factory-Stage-12-Readiness](Factory-Stage-12-Readiness)** — Factory CI.
- **[Factory-Stage-13-Readiness](Factory-Stage-13-Readiness)** — HCW dogfood instance.
- **[Factory-Stage-14-Readiness](Factory-Stage-14-Readiness)** — release evidence attestation.

### Operations mirrors (repo copies are canonical)

- **[User-Checklist](User-Checklist)** — operator authentication, publication,
  and verification activities (canonical: repo root `USER-CHECKLIST.md`; read
  by the factory test suites).
- **[Cross-Domain-Contracts](Cross-Domain-Contracts)** — load-bearing
  cross-file contracts (canonical: repo `.claude/CROSS-DOMAIN-CONTRACTS.md`).

### Build documentation (historical — June 2026 plan superseded by the factory conversion before execution; reviewed 2026-08-06)

- **[Build-README](Build-README)** — index of the build documentation set.
- **[Build-Critical-Path](Build-Critical-Path)** — build critical path and timeline.
- **[Build-Standards-Reference](Build-Standards-Reference)** — build standards reference.
- **[Build-Verification-Report](Build-Verification-Report)** — verification report and next steps.
- **[Deployment-Flow](Deployment-Flow)** — deployment flow architecture.

### Webapp / static config generator (historical — describes `frontend/`, the legacy generator, and the `site/` wizard's ancestry; reviewed 2026-08-06)

- **[Webapp-Plan](Webapp-Plan)** — static configuration generator build plan.
- **[Quick-Start](Quick-Start)** — quick start for the static `.tfvars` generator.
- **[Static-Generator-Design](Static-Generator-Design)** — generator design.
- **[Static-Generator-Implementation](Static-Generator-Implementation)** — implementation guide.
- **[Testing-Static-Generator](Testing-Static-Generator)** — testing guide.
- **[Form-Migration-Guide](Form-Migration-Guide)** — current → official ALZ form migration.
- **[Phase-1-Prep-Stage-Inventory](Phase-1-Prep-Stage-Inventory)** — ALZ configuration inventory (generator research).
- **[Phase-2-Build-Plan](Phase-2-Build-Plan)** — static generator rebuild plan.
- **[Expanded-Scope](Expanded-Scope)** — full configuration generator scope.
- **[Fix-Login-Error](Fix-Login-Error)** — login error fix note.

### Architecture and standards (historical — self-deploy era; concepts still inform the factory templates)

- **[Architecture](Architecture)** — hub-spoke topology, security layers, scaling.
- **[Subscriptions-Layout](Subscriptions-Layout)** — 6-subscription design, management groups, RBAC matrix.
- **[Naming-Convention](Naming-Convention)** — resource naming patterns (80+ types).
- **[Tagging-Strategy](Tagging-Strategy)** — mandatory and optional tags, cost allocation.
- **[RBAC-Access-Control](RBAC-Access-Control)** — Entra groups and least-privilege roles.
- **[Service-Principals](Service-Principals)** — OIDC federation and the three-tier SP design.
- **[Requirements](Requirements)** — RBAC and system requirements.
- **[OIDC-Best-Practices](OIDC-Best-Practices)** — zero-password authentication patterns.
- **[GitHub-Integration](GitHub-Integration)** — OIDC federation, secrets, environments.
- **[GitHub-Security](GitHub-Security)** — GitHub hardening guidance.
- **[AVM-Compliance](AVM-Compliance)** — Azure Verified Modules compliance guide.

### Planning and phase records (historical — the pre-factory 4-phase deployment plan)

- **[Phase-Roadmap](Phase-Roadmap)** — the original 4-phase deployment model.
- **[Planning-Architecture](Planning-Architecture)** — unified roadmap, strategy, and architecture decisions.
- **[Implementation-Tasks](Implementation-Tasks)** — implementation task breakdown.
- **[Phase-0-Completion](Phase-0-Completion)** — Phase 0 sign-off checklist.
- **[Phase-1-Prerequisites](Phase-1-Prerequisites)** — Phase 1 day-by-day execution guide.
- **[Phase-2-Bootstrap](Phase-2-Bootstrap)** — Phase 2 bootstrap timeline.
- **[Phases-0-2-Summary](Phases-0-2-Summary)** — progress overview.
- **[Pre-Deployment-Checklist](Pre-Deployment-Checklist)** — pre-deployment validation (superseded by [User-Checklist](User-Checklist)).
- **[Deployment-Guide](Deployment-Guide)** — Terraform workflow and rollback procedures (self-deploy era).
- **[Customer-Setup-Guide](Customer-Setup-Guide)** — earlier customer setup guide (superseded by the How to Get Started section).
- **[Quick-Reference](Quick-Reference)** — quick reference card (self-deploy era).

### Day-2 operations (reference — written for the self-deploy era; adapt per generated repo)

- **[Daily-Operations](Daily-Operations)** — operational checklists.
- **[Incident-Triage](Incident-Triage)** — incident response playbook.
- **[Change-Management](Change-Management)** — change approval and deployment process.
- **[On-Call-Escalation](On-Call-Escalation)** — escalation matrix.
- **[Sandbox-Lifecycle](Sandbox-Lifecycle)** — sandbox cleanup and resource management.

### Session archives (historical)

- **[Session-History](Session-History)** — session history and project summary.
- **[Session-Progress](Session-Progress)** — detailed progress tracking.

---

## Key resources

- **Repository:** [HCW-Plan_LZDeployment](https://github.com/HybridCloudWorks/Template-LZDeployment)
- **Microsoft CAF:** [Cloud Adoption Framework — Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- **Azure Verified Modules:** [AVM Terraform requirements](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/)

**Last Updated:** 2026-08-06 (build and generator source material content-reviewed against the repository and bannered)
