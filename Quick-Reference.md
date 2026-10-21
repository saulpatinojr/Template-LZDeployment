<!-- Quick Reference Card -->

# Quick Reference Guide

One-page cheat sheet for the Azure Landing Zone deployment.

---

## 📋 The 4 Phases at a Glance

| Phase | Focus | Timeline | Status | Start Here |
|-------|-------|----------|--------|------------|
| **0** | Planning | 1 week | ✅ Done | [Phase Roadmap](Phase-Roadmap) |
| **1** | Prerequisites | 1 week | 🟡 Ready (Jul 1) | [Phase 1](Phase-1-Prerequisites) |
| **2** | Bootstrap | 2 weeks | ⚪ Blocked | [Phase 2](Phase-2-Bootstrap) |
| **3** | Deployment | 2+ weeks | ⚪ Blocked | [Deployment Guide](Deployment-Guide) |

---

## 🏗️ Architecture at a Glance

```
                    Azure Tenant
                        │
        ┌───────────────┼───────────────┐
        │               │               │
    MANAGEMENT     CONNECTIVITY      WORKLOAD
    Subscription   Subscription    Subscriptions
        │               │               │
     └─ Log Analytics   └─ Hub VNet    └─ Spoke VNets
     └─ KeyVault           └─ Firewall    └─ App Resources
                           └─ VPN         └─ Data Resources

Management Groups: Root → Platform → Workload → Sandbox
```

**Read more:** [Architecture](Architecture) | [Subscriptions Layout](Subscriptions-Layout)

---

## 📝 Resource Naming Pattern

```
{TYPE}-{WORKLOAD}-{ENVIRONMENT}-{REGION}-{INSTANCE}

Examples:
  vnet-hub-prod-eastus-01      (Virtual Network - Hub)
  rg-spoke-prod-eastus-01      (Resource Group - Spoke)
  fw-hub-prod-eastus-01        (Firewall)
  nsg-app-prod-eastus-01       (Network Security Group)
  st{org}prod{region}{id}      (Storage Account - no hyphens)
```

**Reference:** [Naming Convention](Naming-Convention)

---

## 🏷️ Required Tags (6 Mandatory)

| Tag | Example | Purpose |
|-----|---------|---------|
| `Environment` | prod, nonprod | Cost allocation, policy scoping |
| `Application` | platform, app-name | Resource ownership, grouping |
| `Owner` | team@org.com | Escalation contact |
| `CostCenter` | CC-1234 | Chargeback |
| `CreatedDate` | 2026-06-30 | Audit trail |
| `Terraform` | true | IaC tracking |

**Reference:** [Tagging Strategy](Tagging-Strategy)

---

## 👥 RBAC Groups (7 Total)

| Group | Roles | Purpose |
|-------|-------|---------|
| `Azure-platform-admins` | Owner (Hub/Connectivity) | Platform ops |
| `Azure-platform-readers` | Reader (all platform) | Visibility |
| `Azure-workload-admins` | Owner (Workload subs) | Workload deployment |
| `Azure-workload-owners-{app}` | Contributor | App-specific access |
| `Azure-security-team` | Reader + Policy Contributor | Compliance |
| `Azure-operations-team` | Operator roles | Day-2 ops |
| `Azure-sandbox-admins` | Owner (Sandbox sub) | Dev/test access |

**Reference:** [RBAC & Access Control](RBAC-Access-Control)

---

## 🔑 Service Principals (3-Tier)

```
sp-terraform-platform-prod      Deploys: Hub, Management
                ↓ (OIDC federated)
sp-terraform-workload-prod      Deploys: Spoke networks, policies
                ↓ (OIDC federated)
sp-terraform-sandbox-nonprod    Deploys: Sandbox dev/test
```

**Key:** All use OIDC federation. **Zero passwords stored.**  
**Reference:** [Service Principals](Service-Principals) | [OIDC Best Practices](OIDC-Best-Practices)

---

## 🚀 Phase 1 Tasks (11 Hours Total)

| Task | Effort | Dependencies | Deliverable |
|------|--------|--------------|-------------|
| 1. Create 6 subscriptions | 2 hrs | Azure account | Subscriptions ready, tagged |
| 2. Create 7 Entra groups | 1.5 hrs | Entra admin | RBAC groups + members |
| 3. Create 3 service principals + OIDC | 4 hrs | Entra + GitHub | GitHub secrets set |
| 4. Terraform setup + backend | 3.5 hrs | TF Cloud account | State backend ready |

**Start:** [Phase 1 Prerequisites](Phase-1-Prerequisites)

---

## 🔗 Terraform Layers (Phase 3)

| Layer | Deploys | Dependencies |
|-------|---------|--------------|
| **00** | Management Groups | Azure tenant |
| **01** | Entra roles + policies | Management groups |
| **02** | Hub network + firewall | Subscriptions + Layer 01 |
| **03** | Management resources | Hub network |
| **04** | Security services | Hub network |
| **05** | Sandbox subscriptions | Hub network |

**Reference:** [Deployment Guide](Deployment-Guide)

---

## 💰 Cost Estimates

| Component | Monthly | Annual | Notes |
|-----------|---------|--------|-------|
| Hub VNet + Firewall | $900 | $10.8k | Shared across org |
| Management resources | $400 | $4.8k | Logs, KeyVault, etc. |
| Spoke VNet + VPN | $200 | $2.4k | Per workload |
| Firewall rules | — | — | Included |
| **TOTAL (baseline)** | **$1,500** | **$18k** | Per org |

Optional: +$300-3000/mo (Defender, Sentinel, CMK)

**Reference:** [Subscriptions Layout](Subscriptions-Layout)

---

## ⚡ Quick Commands

### Login
```bash
az login
gh auth login
```

### Trigger Phase 1 setup
```bash
./scripts/010-BOOTSTRAP-START.ps1
```

### Terraform workflow
```bash
terraform -chdir=terraform/live init
terraform plan -out=tfplan
terraform apply tfplan
```

### View state
```bash
terraform state list
terraform state show <resource>
```

### Rollback
```bash
terraform destroy -auto-approve
```

**Full guide:** [Deployment Guide](Deployment-Guide)

---

## 📞 Common Scenarios

**"I'm new to Azure"**  
→ [Getting Started](Getting-Started) → [Architecture](Architecture)

**"I need to add a workload subscription"**  
→ [Subscriptions Layout](Subscriptions-Layout) → [Phase 2 Bootstrap](Phase-2-Bootstrap)

**"How do I deploy something?"**  
→ [Terraform Layers](Terraform-Layers) → [Deployment Guide](Deployment-Guide)

**"What's the security model?"**  
→ [RBAC & Access Control](RBAC-Access-Control) → [GitHub Security](GitHub-Security)

**"Something broke!"**  
→ [Incident Triage](Incident-Triage) → [Rollback Procedures](Rollback-Procedures)

---

## 🔗 Key Links

- **Repo:** [HCW-Plan_LZDeployment](https://github.com/HybridCloudWorks/Template-LZDeployment)
- **Microsoft CAF:** [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- **Azure Verified Modules:** [AVM Terraform](https://azure.github.io/Azure-Verified-Modules/)

---

**Bookmark this page!** | **Last Updated:** 2026-06-30
