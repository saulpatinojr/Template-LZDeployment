# Getting Started

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

This page is step 1 of 4 in the **How to Get Started** guidebook.
Next: [Credentials-Checklist](02-credentials-checklist.md) →
[Bootstrap-Walkthrough](03-bootstrap-walkthrough.md) →
[Generate-and-Deploy](04-generate-and-deploy.md).

> The earlier "Getting Started" content for the self-deploying 4-phase plan now
> lives in the wiki's *Source Material* section — see [Phase-Roadmap](https://github.com/saulpatinojr/Template-LZDeployment/wiki/Phase-Roadmap) and
> [Phase-1-Prerequisites](https://github.com/saulpatinojr/Template-LZDeployment/wiki/Phase-1-Prerequisites). This page describes the
> current factory motion.

## What this repository is

**HCW-Plan_LZDeployment is a Landing Zone Factory.** You use it once per
customer to produce a brand-new, self-contained GitHub repository that deploys
and then manages that customer's Azure landing zone (management groups,
policies, hub network with firewall, management baseline, workload spokes).
The factory copy you work in is disposable; the repository it generates is the
long-lived deliverable.

## Who this guide is for

A single operator (L1 is fine) who has been given the client's credentials.
You do not need any other person to complete the walkthrough — every approval
gate you meet is one you approve yourself, using accounts from the
[Credentials-Checklist](02-credentials-checklist.md).

You need working knowledge of: running commands in a terminal, signing into
web accounts, and copying files between folders. You do **not** need to write
Terraform or read PowerShell.

## The motion — one engagement, seven moves

```
1. COPY      Take a copy of this repo — a clone, a fork, or a downloaded
             archive. The motion works from any of them; nothing requires a
             GitHub-side fork.
2. INITIATE  Run the initiation on your own machine: tools, sign-ins, and the
             broker that creates identities and OIDC federation.
3. WIZARD    Run the configuration wizard (site/), which produces
             lz-config.json — the contract the whole pipeline runs on.
4. GENERATE  The factory renders and scaffolds a NEW repository for the
             customer. That repository is the deliverable.
5. DEPLOY    The landing zone deploys from that new repository, layer by layer.
6. DISPOSE   Evidence is archived and this copy is deleted.
7. REPEAT    Next customer, fresh copy.
```

> **Two corrections to the older wording above (2026-08-27).**
> **(a) It is not a fork.** The copy may be a plain clone or a downloaded
> archive with no GitHub-side representation at all
> ([decision 0004](../decisions/0004-factory-copy-is-a-disposable-installer.md)) —
> never write a step that assumes a fork exists.
> **(b) There is no third-party consultancy in the motion.** The earlier text
> named an intermediary performing the copy on a client's behalf; that premise
> was corrected at
> [decision 0010](../decisions/0010-generated-repo-ownership-policy.md).
> **The operator runs it on their own machine, under their own `gh` and `az`
> sessions** — which is what makes the tenant-confirmation step load-bearing.
>
> This copy is a **disposable installer**, not an asset anyone governs: it is
> used once and deleted. The *generated* repository is what gets hardened, and
> the broker already does that.

Everything the factory creates is per-customer: identities, secrets,
environments, configuration, the generated repository, and the Azure resources
themselves. The disposal step ([Generate-and-Deploy](04-generate-and-deploy.md),
section 6) tells you exactly what to delete and — just as important — what to
keep.

## What you need before you start

Full details, with placeholders and where to get each item, are on the
[Credentials-Checklist](02-credentials-checklist.md). In summary:

**Accounts**
- A GitHub account that can create private repositories and administer the
  **generated** repository (the deliverable). Ownership follows
  [decision 0010](../decisions/0010-generated-repo-ownership-policy.md):
  an organization you control, with `ownershipModel: organization`.
- Access to the client's Azure tenant with rights to create app registrations
  (Entra) and to assign roles at the management-group root.
- Optional: an HCP Terraform (Terraform Cloud) account, if the engagement uses
  the HCP Terraform backend instead of Azure Storage.

**Tools** (any OS; Windows, macOS, and Linux all work)

| Tool | Minimum version | Check with |
| --- | --- | --- |
| PowerShell | 7.0 | `pwsh --version` |
| Azure CLI (`az`) | 2.69.0 | `az version` |
| GitHub CLI (`gh`) | 2.67.0 | `gh --version` |
| Git | 2.43.0 | `git --version` |
| Terraform | 1.9.0 | `terraform version` |

The bootstrap script checks these versions for you and prints install
instructions for anything missing — you can let it tell you what to fix.

**A modern web browser** — the configuration wizard is a local page
(`site/index.html`); it makes no network calls and nothing you type leaves
your machine until you export files.

## What "done" looks like

At the end of [Generate-and-Deploy](04-generate-and-deploy.md) you will have:

- a private GitHub repository owned by the client, containing the rendered
  landing-zone Terraform, workflows, and documentation;
- the landing zone deployed into the client's Azure subscriptions, applied
  layer by layer through gated pipelines;
- evidence files (plans, audits, reports) archived to the client's records;
- no factory clone left on your machine, and no leftover sign-in sessions.

## Read this before trusting it in production

As of 2026-08-01 the factory is **v0.9.0** and its release gates are not all
met: there is no recorded successful end-to-end pipeline run yet, and the live
`pull_request` OIDC federated credential for this repository is a confirmed
open blocker (login failure `AADSTS700213` on every pull request). The
walkthrough tells you where you will hit these and how to resolve them for
your engagement. The authoritative, phase-by-phase blocker list is
[`TODO.md`](../../TODO.md)
in the repository.

Also honest, so you can set expectations with the customer: the
`keyvault-cmk` (customer-managed keys) and `sentinel-siem` (Sentinel) modules
are **scaffolds** — the factory deliberately refuses to render them — and
`defender-baseline` is not deployed automatically. Do not present these as
live capabilities.

**Next: [Credentials-Checklist](02-credentials-checklist.md)**
