# Generate and Deploy

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

Step 4 of 4 in **How to Get Started**.
← [Prepare and run the wizard](03-bootstrap-walkthrough.md)

You now have a copy of the factory on your machine, signed in to the tools, and
`generated-output/<customer>/lz-config.json`. This page: check tenant
readiness, reconcile prerequisites with the broker, render and scaffold the
customer's repository, deploy the landing zone from it, then dispose of the
copy. Each mutating tool here is **plan-first**: run it once to see exactly
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
> `repository-scan` (the Security Scan job the generated repository ships; it runs
> on every pull request, so a merge can never wait on a check that does not
> report). To require more, set `LZ_REQUIRED_STATUS_CHECKS` to a comma-separated
> list of exact check-run names, and only add path-filtered or per-layer checks if
> every pull request in the engagement will trigger them.

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

1. **State backend: already done.** The broker created it (section 2). On the Azure
   Storage backend that is a storage account and container in the resource group
   named in the wizard: shared-key access off, versioning and soft delete on, and a
   delete lock on the resource group. Each layer's `backend.hcl` was rendered with
   those exact names, so there is nothing to apply first and no placeholder to fill
   in. On the HCP Terraform backend the broker created one workspace per layer.
2. **Fill the operator placeholders** in `connectivity.auto.tfvars`:
   uncomment and set `management_ip_ranges` now (required; wildcards
   rejected). Leave `log_analytics_workspace_id` for the loop-back in step 4.
3. **Open a pull request** with the configuration. The `terraform-plan`
   workflow runs per changed layer as the **Reader-only plan identity**
   (`-lock=false`, advisory). The `azure-auth-test` workflow proves the OIDC
   token exchange. Read every plan; there must be no unintended destroy or
   replace.

   **If a pull-request job cannot log in to Azure** you will see:

   ```
   AADSTS700213: No matching federated identity record found for presented
   assertion subject 'repo:<owner>/<repo>:pull_request'.
   ```

   That means the plan identity has no federated credential for pull requests. The
   broker creates it, so first re-run the broker (it is idempotent) and read its
   audit. To fix it by hand you need the Application Administrator role, and
   `<APP_ID>` is the plan identity's application ID (the value of the repository
   secret `AZURE_PLAN_CLIENT_ID`):

   ```bash
   az ad app federated-credential create --id <APP_ID> --parameters '{"name":"pr-plan","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<owner>/<repo>:pull_request","audiences":["api://AzureADTokenExchange"]}'
   ```

   Then re-run the pull-request checks and confirm the Azure login step passes.
4. **Merge to deploy.** `terraform-apply` runs layers in dependency order,
   each behind its gated environment approval (on a private repository that
   approval needs GitHub Enterprise; on Pro or Team, branch protection with
   required pull-request approvals is the control. See "Which GitHub plan do you
   need?" in the [credentials checklist](02-credentials-checklist.md)):

   ```
   global → platform-connectivity → platform-management → workloads-prod → sandbox
   ```

   **Loop-back:** after `platform-management` applies, copy its
   `log_analytics_workspace_id` output into `connectivity.auto.tfvars` via a
   follow-up PR — until then, hub firewall diagnostics and threat-intel alerts
   are silently not created.
5. **Known first-apply traps** (tracked in [TODO.md](../../TODO.md)): unset
   `management_ip_ranges` (step 2); and a missing sandbox RBAC grant — if `sandbox`
   fails with `AuthorizationFailed` on a role assignment, the deploying identity
   lacks RBAC Administrator on the sandbox subscription. The broker grants that only
   when the sandbox subscription was set in the wizard before it ran, so set it and
   re-run the broker (see the [credentials checklist](02-credentials-checklist.md)).

The landing zone is now stored and managed from the customer repository:
changes go through PRs there, plans run read-only on PRs, applies run through
gated environments on merge.

## 6. Dispose of the copy

The copy was always disposable. **Archive first, then delete.**

1. **Archive to the client's records** (or the customer repo's docs):
   `lz-config.json`, `bootstrap-plan.json` + `bootstrap-audit.json`,
   `scaffold-plan.json` + `scaffold-audit.json`,
   `discovery-inventory.json` + `tenant-readiness-report.md`, and
   `.reports/bootstrap/*`. `lz-config.json` is the regeneration key for the
   whole landing zone — losing it means rebuilding configuration from scratch.
2. **Delete the copy of the factory** (the folder you cloned or unzipped). This
   removes `generated-output/` (the customer's configuration and identifiers),
   rendered staging, and `.terraform/` caches in one stroke.
3. **End the sessions**: `az logout` and `az account clear`;
   `gh auth logout`; remove the HCP token (`terraform logout`); unset
   `TFE_TOKEN` and any `LZ_*` variables from your shell profile.
4. **A GitHub copy of the factory** (only if you made one, option 3 on the previous
   page): delete it. It is an installer that is never hardened and holds no secrets
   ([decision 0004](../decisions/0004-factory-copy-is-a-disposable-installer.md)),
   and nothing in it is needed once the customer repository exists.
5. **Do NOT delete**: the customer repository, the Azure resources and the
   state storage account/containers (or HCP workspaces), or the landing-zone
   service principals in the client tenant — they are the deliverable. If an earlier
   engagement used the legacy bootstrap (`Start-LandingZoneBootstrap.ps1`), its
   identities are a second, separate set from the broker-created ones: remove their
   federated credentials and role assignments deliberately, as a reviewed change — never leave two
   write-capable identity sets where one is unmonitored.

## 7. Repeat

Next customer: a new copy of the factory and a new wizard run. Nothing from the
previous engagement carries over — run `az account clear` and `gh auth logout`
between customers so a session from customer A can never touch customer B's
tenant.
