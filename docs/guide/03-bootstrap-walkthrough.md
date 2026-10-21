# Prepare and Run the Wizard

> *Moved here from the project wiki on 2026-10-21. This copy is the maintained one.*

Step 3 of 4 in **How to Get Started**.
← [Credentials-Checklist](02-credentials-checklist.md) | Next: [Generate-and-Deploy](04-generate-and-deploy.md)

This page takes you from nothing to: a copy of the factory on your machine, signed-in
command-line tools, and the customer's configuration exported from the wizard. It does not
change anything in Azure or GitHub. The identities, the customer repository and the deployment
are created on the next page.

## 1. Get a copy of the factory

The copy is an installer. You use it once, on your machine, and delete it at the end
([decision 0004](../decisions/0004-factory-copy-is-a-disposable-installer.md)). So there is
nothing to set up on it: **do not** enable Actions, branch protection, environments or secrets
on it. The repository the factory *generates* gets all of that, from the broker, on the next
page ([decision 0007](../decisions/0007-retire-client-copy-hardening.md)).

Pick whichever is easiest. They all work the same afterwards.

1. **Clone it** (simplest):

   ```bash
   git clone https://github.com/saulpatinojr/Template-LZDeployment.git
   cd Template-LZDeployment
   ```

2. **Or download it.** On the repository's GitHub page choose **Code → Download ZIP**, then unzip
   it and open a terminal in the unzipped folder.

3. **Or, only if the copy must live on GitHub**, make a **private** copy with the repository's own
   script. Do not use GitHub's Fork button: a fork of a public repository is always public. Run
   this from a copy you already have (option 1 or 2). Without `-Apply` the script only shows what
   it would do; read that, then run it again with `-Apply`:

   ```powershell
   pwsh ./scripts/Initialize-ClientFork.ps1 -Repository <owner>/<name> `
       -SourceRepository saulpatinojr/Template-LZDeployment -CreatePrivateCopy
   pwsh ./scripts/Initialize-ClientFork.ps1 -Repository <owner>/<name> `
       -SourceRepository saulpatinojr/Template-LZDeployment -CreatePrivateCopy -Apply
   ```

   The script only creates the private copy and checks that it really is private. It does not
   harden anything, on purpose. Then clone your private copy and work in that.

## 2. One copy per customer

Keep exactly one copy per customer and never reuse one for another customer: that customer's
configuration and evidence end up inside it, and you delete it when the engagement is done.

## 3. Install tools and sign in (the "initiation")

Versions and install commands are in
[Getting-Started](01-getting-started.md#what-you-need-before-you-start).

Sign in to the three services (the only manual authentication in the whole
flow — everything after this uses OIDC or your CLI sessions):

```bash
az login --tenant <tenant-id>     # browser or device-code sign-in
gh auth login                     # choose github.com, HTTPS, browser
terraform login                   # HCP Terraform backend only; skip for Azure Storage
```

## 4. Run the configuration wizard

1. In your copy, open **`site/index.html`** in a browser (double-click the
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
   | `connectivity.auto.tfvars` | Variables for `platform-connectivity`. |
   | `backend.hcl` | Partial backend config for `terraform init` (one per layer — replace `<layer>` in the key/workspace name per layer). |
   | `environments.json` | Environment definitions, promotion order, approval gates — consumed by the bootstrap broker. |
   | `deployment-metadata.json` | Provenance: factory and schema versions, timestamp, release gates. |
   | `CONFIGURATION.md` | Human-readable record of every decision, for change review. |
   | `NEXT-STEPS.md` | A command sheet with the exact commands to run next, in order. It follows the same steps as this walkthrough and [Generate and Deploy](04-generate-and-deploy.md). The factory's automated tests check its script names, options and environment variables against the real scripts, so it cannot quietly drift. |

4. **Where the outputs go:** create a folder in your copy and move all eight
   files into it —

   ```
   <your-copy>/generated-output/<customer-short-name>/
   ```

   This path is gitignored, so the customer's identifiers cannot be committed
   by accident. Do not hand-edit the exported files; to change a
   value, re-run the wizard and re-export so config and variables cannot
   diverge.

> **You may notice `scripts/Start-LandingZoneBootstrap.ps1` in the repository.** It is the legacy
> single-repo bootstrap, kept for compatibility. It is **not** part of this path: the identities
> and the customer repository are created by the broker on the next page
> ([go-live runbook](../runbooks/go-live-opening.md)).

**Next: [Generate-and-Deploy](04-generate-and-deploy.md)** — discovery, the broker,
rendering and scaffolding the customer repository, deploying, and disposing of
this copy.
