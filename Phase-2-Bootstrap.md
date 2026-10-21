<!-- Source: docs/EXC-PHASE2-KICKOFF.md -->
<!-- Last migrated: 2026-06-30 -->

# Phase 2: Bootstrap & Deployment — KICKOFF

**Status**: 🚀 READY TO START  
**Kickoff Date**: 2026-07-08  
**Deadline**: 2026-07-21  
**Duration**: 2 weeks  
**Effort**: 20-30 hours  
**Owner**: Platform Team

---

## 🎯 Phase 2 Mission

**Deploy the Azure Landing Zone platform infrastructure via Terraform + GitHub Actions.**

After Phase 2 complete, you will have:
- ✅ Hub-spoke network topology deployed
- ✅ Azure Firewall operational
- ✅ Centralized logging configured
- ✅ Security policies enforced
- ✅ Fully operational platform ready for workloads
- ✅ Zero manual infrastructure (all IaC)

---

## 📊 What Gets Deployed

### 6 Terraform Layers (in order)

```
Layer 00: Management Groups & Policies (10-15 min)
  └─ Create hierarchy, assign subscriptions, deploy policies

Layer 01: Platform Identity (5-10 min)
  └─ Create identity vnet, key vault, optional domain controllers

Layer 02: Hub Networking (15-30 min) ⭐ CRITICAL PATH
  └─ Create hub vnet, firewall, subnets, NSGs

Layer 03: Platform Management (5-10 min)
  └─ Create Log Analytics, storage, alerts

Layer 04: Platform Security (10-15 min)
  └─ Create Key Vault, Sentinel (optional)

Layer 05: Sandbox Landing Zone (10-15 min)
  └─ Create sandbox vnet, peering to hub

TOTAL TIME: 55 minutes - 1.5 hours (can run in parallel)
```

---

## 📋 Pre-Deployment Checklist

### Prerequisites (All should be ✅ from Phase 1)

- [ ] Phase 1 Complete (subscriptions, RBAC, SPs created)
- [ ] 6 subscriptions exist in Azure
- [ ] 7 Entra groups created + members added
- [ ] 3 service principals created with OIDC
- [ ] GitHub secrets configured (AZURE_CLIENT_ID, etc.)
- [ ] Terraform Cloud workspace ready
- [ ] GitHub branch protection enabled on main
- [ ] Test workflow passed (OIDC auth verified)

### Code Prerequisites

- [ ] TODO.md reviewed and understood
- [ ] DEPLOYMENT-GUIDE.md read
- [ ] ARCHITECTURE.md reviewed (understand topology)
- [ ] Terraform code in terraform/layers/ directory
- [ ] All variables.tf files configured with your org values
- [ ] backend.hcl configured with TFC workspace names

### Team Readiness

- [ ] Platform team briefed on deployment plan
- [ ] Schedule 2-hour deployment window (no on-call hours)
- [ ] Internet connection stable
- [ ] All team members online + available
- [ ] Rollback procedures understood

---

## 🚀 Deployment Plan

### Day 1 (2026-07-08): Layer 00 Deployment

**Mission**: Create management group hierarchy + assign subscriptions

**What to Deploy**:
```
terraform/layers/00-management-groups/
```

**Steps**:
1. Read: DEPLOYMENT-GUIDE.md (Layer 00 section)
2. Update: variables.tf with your subscription IDs
3. Run: terraform init → validate → plan → apply
4. Verify: Management groups exist in Azure Portal
5. Verify: All subscriptions in correct MGs

**Expected Duration**: 15 minutes
**Success Criteria**:
- [ ] All 6 MGs created
- [ ] All 6 subscriptions assigned to correct MGs
- [ ] Policies deployed and active

---

### Day 2-3 (2026-07-09 to 07-10): Layers 01-03 Deployment (Parallel)

**Mission**: Deploy identity, hub networking, and management

**Can Deploy in Parallel** (no dependencies on each other):
```
Layer 01: Platform Identity ────┐
Layer 02: Hub Networking ────────┤─→ (run simultaneously)
Layer 03: Platform Management ──┘
```

