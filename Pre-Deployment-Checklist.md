# Pre-Deployment Checklist

**Purpose**: Comprehensive checklist ensuring ALL code, processes, and validations complete before infrastructure deployment.

**Status**: 🟡 IN PROGRESS - Phase 1 Code/Process Build-Out

---

## Phase 0 (Bootstrap) - FOUNDATION

### ✅ Complete & Validated

- [x] GitHub repository created (private)
- [x] Branch protection on main (1+ approvals)
- [x] GitHub Actions OIDC federation configured
- [x] CODEOWNERS file in place
- [x] .gitignore configured
- [x] Terraform .terraform.lock.hcl files committed
- [x] Bootstrap script (1,070 lines, production ready)

---

## Phase 0.1 (Terraform Initialization)

### 🔄 Workflow 010: Terraform Cloud Backend

**File**: `.github/workflows/010-terraform-init.yml`

**Pre-Requisites** (NOT YET COMPLETE):

- [ ] Terraform Cloud organization created
- [ ] Terraform Cloud API token generated
- [ ] GitHub secrets configured:
  - [ ] TF_API_TOKEN
  - [ ] TF_CLOUD_ORGANIZATION
- [ ] Terraform Cloud workspaces defined:
  - [ ] lz-global
  - [ ] lz-connectivity
  - [ ] lz-management
  - [ ] lz-sandbox
  - [ ] lz-workloads-prod
  - [ ] lz-workloads-nonprod

**What This Validates**:
- ✅ OIDC federation works end-to-end
- ✅ Terraform Cloud credentials available
- ✅ Terraform configurations syntactically valid
- ✅ Code formatting complies with standards
- ✅ All module dependencies resolvable

---

## Phase 1 Code & Process Build-Out

### Task 1.1: Service Principal RBAC

**Status**: ⏳ NOT STARTED

**Deliverables**:
- [ ] Service Principal Creation Script (scripts/001_Create_Service_Principals.ps1)
- [ ] RBAC Validation Script (scripts/002_Validate_RBAC.ps1)
- [ ] Service Principal documentation
- [ ] RBAC audit procedures
- [ ] Testing & validation

**Effort**: 8-15 hours

**Acceptance Criteria**:
- ✅ No service principal has Owner role
- ✅ Each SP scoped to single subscription
- ✅ RBAC validation workflow passes
- ✅ Deployment succeeds with least-privilege SPs

### Task 1.2: Terraform State Security

**Status**: ⏳ AWAITING TERRAFORM CLOUD SETUP

**Deliverables**:
- [ ] TERRAFORM-CLOUD-SECURITY.md documentation
- [ ] DEPLOYMENT-GUIDE.md update
- [ ] State recovery script
- [ ] Testing & validation

**Effort**: 5-7 hours

### Task SEC-1: GitHub Secret Scanning

**Status**: ⏳ NOT STARTED

**Deliverables**:
- [ ] Repository settings configuration (manual)
- [ ] secrets-scan.yml workflow
- [ ] dependabot.yml configuration
- [ ] Testing & validation

**Effort**: 4-5 hours

---

## Terraform Module Code

### ✅ Phase 1 Modules - COMPLETE

- [x] Sandbox Module (terraform/modules/sandbox/)
  - [x] terraform.tf, variables.tf, main.tf, outputs.tf
  - [x] .terraform-docs.yml, README.md
  - [x] AVM Compliance: 11/11 verified
  - [x] terraform fmt & validate: PASSED

- [x] Live Configuration (terraform/live/sandbox/)
  - [x] main.tf, variables.tf, outputs.tf
  - [x] terraform.tfvars, backend.hcl
  - [x] terraform fmt & validate: PASSED

---

## CI/CD Workflows

### ✅ Phase 0 Workflows - COMPLETE

- [x] 010-terraform-init.yml (TFC initialization)
- [x] 020-rbac-validation.yml (RBAC audit)

### ⏳ Phase 1 Workflows - NOT STARTED

- [ ] 200-terraform-plan.yml (Drift detection on PR)
- [ ] 210-terraform-apply.yml (State enforcement on merge)
- [ ] 300-compliance-scan.yml (IaC compliance)
- [ ] 310-security-validation.yml (Post-deployment validation)

