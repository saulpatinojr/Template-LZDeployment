# Bootstrap Walkthrough

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

Step 3 of 4 in **How to Get Started**.
← [Credentials-Checklist](02-credentials-checklist.md) | Next: [Generate-and-Deploy](04-generate-and-deploy.md)

This page takes you from nothing to: a client-owned copy of the factory on
your machine, signed-in CLIs, the OIDC identities and GitHub plumbing created,
and the customer's configuration exported from the wizard.

## 1. Fork (or copy) the factory to the client

The client must **own** their copy of this repository.

1. Signed in as the client's GitHub account, open
   `https://github.com/saulpatinojr/Template-LZDeployment` and use **Fork**
   (or, preferably for confidentiality, create a **private** copy:
   `gh repo create <client-org>/<repo-name> --private` and push this
   repository's contents to it — a fork of a public repository is always
   public, and the bootstrap later commits a state file containing tenant and
   subscription IDs).
2. On the client copy, enable **Actions** (Actions tab → enable workflows).
   Forks start with workflows disabled.
3. Note what a fork does **not** inherit and must be re-created per client:
   branch protection/required checks, secrets, variables, environments, and
   third-party integrations. The bootstrap below creates the secrets,
   variables, and environments; branch protection is a manual settings step.

## 2. Clone it

```bash
git clone https://github.com/<client-owner>/<repo-name>.git
cd <repo-name>
```

Keep exactly one clone per customer. Never reuse a clone across engagements.

## 3. Install tools and sign in (the "initiation")