**Layer 01 Steps**:
```
terraform/layers/01-platform-identity/
1. Update: variables.tf
2. Run: terraform init → validate → plan → apply
3. Verify: vnet, NSG, key vault created
Duration: 10 min
```

**Layer 02 Steps** (CRITICAL PATH - watch closely):
```
terraform/layers/02-platform-hub-networking/
1. Update: variables.tf (vnet CIDR, firewall SKU, etc.)
2. Run: terraform init → validate → plan → apply
3. Verify: Hub vnet, subnets, firewall, NSGs created
Duration: 30 min (firewall provisioning takes time)

WARNING: This is the most important layer!
- Hub firewall controls all egress traffic
- Central networking point for entire platform
- Test thoroughly after deployment
```

**Layer 03 Steps**:
```
terraform/layers/03-platform-management/
1. Update: variables.tf
2. Run: terraform init → validate → plan → apply
3. Verify: Log Analytics, storage, action groups created
Duration: 10 min

Important: This layer configures centralized logging
- All platform resources' logs flow here
- MUST work for monitoring to function
```

**Expected Duration**: 30-40 minutes (parallel execution)

---

### Day 4 (2026-07-11): Layer 04 Deployment

**Mission**: Deploy security infrastructure (Key Vault, Sentinel)

```
terraform/layers/04-platform-security/
1. Update: variables.tf
   ├─ Set: create_sentinel = true (or false to save money)
   └─ Note: Sentinel costs $300-1,000/month if enabled
2. Run: terraform init → validate → plan → apply
3. Verify: Key Vault created, Sentinel (if enabled)
Duration: 15 min (or 30 min if Sentinel)
```

**Decision Point**: Enable Sentinel?
- YES: Full SIEM, threat detection, incident automation ($300-1,000/mo)
- NO: Skip Sentinel, save money, can enable later (recommended for Phase 1)

For Phase 2, recommended: **NO** (cost-conscious approach)
Can enable later when you have workloads to monitor.

---

### Day 5 (2026-07-15): Layer 05 Deployment

**Mission**: Deploy sandbox for developers

```
terraform/layers/05-workload-sandbox/
1. Update: variables.tf
2. Run: terraform init → validate → plan → apply
3. Verify: Sandbox vnet, peering to hub, subnets created
Duration: 15 min
```

**Why Sandbox First?**
- Lowest risk (dev/test only)
- Developers can start experimenting immediately
- Test networking, peering, firewall rules before prod workloads

---

### Day 6-7 (2026-07-16 to 07-17): Validation & Testing

**Mission**: Verify entire platform works end-to-end

**Testing Checklist**:
- [ ] Hub vnet accessible from sandbox vnet (peering works)
- [ ] Firewall routing working (traffic flows through fw)
- [ ] Logging working (logs in Log Analytics)
- [ ] Alerts configured (test alert delivery)
- [ ] RBAC working (team members can access correct subs)
- [ ] CI/CD working (test Terraform workflow)
- [ ] Tag compliance (all resources have mandatory tags)

**Test Procedures**:
```bash
# Test 1: Firewall routing
# Deploy test VM in sandbox
# SSH to VM
# curl https://example.com
# Should succeed if firewall allows

# Test 2: Logging
# Check Log Analytics for resource creation events
# Should see all deployed resources

# Test 3: RBAC
# Switch to different user
# Try to access each subscription
# Should match RBAC policy

# Test 4: Tags
# List all resources with tags
# Verify all have 6 mandatory tags
```

**Expected Duration**: 2-4 hours

---

## 📚 Documentation References

### By Task

