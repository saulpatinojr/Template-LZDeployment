# Generate and Deploy

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

Step 4 of 4 in **How to Get Started**.
← [Bootstrap-Walkthrough](03-bootstrap-walkthrough.md)

You now have a bootstrapped clone and
`generated-output/<customer>/lz-config.json`. This page: check tenant
readiness, reconcile prerequisites with the broker, render and scaffold the
customer's repository, deploy the landing zone from it, then dispose of the
clone. Each mutating tool here is **plan-first**: run it once to see exactly
what it would do, review the plan file it writes, then run it again with
`-Apply`.

Throughout, the per-stage authoritative checklist is the repository's
[`USER-CHECKLIST.md`](../USER-CHECKLIST.md)
— this page is the narrative version of it.

## 1. Discovery (read-only readiness check)

```powershell
pwsh ./factory/discovery/Invoke-Discovery.ps1 -ConfigPath ./generated-output/<customer>/lz-config.json
```

Creates, next to the config: `tenant-readiness-report.md` (human gate — fix
every **Fail** before continuing; **Warning** entries include remediation
guidance) and `discovery-inventory.json` (machine-readable, consumed by the
broker). Nothing is created or changed in Azure — safe against a production
tenant.

## 2. Bootstrap broker (prerequisites for the generated repo)

The broker reconciles Entra identities, RBAC, GitHub repository/environments/
branch protection, and the state backend for the **customer repository** the
factory is about to create. It never prompts; it reads the config, the
discovery inventory, and environment variables.

```powershell
$env:LZ_CONFIG_PATH    = './generated-output/<customer>/lz-config.json'
$env:LZ_DISCOVERY_PATH = './generated-output/<customer>/discovery-inventory.json'
$env:LZ_BOOTSTRAP_OUTPUT = './bootstrap-output'          # protected evidence directory

pwsh ./bootstrap-broker.ps1            # PLAN ONLY — writes bootstrap-plan.json
```

Review `bootstrap-plan.json` before applying. Per USER-CHECKLIST: every plan
identity is Reader-only; apply identities are Contributor-only at their
declared subscription scopes; OIDC subjects are exactly `pull_request` or
`environment:<name>` with no wildcards; backend names, HCP organization/
workspace prefix, environments, and branch-protection settings match the
engagement.

```powershell
pwsh ./bootstrap-broker.ps1 -Apply
```

On Linux or macOS, with Bash, set the variable and run the shell version instead:

```bash
LZ_BOOTSTRAP_APPLY=true ./bootstrap-broker.sh
```

Preserve `bootstrap-plan.json` and `bootstrap-audit.json`, read back what was
created (the audit lists it), and resolve every `pendingUserActivities` entry.

> Branch protection default: the broker requires the status check
> `qlty check` unless you set `LZ_REQUIRED_STATUS_CHECKS` (comma-separated).
> A fresh customer repository has no qlty integration, so set this to checks
> the generated repo actually runs, or install the integration — otherwise
> merges wait on a check that never reports (tracked in `PROD-TODO.md`).

## 3. Render the customer repository

```powershell
Import-Module ./factory/renderer/LZFactory.Renderer.psd1
Invoke-LzRender -ConfigPath ./generated-output/<customer>/lz-config.json `
                -OutputDirectory ./generated-output/<customer>/repo
```

Renders the whole repository — Terraform, workflows, docs, and a per-customer
`USER-CHECKLIST.md` — into a staging folder, never into a git tree. It
re-validates the config independently of the wizard (22 fail-closed guards)
and writes `render-manifest.json`, the exact inventory the scaffold step will
verify. Modules that are scaffold-only (`keyvault-cmk`, `sentinel-siem`) are
refused rather than silently emitted empty.

Brownfield engagements (`deploymentStrategy.mode = brownfield`): run
`brownfield-import.ps1` between render and scaffold — plan-only by default; it
classifies discovered resources (Adopt / Ignore / Replace / Require-Approval)
and generates import artifacts for review. It never executes
`terraform import`; you run the reviewed commands yourself. See the Stage 11
sections of USER-CHECKLIST.

## 4. Scaffold — publish the generated repository

```powershell
$env:LZ_RENDERED_PATH     = './generated-output/<customer>/repo'
$env:LZ_SCAFFOLD_TARGET   = 'C:/work/<customer>-scaffold'   # separate, disposable working tree
$env:LZ_SCAFFOLD_EVIDENCE = './scaffold-evidence'

