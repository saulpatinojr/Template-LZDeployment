<!-- Source: docs/EXC-PHASE1-KICKOFF.md -->
<!-- Last migrated: 2026-06-30 -->

# Phase 1: Prerequisites — KICKOFF

**Status**: 🚀 READY TO START  
**Kickoff Date**: 2026-07-01  
**Deadline**: 2026-07-07  
**Effort**: 8-12 hours  
**Owner**: Platform Team + Identity Team  

---

## 🎯 Phase 1 Mission

**Create the foundational Azure infrastructure and access control needed for deployment.**

After Phase 1 complete, you will have:
- ✅ 6 Azure subscriptions created and organized
- ✅ 3 Service Principals for CI/CD (with OIDC federation)
- ✅ 6 Entra security groups for user access
- ✅ All RBAC configured (least-privilege per role)
- ✅ GitHub Secrets configured (no long-lived credentials)
- ✅ Ready for Phase 2 (bootstrap workflows)

---

## 📋 Phase 1 Tasks Summary

### Task 1.1: Create Azure Subscriptions (3 hours)
**Reference**: [SUBSCRIPTIONS.md](docs/SUBSCRIPTIONS.md) - Section "Subscription Creation Checklist"

**What to do**:
1. Create 6 subscriptions (Hub, Identity, Mgmt, Security, Prod, Sandbox)
2. Move each to correct management group
3. Set monthly budgets + alerts
4. Assign billing account
5. Document subscription IDs

**Success Criteria**:
- [x] All 6 subscriptions exist in Azure
- [x] Each has a unique ID
- [x] Each is in correct management group
- [x] Budget alerts configured

---

### Task 1.2: Create Entra Security Groups (2 hours)
**Reference**: [RBAC-GROUPS.md](docs/RBAC-GROUPS.md) - Section "Group Creation Checklist"

**What to do**:
1. Create 7 Entra security groups:
   - `Azure-platform-admins` (platform engineers)
   - `Azure-platform-readers` (support staff)
   - `Azure-workload-admins` (workload leads)
   - `Azure-security-team` (security team)
   - `Azure-operations-team` (NOC/ops)
   - `Azure-sandbox-admins` (developers)
   - (Add more per workload as needed)

2. Add initial members (see RBAC-GROUPS.md for who)

3. Assign each group to correct Azure roles on subscriptions

**Success Criteria**:
- [x] All 7 groups created in Entra
- [x] Members added (initial team)
- [x] Role assignments created (Contributor, Reader, etc.)
- [x] Can verify with: `az role assignment list --assignee-object-id {GROUP_ID}`

---

### Task 1.3: Create Service Principals for CI/CD (2 hours)
**Reference**: [SERVICE-PRINCIPALS.md](docs/SERVICE-PRINCIPALS.md) - Section "Creation Checklist"

**What to do**:
1. Create 3 service principals (no passwords - OIDC only):
   - `sp-terraform-platform-prod` (deploy platform)
   - `sp-terraform-workload-prod` (deploy workload)
   - `sp-terraform-sandbox-nonprod` (dev/test)

2. Assign Contributor role to each (subscription-scoped, least privilege)

3. Create OIDC federated credentials (linking GitHub repo)

4. Document App IDs and SP IDs

**Success Criteria**:
- [x] 3 SPs created (no passwords)
- [x] OIDC federated credentials created
- [x] Correct RBAC role assignments per SP
- [x] Can verify with: `az ad sp list --output table`

---

### Task 1.4: Configure GitHub Secrets (1 hour)
**Reference**: [SERVICE-PRINCIPALS.md](docs/SERVICE-PRINCIPALS.md) - Section "GitHub Secrets Setup"

**What to do**:
1. Add GitHub repository secrets:
   - `AZURE_CLIENT_ID` (from sp-terraform-platform-prod)
   - `AZURE_TENANT_ID` (your Entra tenant ID)
   - `AZURE_SUBSCRIPTION_ID` (hub subscription ID)