| Task | Document | Section |
|------|----------|---------|
| Understand deployment approach | DEPLOYMENT-GUIDE.md | "Deployment Architecture" |
| Deploy Layer 00 | DEPLOYMENT-GUIDE.md | "Layer 00: Management Groups" |
| Deploy Layer 01 | DEPLOYMENT-GUIDE.md | "Layer 01: Platform Identity" |
| Deploy Layer 02 | DEPLOYMENT-GUIDE.md | "Layer 02: Hub Networking" |
| Deploy Layer 03 | DEPLOYMENT-GUIDE.md | "Layer 03: Platform Management" |
| Deploy Layer 04 | DEPLOYMENT-GUIDE.md | "Layer 04: Platform Security" |
| Deploy Layer 05 | DEPLOYMENT-GUIDE.md | "Layer 05: Sandbox Landing Zone" |
| Understand architecture | ARCHITECTURE.md | All sections |
| Troubleshoot issues | DEPLOYMENT-GUIDE.md | "Troubleshooting" |

---

## ⚠️ Common Pitfalls

### Pitfall 1: Skipping Terraform Plan Review
❌ Wrong: Run terraform apply without reviewing plan
✅ Right: Always read plan output, verify it matches intent

**Why**: Plan shows exactly what will change. Easy to catch errors before apply.

### Pitfall 2: Not Backing Up State
❌ Wrong: Rely only on Terraform Cloud
✅ Right: `terraform state pull > backup.tfstate` before deploying

**Why**: If TFC has issues, you have a backup.

### Pitfall 3: Deploying During On-Call Hours
❌ Wrong: Deploy 11 PM (when on-call is sleeping)
✅ Right: Deploy 9 AM (when team is available)

**Why**: If something breaks, you need the team immediately.

### Pitfall 4: Ignoring Firewall Costs
❌ Wrong: Assume firewall is "included"
✅ Right: Factor in $200-500/month for firewall

**Why**: Firewall is ~$200/month + traffic costs. Budget accordingly.

### Pitfall 5: Not Documenting Decisions
❌ Wrong: Deploy without recording why certain choices made
✅ Right: Document in commit messages or wiki

**Why**: 6 months later, you'll forget why hub is 10.0.0.0/16, not 10.1.0.0/16.

---

## 🚦 Phase 2 Execution Timeline

```
Mon 7/08:  Layer 00 (MGs) deployed ✅
Tue 7/09:  Layers 01, 02, 03 (Identity, Hub, Mgmt) deployed ✅
Wed 7/10:  (parallel deployment from previous day)
Thu 7/11:  Layer 04 (Security) deployed ✅
Mon 7/15:  Layer 05 (Sandbox) deployed ✅
Tue 7/16:  Validation & testing ✅
Wed 7/17:  Sign-off & documentation ✅

DEPLOYMENT WINDOW: 9 AM - 2 PM (5 hours on Day 1)
VALIDATION WINDOW: 9 AM - 1 PM (4 hours on validation days)
```

---

## 📊 Success Metrics

### Per Layer

```
Layer 00: ✅ All 6 MGs created, subscriptions assigned, policies deployed
Layer 01: ✅ vnet created, NSG created, key vault accessible
Layer 02: ✅ Hub vnet created, firewall operational, peering ready
Layer 03: ✅ Log Analytics working, logs flowing, alerts configured
Layer 04: ✅ Key vault created, Sentinel deployed (if enabled)
Layer 05: ✅ Sandbox vnet created, peered to hub, ready for dev use
```

### Overall

```
[ ] All 6 Terraform layers deployed successfully
[ ] All resources have correct names (per NAMING-CONVENTION.md)
[ ] All resources have mandatory tags
[ ] Hub firewall operational and routing traffic
[ ] Logging flowing to Log Analytics
[ ] Sandbox accessible from Internet (via firewall)
[ ] Team can access correct subscriptions (RBAC working)
[ ] No manual resources (all IaC via Terraform)
[ ] Disaster recovery procedures tested
[ ] Cost tracking working (tags enabling chargeback)
[ ] Platform ready for first workload deployment
```

---

## 🚨 Rollback Plan (If Something Goes Wrong)

