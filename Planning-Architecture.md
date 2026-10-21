# Planning, Architecture & Implementation

**Last Updated**: 2026-06-30  
**Status**: Phase 0-1 Planning Complete

---

## Table of Contents

- [Executive Overview](#executive-overview)
- [Architecture Overview](#architecture-overview)
- [Implementation Plan](#implementation-plan)
- [Implementation Roadmap](#implementation-roadmap)
- [Architecture Summary](#architecture-summary)
- [Architecture Decision](#architecture-decision)

---

## Executive Overview

The HCW Azure Landing Zone is a production-ready infrastructure-as-code system built on Terraform + Azure Verified Modules (AVM), with GitHub Actions for CI/CD automation and Terraform Cloud for state management.

**Key Policy**: ❌ **NO INFRASTRUCTURE DEPLOYMENTS** until all code complete, validated, and signed off.

---

## Architecture Overview

### The Stack

**✅ YES - Use Terraform + ALZ Verified Modules**

\\\
Terraform Cloud (State Management)
    ↓
terraform/
├─ modules/              (Azure Landing Zone - verified)
│  ├─ alz-connectivity
│  ├─ alz-management
│  ├─ alz-identity
│  └─ custom modules
│
└─ live/                 (Infrastructure environments)
   ├─ global
   ├─ connectivity
   ├─ management
   └─ workloads
\\\

**✅ YES - Use GitHub Actions Workflows**

\\\
.github/workflows/
├─ 010-terraform-init.yml     (Initialize TFC state)
├─ 020-rbac-validation.yml    (Validate RBAC config)
├─ 100-terraform-plan.yml     (Drift detection on PRs)
├─ 200-terraform-apply.yml    (Enforce desired state)
└─ 300-compliance-scan.yml    (Policy compliance)
\\\

**✅ YES - Use PowerShell for Bootstrap ONLY**

\\\
scripts/
└─ 000_LZ_Bootloader.ps1
   ├─ Validates CLI tools
   ├─ Creates OIDC federation
   ├─ Sets GitHub integration
   └─ Runs ONCE per landing zone
\\\

**❌ NO - Don't Use PowerShell for Operations**

- Cleanup-ExpiredSandboxResources.ps1 → Use Terraform lifecycle
- Create-ResourceGroups.ps1 → Use Terraform modules
- Set-RbacRoles.ps1 → Use Terraform RBAC module

---

## Implementation Plan

### Phase 0: Bootstrap (✅ COMPLETE)

**Timeline**: 1 day (past)

**Deliverables**:
- GitHub repository (private, branch protected)
- GitHub Actions OIDC federation to Azure
- Bootstrap script (1,070 lines)
- Entra applications & service principals
- Foundation documentation

---

### Phase 0.1: Terraform Cloud Setup (⏳ AWAITING USER)

**Timeline**: 2.5 hours (manual configuration)

**What User Must Do**:
1. Create Terraform Cloud Organization
2. Create 6 TFC Workspaces (lz-global, lz-connectivity, etc.)
3. Generate TFC API Token
4. Configure GitHub Secrets
5. Verify Setup

---

### Phase 1: Core Code & Processes (⏳ IN PROGRESS)

**Timeline**: 8-15 hours total

**Task 1.1**: Service Principal RBAC
- Create 5 least-privilege SPs per layer
- Configure OIDC federated credentials
- Update GitHub secrets
- Validate RBAC configuration

**Task 1.2**: Terraform State Security
- Document TFC state management
- Configure access logging
- Document token management

**Task SEC-1**: GitHub Secret Scanning
- Enable secret scanning
- Create secrets-scan.yml workflow
- Configure Dependabot
- Test blocking secrets

**Workflows 100-300**: Terraform Deployment
- 100: Terraform plan (drift detection)
- 200: Terraform apply (enforcement)
- 300: Compliance scanning

---

## Implementation Roadmap

### Critical Path

\\\
Start: Phase 0.1 (TFC Setup - manual by user)
         ↓
      Phase 1.1 (RBAC) + 1.2 (Docs) + SEC-1 (Secrets) [parallel]
         ↓
      Workflows 200s-300s
         ↓
      Testing & Validation
         ↓
      Sign-Off & GO/NO-GO
         ↓
      DEPLOYMENT READY
\\\

### Timeline Summary

| Phase | Component | Status | Effort | Blocker |
|-------|-----------|--------|--------|---------|
| 0 | Bootstrap | ✅ 100% | Done | None |
| 0.1 | TFC Setup | ⏳ 0% | 2h | Manual (create TFC org) |
| 1.1 | RBAC Code | ⏳ 0% | 8-15h | Phase 0.1 |
| 1.2 | State Docs | ⏳ 0% | 5-7h | Phase 0.1 |
| SEC-1 | Secrets | ⏳ 0% | 4-5h | None |
| 200s-300s | Workflows | ⏳ 0% | 10-14h | Phase 0.1 + 1.1 |
| Testing | Validation | ⏳ 0% | 8.5h | All code complete |
| **TOTAL** | **All Items** | **~42% Done** | **~37-45h** | **TFC Setup** |

---

## Architecture Summary

### How Drift Detection Works

\\\
1. Admin manually changes Azure policy in portal
   ↓
2. Developer commits Terraform code (unchanged)
   ↓
3. Developer opens PR
   ↓
4. Workflow 100 runs: terraform plan
   └─ Output: "Policy X is not in desired state"
   ↓
5. PR shows drift detection in comments
   ↓
6. Developer reviews and makes decision:
   Option A: Discard drift (terraform apply reverts change)
   Option B: Accept drift (update Terraform code)
   ↓
7. PR merged → Workflow 200 runs terraform apply
   └─ Manual change is corrected to match code
   ↓
8. State is now consistent (no drift)
\\\

**Key**: Drift detection is AUTOMATIC, not manual.

### How Idempotency Works

First Deploy:
\\\
terraform plan
└─ "Will create: azurerm_resource_group, azurerm_virtual_network, ..."

terraform apply
└─ Creates all resources
\\\

Second Deploy (No Changes):
\\\
terraform plan
└─ "No changes needed. All resources match desired state."

terraform apply
└─ "No changes needed."
\\\

**Key**: Safe to run terraform apply multiple times.

### How Immutability Works

\\\
State Desired:           Resource As Deployed:
├─ VNet: 10.0.0.0/8      ├─ VNet: 10.0.0.0/8    ✓ Match
├─ Policy: Deny-Owner    ├─ Policy: Deny-Owner  ✓ Match
└─ Role: Contributor     └─ Role: Contributor   ✓ Match

If someone manually changes:
\$ az network vnet update ... --address-prefix 10.1.0.0/8

Next terraform plan detects:
"azurerm_virtual_network: VNet CIDR is 10.1.0.0/8 but desired
 state is 10.0.0.0/8. Will revert on next apply."

This enforcement is GUARANTEED by Terraform.
\\\

---

## Architecture Decision

### Decision Made

✅ **Terraform + ALZ is the foundation**
- Infrastructure as Code everywhere
- Drift detection built-in
- Idempotent by design
- Immutable deployments
- Full audit trail

⚠️ **PowerShell is bootstrap only**
- Set up trust between systems
- One-time execution
- Then hand off to Terraform

❌ **PowerShell is NOT for operations**
- Don't create operational scripts
- Convert existing scripts to Terraform
- Focus on IaC maintainability

### Why Terraform + ALZ is Better

| Aspect | PowerShell Scripts | Terraform + ALZ |
|--------|-------------------|-----------------|
| **Drift Detection** | Manual audits | Automatic (terraform plan) |
| **Idempotency** | Must implement per script | Built-in |
| **State Tracking** | None | TFC tracks all changes |
| **Rollback** | Manual | Automatic (state versioning) |
| **Audit Trail** | Git commits | Git + TFC versions |
| **Security** | No enforcement | ALZ provides guardrails |
| **Compliance** | Manual verification | Automated policy scanning |
| **Reproducibility** | Script-dependent | Fully reproducible |
| **Scalability** | Breaks at scale | Designed for scale |
| **Maintenance** | High (script rot) | Low (standard patterns) |

---

## Migration Notes

### From PowerShell to Terraform

**Old (Wrong)**: PowerShell script cleanup
\\\powershell
Remove-AzResourceGroup -Name \
\\\

**New (Right)**: Terraform module
\\\hcl
resource "azurerm_resource_group" "sandbox" {
  name     = "rg-sandbox-\"
  location = var.region
  
  lifecycle {
    prevent_destroy = false
  }
  
  tags = {
    environment = "sandbox"
    lifecycle   = "temporary"
  }
}
\\\

**Benefits**:
- State tracked in TFC (audit trail)
- Drift detection automatic
- Immutable deployments
- Idempotent (safe to re-run)
- No PS1 maintenance burden

---

## Key Decisions

1. **VALIDATE-not-trust default**: Items previously claimed complete are re-verified in Phase 5 before being marked done
2. **Webapp plan detail lives in separate docs**, main roadmap carries short pointer entries
3. **Security goes last**: Enables one cohesive hardening pass
4. **Optional modules stay deferred**: Phase 1 ensures module code exists; deployment remains explicit opt-in
5. **Existing Phase 0 bootstrap unchanged**: Customer-facing setup remains distinct

---

## Related Documentation

- [Session-History.md](./Session-History.md) - Session summaries and status
- [Pre-Deployment-Checklist.md](./Pre-Deployment-Checklist.md) - Detailed checklist
- [Requirements.md](./Requirements.md) - RBAC requirements
- [Customer-Setup-Guide.md](./Customer-Setup-Guide.md) - Setup instructions

---

**Status**: Planning complete, implementation in progress  
**Next Action**: User executes Phase 0.1 TFC setup  
**Estimated Deployment**: ~4 weeks after TFC setup
