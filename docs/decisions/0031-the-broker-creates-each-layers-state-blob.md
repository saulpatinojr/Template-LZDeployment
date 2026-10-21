# Decision 0031 — The broker creates each layer's state blob, so the read-only plan identity never writes state

- **Status**: **Accepted** — operator-approved 2026-10-21 (the recommended option in
  [issue #140](https://github.com/saulpatinojr/Template-LZDeployment/issues/140)).
- **Date**: 2026-10-21
- **Deciders**: operator
- **Technical depth**: L300 (broker apply path, Terraform state format, identity model)

## Context and Problem Statement

On the azurerm backend, the first pull-request plan for a layer that has never been applied is
expected to fail at `terraform init`.

When a layer's state blob does not exist, Terraform's azurerm backend takes a blob lease, writes an
empty state and persists it, during `terraform init` and regardless of `-lock=false`
([`backend_state.go`, `StateMgr`, Terraform 1.15.8](https://github.com/hashicorp/terraform/blob/v1.15.8/internal/backend/remote-state/azure/backend_state.go#L107-L153)).
That write needs `blobs/write`, the Storage Blob Data Contributor role
([Lease Blob](https://learn.microsoft.com/rest/api/storageservices/lease-blob)). The plan identity
only has Storage Blob Data Reader, on purpose ([decision 0002](0002-minimal-identity-estate.md)).

The broker creates the state storage account and container
([`Set-LzAzurermBackend`](../../factory/bootstrap/LZFactory.Bootstrap.psm1)) but not the per-layer
blobs, and nothing else creates them before the first apply. The operator guide's flow opens the first
pull request, and so runs the first plan, before any apply.

Running the pull-request plan with `-lock=false` fixes every plan *after* a layer's state exists
(decision 0030, in review at the time of writing). It does not fix this first-run case.

## Decision

**The broker creates any missing per-layer state blob when it reconciles the azurerm backend.**

- **Where:** `Initialize-LzStateBlobs`, called from `Set-LzAzurermBackend` right after the container
  is reconciled and before the identities that depend on it. It runs in the operator's own `az`
  session, the same session that already creates the container.
- **Which blobs:** one per active layer in the plan (`platform-management`, `global`,
  `platform-connectivity`, and `state-hardening` when it is emitted), named `<layer>.tfstate`.
- **What goes in them:** exactly what Terraform writes itself the first time it initialises an empty
  state: state format 4, a fresh lineage per blob, serial 1, no outputs, no resources. The shape comes
  from Terraform's own writer (`statefile/version4.go`) and first-write rule (`remote/state.go`). The
  file's `terraform_version` is the **minimum** supported version
  (`toolchain.terraform.required` in `factory-version.json`), since the field means "the version that
  last wrote this" and Terraform rewrites it on its first real write.
- **Create-only.** It checks whether the blob exists, uploads only if it does not, and passes
  `--overwrite false` so the service refuses to replace one even if it appears in between. It never
  deletes and never touches an existing blob. A second run changes nothing.
- **Authentication:** always `--auth-mode login` (the operator's own sign-in). No account key and no
  SAS token, consistent with the account having shared-key access off.
- **Evidence:** plan mode lists the blobs it *would* create in `bootstrap-audit.json`; apply records
  the outcome (`initialized` or `exists`) under `backend.details.stateBlobs`. `bootstrap-plan.json` is
  deliberately unchanged, because it is under a byte-parity contract with existing fixtures.
- **A new cross-file contract:** the blob name the broker creates must equal the `key` line of
  [`backend.hcl.tmpl`](../../factory/templates/terraform/live/_layer/backend.hcl.tmpl), or the blob
  created here would not be the one Terraform looks for. `Test-Bootstrap.ps1` enforces it.
- The HCP Terraform backend is unaffected: its workspaces are created by the broker, not blobs.

## Consequences

- The first pull-request plan for a layer finds its state and only has to read it, so the plan
  identity stays read-only (risks SR2 and SR5 in the factory design record).
- The operator's account needs **Storage Blob Data Contributor** on the state container (or account)
  to create the blobs. The broker already needed this to create the container with `--auth-mode login`;
  the error messages now name the role. The operator guide should list it among the operator's
  permissions (follow-up).
- If a layer's state blob is deleted by mistake and the broker is re-run, it is recreated **empty**,
  exactly as Terraform's own `init` would recreate it. Recover a deleted blob from soft delete or
  versioning (both are on) instead of re-running the broker.
- The `global` layer reads `platform-management`'s state. Applying `platform-management` first is
  still required; this decision does not change that order.

## Alternatives considered

- **An emitted one-time "initialise state" workflow** run under the apply identity. Rejected: it adds a
  workflow and an approval to every generated repository, and pull-request plans fail until someone
  has run it.
- **A documented manual step** (the operator runs `terraform init` per layer). Rejected: error-prone,
  and `backend.hcl` sets `use_oidc = true`, so it needs a different local sign-in mode that has not
  been verified.
- **Give the plan identity write access to state.** Rejected: any pull request could then write state,
  which is what SR2 and SR5 exist to prevent.
- **Generate the empty state with Terraform itself.** Rejected for the broker: it runs before the
  layers are rendered, and has no Terraform to hand. The hand-built file is checked against the real
  binary instead (below).

## Verification

- `Test-Bootstrap.ps1`: 117 passed, 0 failed. It covers the exact state format, a recording fake of
  `az` (nothing exists, some exist, all exist, a race, an unauthorised upload, an unauthorised check,
  no layers), the plan-mode audit, and the template contract. Two deliberate breakages (allowing
  overwrite, skipping the existence check) were each caught by the suite.
- The generated state is accepted by a real Terraform (1.16.6): `terraform show`, `state list` and
  `plan` all succeed on it, and a corrupt file is rejected, so the check can fail. This runs in the test
  suite whenever Terraform is installed.
- The `az` flags (`blob exists`, `blob upload` with `--overwrite`, `--content-type`, `--auth-mode`)
  were taken from Microsoft's CLI reference, not from memory.
- **Not verified:** a run against a live Azure tenant. No real instantiation has happened yet
  ([REVIEW.md](../../REVIEW.md), item 4).
