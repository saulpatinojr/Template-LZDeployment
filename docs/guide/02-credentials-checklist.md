# Credentials Checklist

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

Step 2 of 4 in **How to Get Started**.
← [Getting-Started](01-getting-started.md) | Next: [Bootstrap-Walkthrough](03-bootstrap-walkthrough.md)

Every account, credential, identifier, secret, and permission an operator
needs to complete one engagement. All values shown are placeholders — collect
the real ones into your engagement notes (never into the repository).

## 1. Accounts you sign in with

| Item | Placeholder | Where to get it | What it is for |
| --- | --- | --- | --- |
| GitHub account | `your-github-login` | github.com (client provides or creates one for the engagement) | `gh auth login`; owning/administering the client's copy of the factory; creating the generated customer repository. |
| Azure work account | `operator@client.example.com` | Client's IT admin creates it in their tenant | `az login`; creating identities and granting roles in the client tenant. |
| HCP Terraform account (optional) | `you@client.example.com` on app.terraform.io | app.terraform.io sign-up, join the client's organization | Only if the engagement uses the HCP Terraform backend (the recorded default; Azure Storage is the fully supported alternative). |

## 2. Azure identifiers (the wizard and the bootstrap ask for these)

| Item | Placeholder | Where to get it | What it is for |
| --- | --- | --- | --- |
| Tenant ID | `11111111-2222-3333-4444-555555555555` | Azure Portal → Microsoft Entra ID → Overview → Tenant ID | Identifies the client directory to OIDC and to `az login --tenant`. |
| Management subscription ID | `aaaaaaaa-0000-0000-0000-000000000001` | Portal → Subscriptions (client provides the layout) | Hosts the management/monitoring baseline layer. |
| Connectivity subscription ID | `aaaaaaaa-0000-0000-0000-000000000002` | Portal → Subscriptions | Hosts the hub network and firewall. |
| Workload (prod) subscription ID | `aaaaaaaa-0000-0000-0000-000000000003` | Portal → Subscriptions | Hosts production workload spokes. |
| Identity / workload non-prod / sandbox subscription IDs (optional) | `aaaaaaaa-0000-0000-0000-00000000000N` | Portal → Subscriptions | Optional layers; the wizard marks which are required. |
| Sandbox subscription ID (again, for the bootstrap) | same as above | — | Passed as `-SandboxSubscriptionId` so the deploying identity can write the sandbox-cleanup role assignment. **Skipping this makes the platform-management apply fail with `AuthorizationFailed`.** |
| Management-group root ID | `client-root` | Portal → Management groups (or the wizard's naming step defines it) | The scope where management groups are created and roles assigned. |

## 3. Azure permissions the operator's account needs

| Permission | Placeholder scope | Where it is granted | Why |
| --- | --- | --- | --- |
| Application Administrator (Entra role) | directory-wide | Entra ID → Roles and administrators | Create app registrations and **federated credentials** (the OIDC trust records). Without it, the bootstrap's identity phase fails. |
| Owner **or** User Access Administrator | management-group root (`client-root`) | Portal → Management groups → Access control (IAM) | Create management groups and assign the least-privilege roles the pipelines run with. |
| Subscription access | each subscription above | IAM on each subscription | The bootstrap assigns roles scoped to these subscriptions. |

The identities the bootstrap **creates** get less than you have: Contributor +
Storage Blob Data Contributor for apply, Reader + Storage Blob Data Reader for
the PR plan identity, RBAC Administrator only where sandbox cleanup requires
it. No service principal ever holds Owner (the scripts and pipelines both
check and refuse).

## 4. GitHub permissions and scopes

| Item | Placeholder | Where to get it | What it is for |
| --- | --- | --- | --- |
| Repository admin on the client's copy | — | Repository settings → Collaborators/Teams | Setting secrets, variables, environments, and branch protection. |
| Ability to create a private repository | — | Client org settings (or the operator's account) | The scaffold step creates the generated customer repository. |
| CLI scopes: `repo`, `workflow`, `read:org` | — | Granted during `gh auth login` (browser flow; the bootstrap requests them) | Lets `gh` set secrets/variables, manage environments, and open the bootstrap PR. |

### Which GitHub plan do you need?

The factory creates a **private** repository for the customer, and GitHub limits what a
private repository can do depending on the plan. This matters because the human approval
before an apply depends on it.

| Plan | Environments | Branch protection | Human approval before apply (an environment's *required reviewers*) |
| --- | --- | --- | --- |
| Free (personal account **or** organization) | No | No | No |
| Pro (personal) or Team (organization) | Yes | Yes | **No** — Enterprise only |
| Enterprise | Yes | Yes | Yes |

**What the factory does about it.** Its readiness check reads the plan and shows a
**Warning** that names every control your plan cannot provide, instead of skipping it
silently. GitHub only tells the tool the plan for your *own* account, so for an
organization the plan is often "unknown". The check then says plainly that it could not
verify the plan (a blind spot, not a pass), and you should look at **Settings → Billing
and plans** yourself.

**If you are on Pro or Team:** the environments are created but cannot hold an approval.
Turn on branch protection with required pull-request approvals, so that a person reviews
every change before it can reach apply.

Sources, checked 2026-10-21 (GitHub changes plan features from time to time):
[Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments),
[Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments),
[About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches),
[GitHub's plans](https://docs.github.com/en/get-started/learning-about-github/githubs-plans).

## 5. HCP Terraform (only for the HCP backend)

| Item | Placeholder | Where to get it | What it is for |
| --- | --- | --- | --- |
| Organization name | `client-org` | app.terraform.io → your organizations | Backend `organization` in the generated `backend.hcl`; workspaces live here. |
| API token | `xxxxxx.atlasv1.zzzzzzzz…` | app.terraform.io → Settings → Tokens → Create API token | The bootstrap stores it as the GitHub secret `TF_API_TOKEN` (as an **environment** secret in the dogfood flow); export it as `TFE_TOKEN` for local broker runs. **Never write it to a file in the repo or paste it into configuration.** |

## 6. Values the wizard asks for (no credentials, but have them ready)

Company name and short prefix (2–10 lowercase letters/digits, e.g. `contoso`),
primary region (e.g. `eastus`) and optional DR region, hub address spaces
(CIDR, e.g. `10.100.0.0/22`), firewall choice and tier, bastion/DNS toggles,
tags, environments and their promotion order, backend choice
(HCP Terraform or Azure Storage), GitHub owner + repository name for the
generated repo.

## 7. Two values the wizard deliberately does NOT collect

These arrive later as commented placeholders in `connectivity.auto.tfvars` —
this is by design (a recorded contract), so do not look for wizard fields:

| Variable | Placeholder | Where to get it | When |
| --- | --- | --- | --- |
| `management_ip_ranges` | `["203.0.113.0/24"]` | The client's network team — CIDR ranges allowed to reach firewall management. Wildcards (`*`, `0.0.0.0/0`) are rejected. | **Required before the first connectivity plan.** |
| `log_analytics_workspace_id` | `/subscriptions/aaaaaaaa-…/resourceGroups/rg-mgmt…/providers/Microsoft.OperationalInsights/workspaces/law-…` | Output of the platform-management layer **after it applies** | Recommended; without it, firewall diagnostics and threat-intel alerts are silently not created. |

## 8. Secrets and variables that get created FOR you

The bootstrap sets these — listed so you can verify them (client copy → Settings →
Secrets and variables → Actions), not create them by hand:

- Secrets: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID`
  (Contributor/apply identity), `AZURE_PLAN_CLIENT_ID` (Reader-only PR plan
  identity), `TF_API_TOKEN` (HCP backend only).
- Variables: `AZURE_REGION`, `AZURE_REGION_CODE`, `ORG_PREFIX`, `TF_VERSION`,
  `TERRAFORM_CLOUD_ENABLED`, `TF_CLOUD_ORGANIZATION`, `TF_CLOUD_WORKSPACE`.
- Environments: `dev`, `prod`, `hub` — each with a required reviewer and
  protected-branch deployment policy.

No client secret or password is ever created for these identities:
authentication is OIDC federated credentials only. If any step asks you to
create a service-principal password, stop — that is not this design.

## 9. Never store (from the repository's USER-CHECKLIST)

- Azure or GitHub **user** tokens.
- `TFE_TOKEN` / TFC API tokens, other than as the GitHub secret. The one exception
  is a temporary environment variable in your own terminal while a local broker run
  is in progress; clear it afterwards. Never put one in a file, the repository, or
  configuration.
- Client secrets.
- Storage account keys (state access is Azure AD only; key access is disabled).

**Next: [Bootstrap-Walkthrough](03-bootstrap-walkthrough.md)**
