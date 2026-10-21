# Decision 0030 — On the azurerm backend, the pull-request plan runs without the state lock

- **Status**: **Accepted** — operator-directed 2026-10-21, resolving item 1 of
  [issue #134](https://github.com/saulpatinojr/Template-LZDeployment/issues/134).
- **Date**: 2026-10-21
- **Deciders**: operator
- **Technical depth**: L300 (generated workflow, state-backend permissions, identity model)

## Context and Problem Statement

Every generated repository runs `terraform plan` on each pull request under the
**plan identity**. That identity is read-only on purpose: Reader on the estate, and
**Storage Blob Data Reader** on the state container
([decision 0002](0002-minimal-identity-estate.md); risks SR2 and SR5 in the
[factory design record](../factory/factory-design.md)).

The azurerm backend takes the state lock by acquiring an **Azure Blob lease**, and
`terraform plan` takes that lock by default. Microsoft documents that Lease Blob needs
the RBAC action `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write`,
and that the least-privileged built-in role containing it is **Storage Blob Data
Contributor** ([Lease Blob](https://learn.microsoft.com/rest/api/storageservices/lease-blob)).
HashiCorp's azurerm backend page lists the same role as required
([azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)).
Storage Blob Data Reader does not include that action.

So a plain `terraform plan` under the plan identity is expected to fail to acquire the
state lock on every pull request, which would make the plan gate unusable on the
azurerm backend.

**How sure we are:** the permission requirement comes from the two documentation
pages above. It has **not been reproduced against a live backend**: no real
instantiation has run yet ([REVIEW.md](../../REVIEW.md), item 4).

## Decision

**Run the pull-request plan with `-lock=false` on the azurerm backend, and change
nothing else.**

- [`terraform-plan.yml.tmpl`](../../factory/templates/.github/workflows/terraform-plan.yml.tmpl)
  emits `terraform plan -input=false -no-color -lock=false -out=tfplan` when the
  backend is azurerm, with a comment saying why. The HCP Terraform path is unchanged.
- The plan identity stays read-only. A plan never writes state, so it does not need
  the lock.
- **Apply keeps its lock.** The apply workflow runs under the apply identity (Storage
  Blob Data Contributor), re-plans, and applies in the same job; the pull-request
  plan is never what gets applied.
- `Test-Renderer.ps1` asserts all three: azurerm plan has `-lock=false`, the azurerm
  apply workflow does not, and the HCP plan does not.

## Consequences

- A pull-request plan can run while an apply is writing state and may read state
  that is about to change. That is acceptable: the plan is advisory, and apply
  re-plans under the lock before it changes anything.
- If the first real instantiation shows the lock was not needed after all, the flag
  is harmless.
- **To verify on that first run:** open a pull request in a generated azurerm repo
  and confirm the plan job passes with the plan identity. Until then this fix is
  prepared, not proven live.

## What this did not cover, and what fixed it

`-lock=false` covers every plan **after** a layer's state file exists. It did not cover the
**first** plan for a layer that had never been applied. When the state blob does not exist,
Terraform's azurerm backend takes a lock with operation `"init"`, writes an empty state and
persists it, during `terraform init` and regardless of `-lock=false`
([`backend_state.go`, `StateMgr`, Terraform 1.15.8](https://github.com/hashicorp/terraform/blob/v1.15.8/internal/backend/remote-state/azure/backend_state.go#L107-L153)).
The plan identity cannot do that write, and at the time the broker created the storage account and
container but not each layer's `<layer>.tfstate` blob. So on a brand-new estate the first
pull-request plan for a layer was expected to fail at `terraform init`. This was raised in review and
verified against the source, then tracked in
[issue #140](https://github.com/saulpatinojr/Template-LZDeployment/issues/140).

**It is resolved by [decision 0031](0031-the-broker-creates-each-layers-state-blob.md):** the broker
now creates each layer's state blob, so the plan identity only ever reads it. That fix is covered by
tests and a real Terraform reading the file it writes. Like this decision, it has not been run against
a live backend.

## Alternatives considered

- **Give the plan identity Storage Blob Data Contributor.** Rejected: it would let
  any pull request's plan overwrite or corrupt state, which is exactly what SR2 and
  SR5 exist to prevent.
- **A custom role that allows only the lease.** Rejected because it cannot be built:
  Microsoft's permission table maps Lease Blob and the blob write operations to the
  same `blobs/write` action, so no narrower permission exists.
- **A separate "lock" identity for plans.** Rejected: more identities, more
  federation, more to go wrong, to protect an advisory plan.
- **Turn locking off everywhere.** Rejected: apply must hold the lock.
- **Leave it as it was.** Rejected: the plan gate would fail on every pull request.