pwsh ./scaffold-copy.ps1               # PLAN ONLY — writes scaffold-plan.json
```

Review `scaffold-plan.json`: repository slug and visibility (private), branch,
manifest SHA-256, the exact file inventory, and the remote URL. Then:

```powershell
pwsh ./scaffold-copy.ps1 -Apply
```

This creates the private repository (set `LZ_SCAFFOLD_CREATE_REPOSITORY=false`
if it must already exist), commits the rendered tree, and pushes. For an
existing repository it pushes a branch and opens a **draft PR** instead —
which is also the supported upgrade path when you regenerate later. Preserve
`scaffold-plan.json`, `scaffold-audit.json`, and any `*.lz-backup-*`
directories until the repository is accepted, and read back the remote against
the audit's file/commit SHAs.

## 5. Deploy the landing zone (from the customer repository)

Work in the **generated repository** from here on.

1. **State backend first.** Azure Storage backend: apply
   `terraform/backend-bootstrap/` once, then put its storage-account name into
   each layer's `backend.hcl` (the generated stacks ship with a
   `<REPLACE_WITH_OUTPUT_FROM_BOOTSTRAP>` placeholder — `terraform init`
   fails until you replace it). HCP Terraform backend: workspaces come from
   the broker; no placeholder step.
2. **Fill the operator placeholders** in `connectivity.auto.tfvars`:
   uncomment and set `management_ip_ranges` now (required; wildcards
   rejected). Leave `log_analytics_workspace_id` for the loop-back in step 4.
3. **Open a pull request** with the configuration. The `terraform-plan`
   workflow runs per changed layer as the **Reader-only plan identity**
   (`-lock=false`, advisory). The `azure-auth-test` workflow proves the OIDC
   token exchange. Read every plan; there must be no unintended destroy or
   replace.
4. **Merge to deploy.** `terraform-apply` runs layers in dependency order,
   each behind its gated environment approval:

   ```
   global → platform-connectivity → platform-management → workloads-prod → sandbox
   ```

   **Loop-back:** after `platform-management` applies, copy its
   `log_analytics_workspace_id` output into `connectivity.auto.tfvars` via a
   follow-up PR — until then, hub firewall diagnostics and threat-intel alerts
   are silently not created.
5. **Known first-apply traps** (all in `PROD-TODO.md`): the backend.hcl
   placeholder (step 1); unset `management_ip_ranges` (step 2); missing
   sandbox RBAC grant — if `sandbox` fails with `AuthorizationFailed` on a
   role assignment, the deploying identity lacks RBAC Administrator on the
   sandbox subscription (see [Bootstrap-Walkthrough](03-bootstrap-walkthrough.md)
   step 4).

The landing zone is now stored and managed from the customer repository:
changes go through PRs there, plans run read-only on PRs, applies run through
gated environments on merge.

## 6. Dispose of the clone

The clone was always disposable. **Archive first, then delete.**

1. **Archive to the client's records** (or the customer repo's docs):
   `lz-config.json`, `bootstrap-plan.json` + `bootstrap-audit.json`,
   `scaffold-plan.json` + `scaffold-audit.json`,
   `discovery-inventory.json` + `tenant-readiness-report.md`, and
   `.reports/bootstrap/*`. `lz-config.json` is the regeneration key for the
   whole landing zone — losing it means rebuilding configuration from scratch.
2. **Delete the clone directory.** This removes `.lz-bootloader-state.json`
   (tenant/subscription IDs), `generated-output/`, rendered staging, and
   `.terraform/` caches in one stroke.
3. **End the sessions**: `az logout` and `az account clear`;
   `gh auth logout`; remove the HCP token (`terraform logout`); unset
   `TFE_TOKEN` and any `LZ_*` variables from your shell profile.
4. **Fork residue** — decide with the client: if the fork is retired now that
   the customer repo owns the landing zone, delete its Actions secrets, revoke
   the `TF_API_TOKEN`, and archive the repository; if the fork stays as the
   client's factory instance for future regeneration, record that it holds
   tenant-scoped configuration (secrets, environments, the committed
   bootstrap state file).
5. **Do NOT delete**: the customer repository, the Azure resources and the
   state storage account/containers (or HCP workspaces), or the landing-zone
   service principals in the client tenant — they are the deliverable. If the
   legacy bootstrap's fork-bound identities are being retired in favor of the
   broker-created ones, remove their federated credentials and role
   assignments deliberately, as a reviewed change — never leave two
   write-capable identity sets where one is unmonitored.

## 7. Repeat

Next customer: new fork/copy, new clone, new wizard run. Nothing from the
previous engagement carries over — run `az account clear` and `gh auth logout`
between customers so a session from customer A can never touch customer B's
tenant.