2. Verify secrets are set (don't display values)

**Success Criteria**:
- [x] 3 secrets added to GitHub
- [x] No long-lived passwords stored anywhere
- [x] Can verify with: `gh secret list --repo owner/repo`

---

## 📚 Documentation References

### For Subscriptions
```
File: docs/SUBSCRIPTIONS.md
Read: Section "Subscription Creation Checklist"
Follow: Azure CLI commands step-by-step
Verify: All 6 subscriptions exist and are in correct MGs
```

### For RBAC Groups
```
File: docs/RBAC-GROUPS.md
Read: Section "Group Creation Checklist"
Follow: Group creation + member assignment steps
Verify: Role assignments with `az role assignment list`
```

### For Service Principals
```
File: docs/SERVICE-PRINCIPALS.md
Read: Section "Creation Checklist"
Follow: SP creation, OIDC federation setup
Verify: `az ad sp list` and `az ad app federated-credential list`
```

---

## 🏃 Day-by-Day Execution Plan

### Monday (2026-07-01)
**Task**: Create Subscriptions & Document IDs  
**Time**: 3 hours  
**Owner**: Platform Lead + Finance

**Steps**:
1. Create 6 subscriptions using Azure CLI/Portal
2. Move to correct management groups
3. Set monthly budgets
4. Document all subscription IDs in spreadsheet
5. Send IDs to team for next tasks

**Output**: 
- 6 subscriptions exist
- SUBSCRIPTIONS-INVENTORY.md populated with IDs

---

### Tuesday (2026-07-02)
**Task**: Create Entra Groups & Assign Members  
**Time**: 2 hours  
**Owner**: Identity Admin

**Steps**:
1. Create 7 security groups in Entra
2. Add initial members (get approval from managers first)
3. Document group IDs

**Output**:
- 7 Entra groups created
- Members assigned
- RBAC-GROUPS-INVENTORY.md populated with group IDs

---

### Wednesday (2026-07-03)
**Task**: Assign RBAC Roles to Groups  
**Time**: 2 hours  
**Owner**: Platform Lead

**Steps**:
1. For each group, assign correct role to correct subscription(s)
2. Use [RBAC-GROUPS.md](docs/RBAC-GROUPS.md) "Role Assignments" table
3. Verify all assignments created

**Output**:
- All role assignments created
- Verification: `az role assignment list --output table`

---

### Thursday (2026-07-04)
**Holiday** - Continue if needed, or shift to Friday

---

### Friday (2026-07-05)
**Task**: Create Service Principals & OIDC  
**Time**: 2 hours  
**Owner**: Platform Lead + Security

**Steps**:
1. Create 3 service principals
2. Create OIDC federated credentials per SP
3. Assign Contributor roles (subscription-scoped)
4. Document all App IDs

**Output**:
- 3 SPs created
- OIDC credentials configured
- SERVICE-PRINCIPALS-INVENTORY.md populated

---

### Saturday (2026-07-06)
**Task**: GitHub Secrets + Testing  
**Time**: 1-2 hours  
**Owner**: Platform Lead

**Steps**:
1. Add GitHub secrets (AZURE_CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID)
2. Create test workflow file (test-oidc.yml)
3. Run workflow manually to verify auth works
4. Verify no errors in logs

**Output**:
- GitHub secrets configured
- Test workflow passes
- Authentication verified

---

### Monday (2026-07-07)
**Task**: Final Verification & Sign-Off  
**Time**: 1 hour  
**Owner**: Platform Lead

**Steps**:
1. Checklist verification:
   - [ ] All 6 subscriptions exist
   - [ ] All 7 groups exist
   - [ ] All RBAC assignments created
   - [ ] All 3 SPs exist
   - [ ] All OIDC credentials configured
   - [ ] GitHub secrets added
   - [ ] Test workflow passes

2. Get sign-off from Platform Lead + Security Lead

**Output**:
- PHASE1-COMPLETE.md created
- Phase 2 unblocked

---

## 🚦 Success Metrics

### Subscriptions
```
✅ 6 subscriptions created
✅ Each in correct management group
✅ Budget alerts configured
✅ Monthly costs ~$4,100 baseline
```

### RBAC Groups
```
✅ 7 Entra security groups created
✅ ~15-20 users assigned to groups (initial)
✅ All role assignments created
✅ Roles follow least-privilege principle
```

### Service Principals
```
✅ 3 SPs created (no passwords)
✅ OIDC credentials configured
✅ Correct RBAC per SP
✅ Each SP scoped to correct subscriptions only
```

### GitHub Integration
```
✅ 3 GitHub secrets added
✅ Test workflow runs successfully
✅ OIDC authentication verified
✅ No long-lived credentials stored
```

---

## ⚠️ Common Pitfalls to Avoid

### Pitfall 1: Giving Everyone Owner Role
**❌ Wrong**: "Just give everyone Owner so they can deploy"  
**✅ Right**: Use Contributor + PIM for elevated access when needed

**Why**: Owner role is too broad, hard to audit, violates least-privilege

### Pitfall 2: Storing SP Passwords
**❌ Wrong**: Create SP password + store in GitHub Secrets  
**✅ Right**: Use OIDC (no password needed)

**Why**: Passwords can be stolen, OIDC tokens are short-lived (15 min)

### Pitfall 3: Single SP for Everything
**❌ Wrong**: One SP with Contributor on all subscriptions  
**✅ Right**: Separate SPs per layer (platform, workload, sandbox)

**Why**: If one SP is compromised, all resources are at risk

### Pitfall 4: Forgetting Resource Quotas
**❌ Wrong**: Create resources without checking subscription limits  
**✅ Right**: Review subscription limits before deploying

**Why**: Azure has limits (e.g., 10 virtual networks per subscription by default)

### Pitfall 5: No Audit Trail
**❌ Wrong**: Manual access changes, no documentation  
**✅ Right**: Use Entra groups + RBAC so audit trail is automatic

**Why**: Compliance requires proof of who had access when

---

## 📞 Getting Help

### If you're stuck on...

**Subscriptions**:
```
Reference: docs/SUBSCRIPTIONS.md (Section: Subscription Creation Checklist)
Or ask: Platform Lead (knows subscription structure)
```

**Entra Groups**:
```
Reference: docs/RBAC-GROUPS.md (Section: Group Creation Checklist)
Or ask: Identity Admin (knows Entra setup)
```

**Service Principals**:
```
Reference: docs/SERVICE-PRINCIPALS.md (Section: Creation Checklist)
Or ask: Security Team (knows OIDC setup)
```

**GitHub Integration**:
```
Reference: docs/SERVICE-PRINCIPALS.md (Section: GitHub Secrets Setup)
Or ask: DevOps Lead (knows GitHub configuration)
```

---

## 🎓 Key Learnings from Phase 1

### 1. Subscriptions are Boundaries
- Subscriptions group resources for billing/management
- You can have many subscriptions (no hard limit)
- Moving resources between subscriptions is hard → plan first

### 2. Least Privilege is Essential
- Give people/SPs only what they need
- Separate SPs per layer = containment
- Owner role is rarely needed (use PIM instead)

### 3. OIDC is Better Than Secrets
- No passwords to steal
- Tokens auto-rotate (GitHub handles it)
- Audit trail shows what/who/when (not just which SP)
- Matches industry best practices (AWS, GCP also use similar)

### 4. Entra Groups Enable Governance
- Centralized access management (change group = change all members' access)
- Easy onboarding (add to group = immediate access)
- Easy offboarding (remove from group = immediate revocation)
- Audit trail (who was in which group when)

---

## ✅ Phase 1 Completion Checklist

### Subscriptions
- [ ] 6 subscriptions created
- [ ] Each assigned to correct management group
- [ ] Budget alerts configured ($1,000-2,000 per platform sub)
- [ ] Billing owner assigned
- [ ] SUBSCRIPTIONS-INVENTORY.md populated

### RBAC Groups
- [ ] 7 Entra security groups created
- [ ] Members assigned (initial team)
- [ ] Role assignments created for each group
- [ ] RBAC-GROUPS-INVENTORY.md populated

### Service Principals
- [ ] 3 SPs created (sp-terraform-platform, -workload, -sandbox)
- [ ] OIDC federated credentials configured
- [ ] Correct RBAC roles assigned (scoped to subscriptions)
- [ ] SERVICE-PRINCIPALS-INVENTORY.md populated
- [ ] No passwords stored anywhere

### GitHub Integration
- [ ] GitHub secrets added (AZURE_CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID)
- [ ] Test workflow created (test-oidc.yml)
- [ ] Test workflow runs successfully
- [ ] OIDC authentication verified

### Documentation
- [ ] All inventories populated (subscriptions, groups, SPs)
- [ ] Issues/blockers documented
- [ ] Phase 2 ready (deployment-guide.md, architecture.md)

### Sign-Off
- [ ] Platform Lead approval: _____ (date)
- [ ] Identity Admin approval: _____ (date)
- [ ] Security Lead approval: _____ (date)

---

## 🚀 What's Next

**After Phase 1 Complete** → Phase 2 Kickoff

**Phase 2 Tasks**:
1. Verify Terraform + backend setup
2. Deploy platform layers via IaC (Layer 00-05)
3. Verify platform is operational

**Phase 2 Timeline**: 2026-07-08 to 2026-07-21

---

## 📊 Phase 1 Progress Tracking

### Daily Standup Template

```
Date: 2026-07-XX
Owner: [Name]

✅ Completed:
- [ ] Task name + result

🟡 In Progress:
- [ ] Task name + status

❌ Blocked:
- [ ] Task name + blocker

📋 Plan for Tomorrow:
- [ ] Next task
```

---

## 📝 Phase 1 Document History

| Date | Event | Owner |
|------|-------|-------|
| 2026-06-30 | Phase 0 Complete (docs ready) | Platform Team |
| 2026-07-01 | Phase 1 Kickoff | Platform Lead |
| 2026-07-07 | Phase 1 Sign-Off (target) | All Leads |

---

**Owner**: Platform Engineering Team  
**Kickoff Date**: 2026-07-01  
**Deadline**: 2026-07-07  
**Next Phase**: Phase 2 - Bootstrap (2026-07-08)

Ready? Let's build the foundation! 🚀


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

