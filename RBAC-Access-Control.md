<!-- Source: docs/SEC-RBAC-GROUPS.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure RBAC Groups & Access Control

**Document ID**: DOC-RBAC-GROUPS-001  
**Version**: 1.0  
**Status**: ✅ APPROVED  
**Last Updated**: 2026-06-30  
**Owner**: Identity + Platform Engineering  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Entra ID Group Strategy](#entra-id-group-strategy)
3. [Groups by Role & Layer](#groups-by-role--layer)
4. [Group Creation Checklist](#group-creation-checklist)
5. [Role Assignments](#role-assignments)
6. [PIM (Privileged Identity Management)](#pim-privileged-identity-management)
7. [Access Review Procedures](#access-review-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Overview

**Goal**: Enable secure, auditable access to Azure resources via Entra ID security groups.

**Strategy**:
- Create Entra security groups for each role/team
- Assign Azure roles (Contributor, Reader, Network Contributor) to groups
- Add users to groups (not direct role assignments)
- Use PIM for time-bound elevated access
- Regular access reviews to remove unused access

**Benefits**:
- ✅ Centralized access management (change group, not every role assignment)
- ✅ Audit trail (see who accessed what, via which group)
- ✅ Easy offboarding (remove user from group = immediate access revocation)
- ✅ Separation of duties (platform team ≠ workload team)
- ✅ Delegation (team lead can manage group membership)

---

## Entra ID Group Strategy

### Group Naming Convention

All Entra security groups follow this pattern:

```
Azure-{role}-{layer}-{environment}

Examples:
  Azure-platform-admins-prod          (Platform engineers)
  Azure-platform-readers-prod         (Support staff - read-only)
  Azure-workload-admins-prod          (Workload team leads)
  Azure-workload-owners-prod          (Individual workload owners)
  Azure-security-team-prod            (Security engineers)
  Azure-operations-team-prod          (NOC / Operations)
  Azure-sandbox-admins-nonprod        (Developers)
```

### Group Owner & Membership

Each group should have:
- **Owner**: Entra admin or platform lead (controls membership)
- **Members**: Users who need access
- **Governance**: Quarterly access reviews

---

## Groups by Role & Layer

### Platform Groups (Platform Services)

#### Azure-platform-admins

**Purpose**: Deploy and manage platform infrastructure

**Details**:
```
Name:              Azure-platform-admins
Display Name:      Platform Admins (Prod)
Environment:       Production
Description:       Engineers who manage hub, identity, management, security
Group Type:        Security
Membership Type:   Dynamic (AD group based on department) or Manual
Owner:             Platform Lead
```

**Permissions**:
```
✅ Contributor on: sub-platform-hub-prod
✅ Contributor on: sub-platform-identity-prod
✅ Contributor on: sub-platform-management-prod
✅ Contributor on: sub-platform-security-prod
❌ Contributor on: Workload/Sandbox subscriptions
```

**Typical Members**:
- Platform engineering team (4-6 engineers)
- Network architects
- Security engineers (for platform security tasks)

**Access Grant Process**:
1. New hire requests access via Jira ticket
2. Manager approves
3. Platform lead adds to group
4. Access verified within 24 hours

---

#### Azure-platform-readers

**Purpose**: View platform infrastructure without modify permissions

**Details**:
```
Name:              Azure-platform-readers
Display Name:      Platform Readers (Prod)
Environment:       Production
Description:       Support and NOC staff who monitor platform (read-only)
Group Type:        Security
Membership Type:   Manual
Owner:             Platform Lead
```

**Permissions**:
```
✅ Reader on: All platform subscriptions
✅ Reader on: All workload subscriptions (visibility)
❌ Contributor on: Any subscription
❌ Modify on: Anything
```

**Typical Members**:
- NOC/Operations support (2-3 staff)
- Compliance/audit staff
- Help desk (for basic troubleshooting)

**Use Case**: "My app is down, I need to check if platform is OK"

---

### Workload Groups (Business Applications)

#### Azure-workload-admins

**Purpose**: Deploy and manage workload subscriptions (all apps)

**Details**:
```
Name:              Azure-workload-admins
Display Name:      Workload Admins (Prod)
Environment:       Production
Description:       Leads of application teams who deploy/manage their workloads
Group Type:        Security
Membership Type:   Manual
Owner:             Platform Lead
```

**Permissions**:
```
✅ Contributor on: sub-workload-payroll-prod (first app)
✅ Contributor on: sub-workload-{future-apps}-prod (as added)
❌ Contributor on: Platform subscriptions
❌ Can see platform resources
```

**Typical Members**:
- Payroll app team lead
- (HR app team lead, when added)
- (CRM app team lead, when added)

**Access Grant Process**:
1. Business owner requests new workload subscription
2. Finance approves budget
3. Platform creates new subscription
4. Platform creates `Azure-workload-{app}-admins` group
5. Business owner assigns team members

---

#### Azure-workload-owners-{app}

**Purpose**: Manage SPECIFIC workload (more fine-grained than admins)

**Details**:
```
Name:              Azure-workload-owners-payroll
Display Name:      Payroll Workload Owners (Prod)
Environment:       Production
Description:       Payroll application owners who manage payroll resources
Group Type:        Security
Membership Type:   Manual
Owner:             Payroll Team Lead
```

**Permissions**:
```
✅ Contributor on: sub-workload-payroll-prod (only)
✅ Limited scope via Resource Group (optional)
❌ Contributor on: Other workload subscriptions
❌ Contributor on: Platform subscriptions
```

**Typical Members**:
- Payroll app owners (3-5 developers)
- Payroll DevOps engineers
- Payroll technical lead

**Why Separate from Admins?**
- Workload admins: Cross-app oversight, billing, policies
- Workload owners: Day-to-day development/operations

---

### Security & Operations Groups

#### Azure-security-team

**Purpose**: Manage security infrastructure (Sentinel, Defender, policies)

**Details**:
```
Name:              Azure-security-team
Display Name:      Security Team (Prod)
Environment:       Production
Description:       Security engineers managing SIEM, threat detection
Group Type:        Security
Membership Type:   Manual
Owner:             CISO or Security Lead
```

**Permissions**:
```
✅ Contributor on: sub-platform-security-prod
✅ Reader on: All other subscriptions (audit trail)
```

**Typical Members**:
- SOC engineers (Security Operations Center)
- Security architects
- Incident response team

---

#### Azure-operations-team

**Purpose**: Monitor and support all infrastructure

**Details**:
```
Name:              Azure-operations-team
Display Name:      Operations Team (Prod)
Environment:       Production
Description:       NOC and site reliability engineers
Group Type:        Security
Membership Type:   Manual
Owner:             Operations Manager
```

**Permissions**:
```
✅ Reader on: All subscriptions (visibility)
✅ Network Contributor on: Platform subscriptions (network troubleshooting)
✅ Log Analytics Reader on: Management subscription (logs)
❌ Contributor on: Any subscription
```

**Typical Members**:
- NOC staff (2-3)
- SRE team (Site Reliability Engineers)
- Support engineers

---

### Development Groups

#### Azure-sandbox-admins

**Purpose**: Allow developers to experiment in sandbox

**Details**:
```
Name:              Azure-sandbox-admins
Display Name:      Sandbox Admins (NonProd)
Environment:       NonProduction (Sandbox)
Description:       Developers and engineers testing infrastructure patterns
Group Type:        Security
Membership Type:   Dynamic (all engineers) or Manual
Owner:             Engineering Manager
```

**Permissions**:
```
✅ Contributor on: sub-sandbox-nonprod
❌ Contributor on: Platform subscriptions
❌ Contributor on: Workload subscriptions
```

**Typical Members**:
- All engineers (self-service access)
- DevOps engineers
- Infrastructure team

**Why Open?**
- Low risk (dev/test only)
- Auto-cleanup enabled (no resource accumulation)
- Encourages experimentation
- No approval needed

---

## Group Creation Checklist

### Prerequisites

- [ ] You have **Entra ID Application Administrator** role (or Global Administrator)
- [ ] You have approved group membership (see Group Strategy above)
- [ ] Teams know who should be added

### Step 1: Create Entra Security Group

```bash
# Create security group in Entra
az ad group create \
  --display-name "Azure-platform-admins" \
  --mail-nickname "azure-platform-admins" \
  --description "Engineers who manage platform infrastructure (prod)"

# Record the group object ID
export GROUP_ID=$(az ad group show --group "azure-platform-admins" --query id -o tsv)
```

**Repeat for each group** (see list below):
1. `Azure-platform-admins`
2. `Azure-platform-readers`
3. `Azure-workload-admins`
4. `Azure-workload-owners-{app}` (per app)
5. `Azure-security-team`
6. `Azure-operations-team`
7. `Azure-sandbox-admins`

### Step 2: Add Members to Group

```bash
# Get user object ID
export USER_ID=$(az ad user show --id saul@acme.com --query id -o tsv)

# Add user to group
az ad group member add \
  --group "azure-platform-admins" \
  --member-id $USER_ID

# Verify member was added
az ad group member list --group "azure-platform-admins" --output table
```

### Step 3: Assign Group to Azure Role

```bash
# Get subscription ID
export SUB_ID=$(az account show --query id -o tsv)

# Assign Contributor role to group on subscription
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $GROUP_ID \
  --scope "/subscriptions/$SUB_ID"

# Verify role assignment
az role assignment list --assignee-object-id $GROUP_ID --output table
```

### Step 4: Document Group in Inventory

Create entry in `RBAC-GROUPS-INVENTORY.md`:

```markdown
| Group Name | Display Name | Role | Scope | Members | Owner | Status |
|------------|--------------|------|-------|---------|-------|--------|
| azure-platform-admins | Platform Admins (Prod) | Contributor | 4 platform subs | 5 | Platform Lead | ✅ Active |
```

---

## Role Assignments

### Assignment Matrix

Use this table to determine which role to assign to which group:

| Group | Subscription | Role | Scope | Reason |
|-------|--------------|------|-------|--------|
| **Platform Admins** | | | | |
| | hub | Contributor | Subscription | Deploy networking |
| | identity | Contributor | Subscription | Deploy identity services |
| | management | Contributor | Subscription | Deploy monitoring |
| | security | Contributor | Subscription | Deploy security tooling |
| **Platform Readers** | | | | |
| | all (4 platform) | Reader | Subscription | Monitor platform health |
| | all (workloads) | Reader | Subscription | Support troubleshooting |
| **Workload Admins** | | | | |
| | payroll-prod | Contributor | Subscription | Deploy payroll app |
| **Security Team** | | | | |
| | security | Contributor | Subscription | Manage Sentinel/Defender |
| | all (4 platform) | Reader | Subscription | Audit trail |
| **Operations Team** | | | | |
| | all (6 total) | Reader | Subscription | Monitor all systems |
| | hub | Network Contributor | Subscription | Troubleshoot networking |
| **Sandbox Admins** | | | | |
| | sandbox | Contributor | Subscription | Dev/test experimentation |

### Example: Assign Platform Admins to Hub Subscription

```bash
# Get group ID
export GROUP_ID=$(az ad group show --group "azure-platform-admins" --query id -o tsv)

# Get hub subscription ID
export HUB_SUB=$(az account list --query "[?name=='sub-acme-platform-hub-prod'].id" -o tsv)

# Assign Contributor role
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $GROUP_ID \
  --scope "/subscriptions/$HUB_SUB"

# Verify
az role assignment list --assignee-object-id $GROUP_ID --scope "/subscriptions/$HUB_SUB"
```

---

## PIM (Privileged Identity Management)

### What is PIM?

PIM allows users to request temporary elevated access (e.g., "I need Owner for 2 hours to troubleshoot this issue").

**Without PIM**: Owner role is permanent (risky)  
**With PIM**: Owner role is temporary and requires approval (safer)

### PIM Levels

```
Level 1: Reader (always active, no approval needed)
Level 2: Contributor (always active, no approval needed)
Level 3: Network Contributor (always active, no approval needed)
Level 4: Owner (requires approval, time-limited)
```

### Enable PIM for Critical Roles

```bash
# Enable PIM for Owner role on platform subscriptions
# This is a GUI operation in Azure Portal:
# 1. Go to Azure AD → Privileged Identity Management
# 2. Select "Azure Resources"
# 3. Select each subscription
# 4. For Owner role: set "Require approval"

# Or via CLI (if supported):
az rest --method POST \
  --uri "/subscriptions/{subId}/providers/Microsoft.Authorization/policyAssignments" \
  --body @- <<EOF
{
  "properties": {
    "displayName": "Require PIM for Owner",
    "policyDefinitionId": "/subscriptions/.../policyDefinitions/require-pim-owner"
  }
}
EOF
```

### Request Elevated Access via PIM

**User Experience**:
1. User logs into Azure Portal
2. Goes to Privileged Identity Management
3. Requests Owner role for 2 hours on a subscription
4. Approval is sent to platform lead
5. If approved, role is activated for 2 hours
6. After 2 hours, access automatically revoked

---

## Access Review Procedures

### Quarterly Access Review

**Schedule**: Every 90 days  
**Owner**: Platform Lead  
**Duration**: 1-2 hours per review

**Process**:
1. Generate list of all users in all groups
2. For each user: Verify they should still have access
3. If they've left/changed roles: Remove from group
4. Document review completion

**Example Review Template**:
```bash
# Generate access report
az ad group member list --group "azure-platform-admins" --output table

# For each member:
# [ ] Verify user still works at company
# [ ] Verify user still needs this access
# [ ] Verify manager approves continued access
# [ ] If not approved: Remove

az ad group member remove --group "azure-platform-admins" --member-id $USER_ID
```

### Offboarding Checklist

When an employee leaves:

**Immediate** (same day):
- [ ] Remove from all Entra groups
- [ ] Disable user account (don't delete yet)
- [ ] Rotate any secrets they had access to

**Within 24 hours**:
- [ ] Verify access is revoked in all subscriptions
- [ ] Audit recent actions (what did they access?)
- [ ] Export any resources they owned for transfer

**After 30 days**:
- [ ] Delete user account (if no recovery needed)
- [ ] Remove from shared mailboxes
- [ ] Archive email (compliance)

**Example Offboarding Script**:
```bash
# Remove user from all groups
for group in "azure-platform-admins" "azure-workload-admins" "azure-sandbox-admins"; do
  az ad group member remove --group "$group" --member-id $USER_ID || true
done

# Disable user (don't delete yet)
az ad user update --id $USER_ID --account-enabled false

# Verify no role assignments remain
az role assignment list --assignee $USER_ID
```

---

## Troubleshooting

### Issue: "User cannot see resources even after group assignment"

**Cause**: Role assignment takes 5-10 minutes to propagate in Azure

**Fix**:
```bash
# 1. Wait 10 minutes
# 2. User logs out and back in
# 3. Clear browser cache
# 4. Verify role assignment exists:
az role assignment list --assignee-object-id $GROUP_ID

# 5. If still not working, user may need to change subscription:
#    Azure Portal → Subscriptions → Select correct subscription
```

### Issue: "Cannot assign role to group"

**Cause**: Group object ID is wrong, or user doesn't have permission

**Fix**:
```bash
# Verify group exists and get correct ID
az ad group show --group "azure-platform-admins" --query id -o tsv

# Verify you have permission to assign roles
az role assignment list --assignee-object-id $(az ad signed-in-user show --query id -o tsv)

# Try assignment again with correct group ID
az role assignment create \
  --role "Contributor" \
  --assignee-object-id {CORRECT_GROUP_ID} \
  --scope "/subscriptions/{SUB_ID}"
```

### Issue: "User is in group but access revoked"

**Cause**: Role assignment was deleted or subscription moved

**Fix**:
```bash
# Check current role assignments for user's groups
for group in $(az ad user get-memberObjects --id $USER_ID); do
  az role assignment list --assignee-object-id $group
done

# Re-create assignment if needed
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $GROUP_ID \
  --scope "/subscriptions/$SUB_ID"
```

---

## RBAC Groups Inventory

**File**: `docs/RBAC-GROUPS-INVENTORY.md` (to be populated)

```markdown
| Group Name | Role | Subscriptions | Members | Owner | Status |
|------------|------|---------------|---------|-------|--------|
| Azure-platform-admins | Contributor | Hub, Identity, Mgmt, Security | TBD | Platform Lead | TODO |
| Azure-platform-readers | Reader | All (4 platform) | TBD | Platform Lead | TODO |
| Azure-workload-admins | Contributor | Payroll-prod | TBD | Workload Lead | TODO |
| Azure-security-team | Contributor | Security | TBD | Security Lead | TODO |
| Azure-operations-team | Reader | All (6 total) | TBD | Ops Manager | TODO |
| Azure-sandbox-admins | Contributor | Sandbox | TBD | Eng Manager | TODO |
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial RBAC strategy |

---

## Related Documents

- [SERVICE-PRINCIPALS.md](SERVICE-PRINCIPALS.md) - CI/CD authentication (separate from user access)
- [SUBSCRIPTIONS.md](SUBSCRIPTIONS.md) - Subscription structure
- [TAGGING-STRATEGY.md](TAGGING-STRATEGY.md) - Tags for access control
- [TODO.md](../TODO.md) - Phase 1.2 task details

---

**Questions?** Contact Identity + Platform Engineering Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