Versions and install commands are in
[Getting-Started](01-getting-started.md#what-you-need-before-you-start); the
bootstrap validates them and prints per-OS install instructions for anything
missing.

Sign in to the three services (the only manual authentication in the whole
flow — everything after this uses OIDC or your CLI sessions):

```bash
az login --tenant <tenant-id>     # browser or device-code sign-in
gh auth login                     # choose github.com, HTTPS, browser
terraform login                   # HCP Terraform backend only; skip for Azure Storage
```

## 4. Run the bootstrap

```powershell
pwsh ./scripts/Start-LandingZoneBootstrap.ps1 -SandboxSubscriptionId <sandbox-subscription-id>
```

Pass `-SandboxSubscriptionId` whenever the engagement includes the sandbox
subscription — without it the script warns you, and later the
platform-management apply fails with `AuthorizationFailed` on the
sandbox-cleanup role assignment.

The script is **idempotent**: if it fails or you stop it, re-run it and it
resumes from its saved state (`.lz-bootloader-state.json` in the repo root).
To start over from scratch, delete that file first.

### What it will prompt you for

| Prompt | What to answer |
| --- | --- |
| Organization prefix | The customer's short name, lowercase letters/digits (e.g. `contoso`). Used in every resource and identity name. |
| Which environments | `1` Dev only, `2` Prod only, `3` Both. (Known quirk: option `1` currently still configures both dev and prod — tracked in `PROD-TODO.md`.) |
| GitHub repository name | The client fork's actual name. **Do not accept the default** (`HCW-Demo-LZDeployment`) unless it matches; secrets and OIDC subjects are written against this name. If the fork lives in an organization rather than your user account, see the caution below. |
| `CREATE` confirmation | The script pauses before touching Azure and tells you what it is about to create. Type `CREATE` to proceed, or press Enter to skip the Azure identity phase. |
| Terraform Cloud organization | The client's HCP Terraform org name. Press Enter to skip TFC setup entirely (Azure Storage backend). |
| TFC API token | Pasted hidden; stored straight into the GitHub secret `TF_API_TOKEN`. Never lands on disk. |
| Create PR? | `y` opens a bootstrap PR containing the state file and report; `N` skips. |

> **Caution — organization-owned forks:** the script currently targets
> `<your-github-login>/<repo-name>` (it resolves the owner from your `gh`
> session, not from the clone's origin). If the client fork is under an
> organization, the secrets and OIDC subjects would be created against the
> wrong repository path. This is a known gap in `PROD-TODO.md`; until fixed,
> use a fork under the account you sign `gh` in with, or fix up the created
> federated-credential subjects afterwards.

### What it creates (phase by phase)

1. **CLI validation** — az/gh/git/terraform present and at minimum versions.
2. **Authentication** — confirms Azure, GitHub, and (optionally) TFC sessions.
3. **Configuration** — the prompts above, saved to `.lz-bootloader-state.json`.
4. **Azure OIDC identities** — four app registrations + service principals,
   named `sp-terraform-<layer>-<env>-<prefix>`:
   - `main` — Contributor + Storage Blob Data Contributor; federated to the
     `main` branch and to the `dev`/`prod`/`hub` environments;
   - `dev`, `prod` — same plus RBAC Administrator; federated to their
     environments;
   - `plan` — **Reader-only** (Reader + Storage Blob Data Reader); the ONLY
     identity federated to the `pull_request` subject, so a PR-triggered plan
     can read but never change anything.
   No client secrets are created — trust is OIDC federated credentials. The
   script refuses to continue if any identity somehow holds Owner.
   With `-SandboxSubscriptionId`, the deploying identity also gets RBAC
   Administrator scoped to the sandbox subscription only.
5. **GitHub secrets and variables** — `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID`, `AZURE_PLAN_CLIENT_ID`; plus
   `AZURE_REGION`, `AZURE_REGION_CODE`, `ORG_PREFIX`, `TF_VERSION`,
   `TERRAFORM_CLOUD_ENABLED` variables.
6. **GitHub environments** — `dev`, `prod`, `hub`, each requiring a reviewer
   (you, the bootstrapping operator — swap in a client team later) and
   restricted to protected branches.
7. **Terraform Cloud** — `TF_API_TOKEN` secret, `TF_CLOUD_ORGANIZATION` and
   `TF_CLOUD_WORKSPACE` variables (HCP backend only).
8. **Report** — a Markdown summary in `.reports/bootstrap/`.
9. **Optional PR** — branch `bootstrap/phase-0-oidc-setup-<date>` with the
   state file and report.

## 5. Verify OIDC before moving on

Open any small pull request in the fork (the bootstrap PR from step 9 works).
The PR-triggered workflows must log into Azure as the plan identity.

**Known failure you will see if the federated credential is missing:**

```
AADSTS700213: No matching federated identity record found for presented
assertion subject 'repo:<owner>/<repo>:pull_request'.
```

Fix (requires the Application Administrator role; `<APP_ID>` is the plan
identity's application ID from the bootstrap report):

```bash
az ad app federated-credential create --id <APP_ID> --parameters '{"name":"pr-plan","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<owner>/<repo>:pull_request","audiences":["api://AzureADTokenExchange"]}'
```

Then re-run the PR checks and confirm the Azure login step passes. The
generated customer repository gets an equivalent check as its
`azure-auth-test` workflow.

## 6. Run the configuration wizard

1. In your clone, open **`site/index.html`** in a browser (double-click the
   file). It is fully offline — nothing you enter leaves the machine.
2. Work through the **15 steps** left to right: organization, Azure
   subscriptions and regions, management groups, networking (hub, firewall,
   bastion, DNS), environments, backend choice, governance, and review. Fields
   validate as you type; the export button stays disabled until every blocking
   issue is resolved and lists what remains.
3. On the final step, **download all eight files**:

   | File | What it is |
   | --- | --- |
   | `lz-config.json` | **The contract.** Every downstream tool reads this; everything else is derived from it. |
   | `terraform.auto.tfvars` | Variables for the `global` layer. |
   | `connectivity.auto.tfvars` | Variables for `platform-connectivity` — includes the two commented operator placeholders (`management_ip_ranges`, `log_analytics_workspace_id`). |
   | `backend.hcl` | Partial backend config for `terraform init` (one per layer — replace `<layer>` in the key/workspace name per layer). |
   | `environments.json` | Environment definitions, promotion order, approval gates — consumed by the bootstrap broker. |
   | `deployment-metadata.json` | Provenance: factory and schema versions, timestamp, release gates. |
   | `CONFIGURATION.md` | Human-readable record of every decision, for change review. |
   | `NEXT-STEPS.md` | Generated command sheet. **Known issue:** it currently names some parameters that do not exist (`-Phase discovery`, `-DryRun`, `-AutoPush`, `--rollback`) — follow THIS wiki page and [Generate-and-Deploy](04-generate-and-deploy.md) instead; tracked in `PROD-TODO.md`. |

4. **Where the outputs go:** create a folder in your clone and move all eight
   files into it —

   ```
   <clone>/generated-output/<customer-short-name>/
   ```

   This path is gitignored, so the customer's identifiers cannot be committed
   to the fork by accident. Do not hand-edit the exported files; to change a
   value, re-run the wizard and re-export so config and variables cannot
   diverge.

**Next: [Generate-and-Deploy](04-generate-and-deploy.md)** — discovery, the broker,
rendering and scaffolding the customer repository, deploying, and disposing of
the clone.