### Option A: Destroy & Redeploy (Nuclear)
```bash
cd terraform/layers/{layer}/
terraform destroy -auto-approve

# This deletes all resources in that layer
# WARNING: Data loss if not careful!
# Then redeploy with fixes
```

### Option B: Revert Code (Safer)
```bash
# In Git
git revert <commit-that-broke-things>

# This creates a new commit undoing changes
# GitHub Actions automatically runs terraform apply
# This removes bad resources, restores good state
```

### Option C: Manual Cleanup
```bash
# Delete individual resources via Azure Portal
# Then run terraform apply to correct state
```

**Recommendation**: Use Option B (revert code) - safest and most auditable.

---

## ✅ Phase 2 Completion Checklist

### Deployment
- [ ] Layer 00 deployed ✅
- [ ] Layer 01 deployed ✅
- [ ] Layer 02 deployed ✅
- [ ] Layer 03 deployed ✅
- [ ] Layer 04 deployed ✅
- [ ] Layer 05 deployed ✅

### Verification
- [ ] All resources in Azure Portal
- [ ] Naming follows NAMING-CONVENTION.md
- [ ] Tags present on all resources
- [ ] Firewall routing working
- [ ] Logging working
- [ ] RBAC working
- [ ] No manual resources

### Documentation
- [ ] Actual resource IDs documented
- [ ] Deployment notes recorded
- [ ] Issues resolved documented
- [ ] Next steps (Phase 3) planned

### Sign-Off
- [ ] Platform Lead approval
- [ ] Security Lead approval
- [ ] Finance approval (cost tracking working)

---

## 🎓 Key Learnings for Phase 2

### 1. Terraform Plan is Your Friend
- Always review plan before apply
- It shows exactly what will change
- Easy to catch mistakes

### 2. Layered Deployment Works Well
- Deploy in order (dependencies matter)
- Can parallelize independent layers
- Clear success criteria per layer

### 3. Firewall is Critical
- Hub firewall is central point of trust
- All egress traffic flows through it
- Test thoroughly after deployment

### 4. Logging is Essential
- Every action audited via Log Analytics
- Enables troubleshooting, compliance
- Must be working before prod workloads

### 5. IaC > Manual Everything
- Terraform makes everything repeatable
- Disaster recovery is just terraform apply
- Changes have full audit trail

---

## 📞 Getting Help

**If you're stuck on**:

**Terraform errors** → DEPLOYMENT-GUIDE.md (Troubleshooting section)
**Architecture questions** → ARCHITECTURE.md (all sections)
**Naming issues** → NAMING-CONVENTION.md
**RBAC problems** → RBAC-GROUPS.md

**People to ask**:
- Platform Lead: General questions, deployment strategy
- Network Team: Hub networking specifics (Layer 02)
- Security Team: Firewall + Sentinel (Layer 04)
- Ops Team: Logging + monitoring (Layer 03)

---

## 📝 Phase 2 Progress Template

```
=== DAILY STANDUP TEMPLATE ===
Date: 2026-07-XX
Owner: [Name]

✅ Completed:
- [ ] Layer 0X deployed, resources verified

🟡 In Progress:
- [ ] Layer 0Y deployment (50% complete)

❌ Blocked:
- [ ] Layer 0Z (reason: explanation)

📋 Plan for Tomorrow:
- [ ] Next layer

NOTES:
- Any issues discovered
- Workarounds applied
- Decisions made
```

---

## 🚀 Next Phase

**After Phase 2 Complete** → Phase 3 Starts

**Phase 3: Run & Optimize**
- Deploy first workload (payroll app)
- Test end-to-end traffic flow
- Optimize costs
- Document operational procedures

**Timeline**: 2026-07-22+

---

## ✅ Ready?

**All prerequisites met?** → YES  
**Team ready?** → YES  
**Let's build!** → 🚀

---

**Owner**: Platform Engineering Team  
**Phase 2 Kickoff**: 2026-07-08  
**Phase 2 Deadline**: 2026-07-21  
**Next Phase**: Phase 3 - Run (2026-07-22+)


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