**Effort**: 8-11 hours

---

## Testing & Validation

### ✅ Complete

- [x] Terraform format check (module & live config)
- [x] Terraform validation (module & live config)
- [x] AVM compliance verification (11/11)
- [x] Module output validation
- [x] Feature toggle pattern tested

### ⏳ Not Yet Completed

- [ ] OIDC federation end-to-end test (1h)
- [ ] RBAC least-privilege test (2h)
- [ ] State security test (2h)
- [ ] Secret scanning test (1.5h)
- [ ] Drift detection test (1h)
- [ ] State enforcement test (1h)

**Total Effort**: 8.5 hours (no actual infrastructure changes)

---

## Pre-Deployment Validation Gate

**Critical checklist before executing ANY workflows:**

### Phase 0 Foundation

- [x] GitHub repository with branch protection
- [x] GitHub Actions OIDC federation configured
- [x] Bootstrap script complete & tested
- [x] Entra apps & SPs created

### Phase 0.1 Setup

- [ ] Terraform Cloud organization created
- [ ] Terraform Cloud workspaces defined (6)
- [ ] GitHub secrets configured
- [ ] Workflow 010 code complete and tested
- **BLOCKER**: Cannot proceed without TFC setup

### Phase 1 Code Complete

- [ ] Task 1.1 code complete (SP scripts + testing)
- [ ] Task 1.2 documentation complete
- [ ] Task SEC-1 code complete (secrets scanning)
- [ ] Workflows 100, 200, 300 code complete
- [ ] All bootstrap scripts created and tested
- [ ] All documentation finalized

### Phase 1 Validation Complete

- [ ] OIDC federation end-to-end test passed
- [ ] RBAC least-privilege test passed
- [ ] State security test passed
- [ ] Secret scanning test passed
- [ ] Drift detection test passed
- [ ] State enforcement test passed

### Sign-Off

- [ ] Security team review complete
- [ ] Infrastructure team review complete
- [ ] Compliance sign-off obtained
- [ ] Deployment schedule established

---

## Deployment Blocking Criteria

**DEPLOYMENT IS BLOCKED** until ALL are true:

### Code Completeness
- [ ] Task 1.1 scripts written & tested
- [ ] Task 1.2 documentation complete
- [ ] Task SEC-1 workflows complete
- [ ] Workflows 200-300 written & tested

### Process Completeness
- [ ] Bootstrap script executed
- [ ] Terraform Cloud organization created
- [ ] RBAC audit baseline created
- [ ] Service principals created (least-privilege)
- [ ] GitHub workflows created & passing
- [ ] Secret scanning enabled & tested

### Validation Completeness
- [ ] All terraform fmt checks pass
- [ ] All terraform validate checks pass
- [ ] OIDC end-to-end test passed
- [ ] RBAC least-privilege test passed
- [ ] State security validation passed
- [ ] Secret scanning test passed
- [ ] Drift detection test passed
- [ ] State enforcement test passed

### Sign-Off Completeness
- [ ] Security team review complete
- [ ] Infrastructure team review complete
- [ ] Compliance team sign-off
- [ ] Stakeholder approval

---

## Summary

| Phase | Component | Status | Effort Remaining | Blocker |
|-------|-----------|--------|-----------------|---------|
| Phase 0 | Bootstrap | ✅ 100% | 0h | None |
| Phase 0.1 | TFC Setup | ⏳ 0% | 2h | Manual (create TFC org) |
| Phase 1.1 | RBAC | ⏳ 0% | 8-15h | Needs Phase 0.1 |
| Phase 1.2 | State Docs | ⏳ 0% | 5-7h | Needs Phase 0.1 |
| Phase 1 SEC-1 | Secrets | ⏳ 0% | 4-5h | None (can start) |
| Workflows 200s-300s | Code | ⏳ 0% | 8-11h | Needs Phase 1.1 |
| Testing | Validation | ⏳ 0% | 8.5h | Needs all code |
| **TOTAL** | **All Items** | **~42% Done** | **~37-45h** | **TFC Setup** |

---

**Next Action**: User creates Terraform Cloud organization and configures GitHub secrets

