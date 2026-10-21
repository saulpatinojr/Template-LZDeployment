<!-- Source: docs/DES-ARCHITECTURE-TOPOLOGY.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure Landing Zone Architecture

**Document ID**: DOC-ARCHITECTURE-001  
**Version**: 1.0  
**Status**: ✅ APPROVED  
**Last Updated**: 2026-06-30  
**Owner**: Platform Engineering  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Management Group Hierarchy](#management-group-hierarchy)
3. [Subscription Layout](#subscription-layout)
4. [Network Topology (Hub-Spoke)](#network-topology-hub-spoke)
5. [Security Architecture](#security-architecture)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Scaling Strategy](#scaling-strategy)
8. [Disaster Recovery](#disaster-recovery)

---

## Architecture Overview

### Design Principles

The Azure Landing Zone follows Microsoft Cloud Adoption Framework (CAF) best practices:

1. **Subscription Democratization**: Subscriptions as units of management/scale
2. **Policy-Driven Governance**: Azure Policy enforces compliance, not manual reviews
3. **Security First**: Least-privilege access, encryption by default, audit everything
4. **Operational Excellence**: Automation, monitoring, consistent patterns
5. **Cost Optimization**: Tag-based cost allocation, right-sizing, auto-cleanup

### Target State Architecture

```
TENANT ROOT
│
└─ INTERMEDIATE ROOT (mg-org-lz)
   │
   ├─ PLATFORM (shared services for all workloads)
   │  ├─ Connectivity (hub networking)
   │  ├─ Identity (auth & access)
   │  ├─ Management (monitoring & ops)
   │  └─ Security (threat detection & response)
   │
   ├─ LANDING ZONES (application workloads)
   │  ├─ Production (payroll app, etc.)
   │  ├─ Non-Production (dev/test)
   │  └─ Sandbox (experimentation)
   │
   └─ DECOMMISSIONED (cleanup staging)
```

---

## Management Group Hierarchy

### Full Hierarchy Diagram

```
Tenant Root Group
(Azure AD tenant root)
│
└─ mg-org-lz (Intermediate root, org prefix)
   │  ├─ Policies: Compliance baseline (all resources)
   │  ├─ RBAC: Admin group has owner
   │  └─ Tags: Environment=prod/nonprod by default
   │
   ├─ PLATFORM (mg-platform)
   │  │  ├─ Policies: Stricter than root
   │  │  ├─ RBAC: platform-admins group
   │  │  └─ Purpose: Shared infrastructure
   │  │
   │  ├─ CONNECTIVITY (mg-platform-connectivity)
   │  │  ├─ Subscription: sub-platform-hub-prod
   │  │  ├─ Resources: Hub vnet, firewall, VPN, DNS
   │  │  ├─ RBAC: network-admins group
   │  │  └─ Cost: ~$1,000/month
   │  │
   │  ├─ IDENTITY (mg-platform-identity)
   │  │  ├─ Subscription: sub-platform-identity-prod
   │  │  ├─ Resources: Domain controllers, Entra sync
   │  │  ├─ RBAC: identity-admins group
   │  │  └─ Cost: ~$100/month
   │  │
   │  ├─ MANAGEMENT (mg-platform-management)
   │  │  ├─ Subscription: sub-platform-mgmt-prod
   │  │  ├─ Resources: Log Analytics, automation, alerts
   │  │  ├─ RBAC: ops-team group
   │  │  └─ Cost: ~$300/month
   │  │
   │  └─ SECURITY (mg-platform-security)
   │     ├─ Subscription: sub-platform-security-prod
   │     ├─ Resources: Sentinel SIEM, threat detection
   │     ├─ RBAC: security-team group
   │     └─ Cost: ~$500/month (if Sentinel enabled)
   │
   ├─ LANDING ZONES (mg-landing-zones)
   │  │  ├─ Policies: Workload-specific
   │  │  ├─ RBAC: workload-admins group
   │  │  └─ Purpose: Application workloads
   │  │
   │  ├─ PROD (mg-landing-zones-prod)
   │  │  ├─ Subscription: sub-workload-payroll-prod
   │  │  ├─ Resources: Production applications
   │  │  ├─ Policies: Stricter, backups required
   │  │  ├─ RBAC: payroll-team group
   │  │  └─ Cost: ~$2,000/month (app-dependent)
   │  │
   │  ├─ NONPROD (mg-landing-zones-nonprod)
   │  │  ├─ Subscriptions: dev/test apps
   │  │  ├─ Policies: Moderate (allows experimentation)
   │  │  ├─ RBAC: dev-team group
   │  │  └─ Cost: ~$500/month
   │  │
   │  └─ SANDBOX (mg-landing-zones-sandbox)
   │     ├─ Subscription: sub-sandbox-nonprod
   │     ├─ Resources: Developer experiments
   │     ├─ Policies: Permissive (auto-cleanup)
   │     ├─ RBAC: all-engineers group
   │     └─ Cost: ~$200/month
   │
   └─ DECOMMISSIONED (mg-decommissioned)
      ├─ Purpose: Staging area for deletion
      ├─ Policy: Auto-delete after 30-60 days
      └─ RBAC: Limited (no active users)
```

### Policy Inheritance

```
Root Policies (apply to everything)
│ Enforce: Tagging (6 mandatory tags)
│ Enforce: TLS 1.2 minimum
│ Audit: Resource creation
│
├─→ Platform Policies (stricter)
│  │ Enforce: No public IPs (except firewall)
│  │ Enforce: All storage encrypted
│  │ Audit: Network changes
│  │
│  └─→ Connectivity Policies
│     Enforce: All traffic through firewall
│     Audit: Route table changes
│
├─→ Landing Zone Policies
│  │ Enforce: Managed identity on compute
│  │ Enforce: Private endpoints for PaaS
│  │
│  ├─→ Prod Policies (strictest)
│  │  Enforce: Backup required
│  │  Deny: Resource deletion (require approval)
│  │
│  └─→ Sandbox Policies (most permissive)
│     Allow: Any resource type
│     Enforce: Auto-cleanup after 90 days
```

---

## Subscription Layout

### Subscription-to-ManagementGroup Mapping

```
PLATFORM SUBSCRIPTIONS (4 total, shared services)
├─ sub-platform-hub-prod
│  ├─ Management Group: mg-platform-connectivity
│  ├─ Purpose: Hub vnet, firewall, VPN/ExpressRoute
│  ├─ Resources: 1 vnet, 4 subnets, 1 firewall, 4 NSGs
│  ├─ RBAC: Contributor (network-admins group)
│  └─ Monthly Cost: $1,000-2,000
│
├─ sub-platform-identity-prod
│  ├─ Management Group: mg-platform-identity
│  ├─ Purpose: Identity & auth (optional: on-prem sync)
│  ├─ Resources: Optional DCs, Entra connectors
│  ├─ RBAC: Contributor (identity-admins group)
│  └─ Monthly Cost: $100-200
│
├─ sub-platform-mgmt-prod
│  ├─ Management Group: mg-platform-management
│  ├─ Purpose: Centralized logging & monitoring
│  ├─ Resources: Log Analytics workspace, automation account, alerts
│  ├─ RBAC: Contributor (ops-team group)
│  └─ Monthly Cost: $300-500
│
└─ sub-platform-security-prod
   ├─ Management Group: mg-platform-security
   ├─ Purpose: SIEM, threat detection, security policies
   ├─ Resources: Sentinel workspace, security alerts, key vault
   ├─ RBAC: Contributor (security-team group)
   └─ Monthly Cost: $0 (baseline) + $300-1,000 (if Sentinel)

WORKLOAD SUBSCRIPTIONS (2+ total, application landing zones)
├─ sub-workload-payroll-prod
│  ├─ Management Group: mg-landing-zones-prod
│  ├─ Purpose: First production workload
│  ├─ Resources: App Service, SQL Database, spoke vnet
│  ├─ RBAC: Contributor (payroll-team group)
│  └─ Monthly Cost: $2,000+ (app-dependent)
│
└─ sub-sandbox-nonprod
   ├─ Management Group: mg-landing-zones-sandbox
   ├─ Purpose: Developer testing & experimentation
   ├─ Resources: VMs, App Services, databases (temporary)
   ├─ RBAC: Contributor (all-engineers group)
   └─ Monthly Cost: $200-500

TOTAL BASELINE COST: ~$4,100-5,000/month (platform only)
+ workload costs on top
```

---

## Network Topology (Hub-Spoke)

### Hub Networking Diagram

```
INTERNET
    │
    ├─→ (inbound/outbound traffic)
    │
┌───┴────────────────────────────────────────┐
│                                            │
│     AZURE FIREWALL (fw-hub-prod-eastus-01) │◄─ Inbound/Outbound filtering
│     Public IP: (pip-fw-hub-prod-...)       │   (threat intelligence,
│                                            │    URL filtering, DPI)
└─────────────────┬──────────────────────────┘
                  │
                  │ (10.0.0.0/16)
                  │
        ┌─────────┴─────────┐
        │                   │
        │                   │
   ┌────▼──────────────────▼────┐
   │   HUB VNET                 │
   │   vnet-hub-platform-...    │
   │   (10.0.0.0/16)            │
   │                            │
   │  Subnets:                  │
   │  ├─ GatewaySubnet (10.0.0.0/24)
   │  │  └─ VPN/ExpressRoute gateway (optional)
   │  │     └─ On-premises connectivity
   │  │
   │  ├─ AzureFirewallSubnet (10.0.1.0/24)
   │  │  └─ Azure Firewall
   │  │     └─ Centralized threat detection
   │  │
   │  ├─ ManagementSubnet (10.0.2.0/24)
   │  │  └─ Log Analytics agent VMs
   │  │     └─ Monitoring & troubleshooting
   │  │
   │  └─ BastionSubnet (10.0.3.0/24)
   │     └─ Azure Bastion (optional)
   │        └─ Secure VM access (no public IP)
   │
   └───┬────────────────────────┬──────────────┬──────────────┐
       │                        │              │              │
       │                        │              │              │
   PEERING                  PEERING       PEERING         PEERING
       │                        │              │              │
       ▼                        ▼              ▼              ▼
   ┌─────────┐          ┌─────────────┐  ┌─────────────┐  ┌──────────┐
   │SPOKE-1  │          │ SPOKE-2     │  │ SPOKE-3     │  │ SANDBOX  │
   │         │          │             │  │             │  │          │
   │Payroll  │          │ HR-System   │  │ CRM         │  │ Dev/Test │
   │         │          │             │  │             │  │          │
   │10.1.0.0/│          │10.2.0.0/16  │  │10.3.0.0/16  │  │10.100.0.0│
   │16       │          │             │  │             │  │/16       │
   │         │          │             │  │             │  │          │
   │App: Web │          │App: Web     │  │App: API     │  │Test Apps │
   │App: API │          │App: API     │  │App: Data    │  │          │
   │Data: DB │          │Data: DB     │  │Data: Cache  │  │          │
   └─────────┘          └─────────────┘  └─────────────┘  └──────────┘
   
   All spokes route through hub firewall for egress
   Hub controls: Who can reach who, threat intel, DPI
```

### Network Flow Examples

**Example 1: Payroll App to Database**
```
Web Tier (spoke-payroll)
  ↓ (internal, via NSG)
API Tier (spoke-payroll)
  ↓ (internal, via NSG)
Database Tier (spoke-payroll)
  ↓ (within spoke, no firewall needed)
Database responds
```

**Example 2: Spoke to Internet**
```
Spoke VM requests: GET https://api.example.com
  ↓ (routes via hub firewall)
Hub Firewall
  ├─ Checks: Threat intel (is api.example.com malicious?)
  ├─ Checks: URL filtering (is this category allowed?)
  ├─ Checks: DPI (is this really HTTPS?)
  └─ Decision: ALLOW or DENY
    ↓ (if allowed)
Internet
  ↓
Response sent back through firewall
```

**Example 3: Spoke to Spoke (same app)**
```
Payroll-Dev (spoke) requests Payroll-Prod (spoke)
  ↓ (routes via hub firewall for audit trail)
Hub Firewall
  ├─ Checks: Is this traffic allowed?
  ├─ Checks: Threat intel
  └─ Decision: ALLOW or DENY
    ↓ (if allowed)
Payroll-Prod (spoke)
```

---

## Security Architecture

### Defense in Depth Layers

```
LAYER 1: Perimeter (Azure Firewall)
├─ Threat Intelligence: Blocks known malicious IPs
├─ URL Filtering: Blocks malicious categories
└─ DPI (Deep Packet Inspection): Inspects traffic content

      ↓ (passes firewall checks)

LAYER 2: Network (Network Security Groups)
├─ East-West: Who can talk to whom within spoke
├─ Rules: Per-subnet NSGs
└─ Example: App tier can reach DB, but DB cannot reach Web

      ↓ (passes NSG rules)

LAYER 3: Resource (Azure Resource Encryption)
├─ Storage: Encrypted at rest (AES-256)
├─ Databases: Encrypted at rest (TDE)
├─ In Transit: TLS 1.2+ enforced
└─ Keys: Customer-managed (CMK) optional

      ↓ (passes encryption checks)

LAYER 4: Access (RBAC + Managed Identity)
├─ RBAC: Only authorized users/apps can access
├─ Managed Identity: Apps use MSI (no passwords)
├─ PIM: Elevated access is time-limited
└─ MFA: Multi-factor auth for privileged access

      ↓ (passes access controls)

LAYER 5: Detection (Monitoring & SIEM)
├─ Log Analytics: Logs all resource creation/changes
├─ Microsoft Defender: Scans for vulnerabilities
├─ Azure Sentinel: ML-based threat detection
└─ Alerts: Security team notified on suspicious activity
```

### RBAC & Access Control

```
ENTRA GROUPS (users added to these groups)
├─ Azure-platform-admins → Contributor on platform subs
├─ Azure-platform-readers → Reader on all subs (audit)
├─ Azure-workload-admins → Contributor on workload subs
├─ Azure-security-team → Contributor on security sub
├─ Azure-operations-team → Reader on all + Network Contrib
└─ Azure-sandbox-admins → Contributor on sandbox only

SERVICE PRINCIPALS (CI/CD, no passwords)
├─ sp-terraform-platform-prod → Contributor on 4 platform subs
├─ sp-terraform-workload-prod → Contributor on workload sub
└─ sp-terraform-sandbox-nonprod → Contributor on sandbox sub

RESULT: Everyone has ONLY what they need (least privilege)
```

---

## Data Flow Diagrams

### Resource Creation Flow

```
Developer Creates Pull Request
    ├─ Changes: terraform/layers/02-hub-networking/main.tf
    │
    ↓ (automatic via GitHub Actions)
    
GitHub Actions Triggers Workflows
    ├─ 00-validate: terraform validate (syntax)
    ├─ 10-plan: terraform plan (what will change)
    └─ Result: Plan output posted to PR for review
    
    ↓ (manual)
    
Developer/Reviewer Reviews Plan
    ├─ Reads: "Will add: 1 vnet, 4 subnets, 1 firewall"
    ├─ Decides: Looks good ✅
    └─ Action: Approves and merges PR
    
    ↓ (automatic)
    
GitHub Actions Triggers Apply
    ├─ terraform init: Connect to Terraform Cloud
    ├─ terraform plan: Double-check
    ├─ terraform apply: Create resources
    └─ State: Saved to Terraform Cloud
    
    ↓
    
Azure Resources Created
    ├─ vnet-hub-platform-prod-eastus-01 ✅
    ├─ 4 subnets ✅
    ├─ 4 NSGs ✅
    ├─ 1 firewall ✅
    └─ 1 public IP ✅
    
    ↓
    
Terraform State Updated
    ├─ TFC stores state (encrypted)
    ├─ Audit log: What changed, who made it, when
    └─ Drift detection: Weekly checks if real ≠ desired
```

### Traffic Flow (Workload to Internet)

```
1. User's browser requests: https://app.company.com
   └─ Resolves to App Service public IP (via DNS)

2. Request hits App Service (in spoke vnet)
   ├─ Lands on: snet-web-payroll-prod-eastus-01
   ├─ NSG check: Allow traffic from internet? YES
   └─ Passes through NSG rule

3. App Service processes request
   ├─ Might need to call: external API (example.com)
   ├─ Outbound traffic: Sent to hub firewall (default route)
   └─ Why firewall? Audit trail + threat intel

4. Hub Firewall evaluates traffic
   ├─ Destination: example.com:443 (HTTPS)
   ├─ Threat Intel: Is example.com malicious? NO
   ├─ URL Filter: Is this category allowed? YES
   ├─ DPI: Is this really HTTPS? YES
   └─ Decision: ALLOW

5. Traffic exits to Internet via Firewall Public IP
   ├─ From: 10.1.x.x (spoke private IP) via NAT
   ├─ To: example.com:443
   └─ Public IP: Firewall's public IP

6. Response comes back through firewall
   ├─ Firewall: Checks if this is response to allowed request
   ├─ Decision: ALLOW (return traffic)
   └─ Response: Routed back to app

7. Response reaches App Service
   ├─ NSG: Allow inbound? YES (for established connections)
   └─ Response: Delivered to user's browser

AUDIT TRAIL:
└─ Log Analytics: All traffic logged (what, who, when, result)
   ├─ src: 10.1.x.x (payroll web tier)
   ├─ dst: example.com:443
   ├─ action: ALLOW
   ├─ reason: Passed threat intel, URL filter, DPI
   └─ timestamp: 2026-06-30 14:30:00Z
```

---

## Scaling Strategy

### Adding New Workload Subscriptions

```
Step 1: Create Subscription via Subscription Vending
├─ Azure Portal or Terraform module
└─ Assign to correct MG (mg-landing-zones-prod)

Step 2: Deploy Spoke Network
├─ Create spoke vnet (10.2.0.0/16 example)
├─ Peer to hub vnet
├─ NSGs configured
└─ Routes through hub firewall

Step 3: Deploy Application Resources
├─ App Service, SQL Database, storage, etc.
├─ Tags applied (Environment, Owner, CostCenter)
└─ Monitoring connected to hub Log Analytics

Step 4: Configure RBAC & Access
├─ Create Entra group (Azure-{app}-admins)
├─ Assign Contributor role to workload subscription
└─ Team members added to group

RESULT: New workload ready in 2-4 hours!
Repeatable process, consistent pattern, full audit trail
```

### Growth Projections

```
Current State (2026-07-07):
├─ 4 platform subscriptions
├─ 2 workload subscriptions (payroll, sandbox)
└─ Total MGs: 11

6-Month Projection (2026-12-31):
├─ 4 platform subscriptions (same)
├─ 5-6 workload subscriptions
│  ├─ Payroll (prod)
│  ├─ HR System (prod)
│  ├─ CRM (prod)
│  ├─ Finance (prod)
│  ├─ Analytics (prod)
│  └─ Sandbox (nonprod)
├─ 2 additional Nonprod subscriptions (dev/test)
└─ Total MGs: ~15

1-Year Projection (2027-06-30):
├─ 4 platform subscriptions (same)
├─ 8-10 workload subscriptions (prod + nonprod + sandbox)
└─ Total MGs: ~20

Cost Scaling:
├─ Platform: ~$4,100/month (fixed)
├─ Per Workload: ~$2,000-5,000/month (variable)
└─ Example 5 apps: $4,100 + (5 × $3,000) = $19,100/month
```

---

## Disaster Recovery

### RTO/RPO Targets

```
Platform Infrastructure:
├─ RTO (Recovery Time Objective): 4 hours
│  └─ Hub vnet restore from Terraform state
├─ RPO (Recovery Point Objective): 1 hour
│  └─ TFC state backup (hourly snapshots)
└─ Strategy: Full rebuild from Terraform code

Application Workloads:
├─ RTO: Varies by criticality (see tagging strategy)
├─ RPO: Varies by backup schedule
└─ Strategy: Per-app backup policies

Disaster Scenarios:
├─ Scenario 1: Hub vnet deleted
│  └─ Solution: terraform apply (hub recreated in 20 min)
│
├─ Scenario 2: Firewall compromised
│  └─ Solution: terraform destroy + terraform apply (30 min)
│
├─ Scenario 3: Regional outage (eastus down)
│  └─ Solution: Manual failover to westus (2-4 hours)
│     └─ Terraform redeploys to new region
│     └─ DNS updated
│     └─ Spoke apps failover manually
│
└─ Scenario 4: Azure AD tenant compromise
   └─ Solution: Break-glass accounts (documented separately)
      └─ Full recovery via support ticket
```

### Backup Strategy

```
Terraform State:
├─ Storage: Terraform Cloud (encrypted, auto-backed up)
├─ Retention: 30 days (versions)
└─ Recovery: terraform state pull → restore

Key Vaults:
├─ Backup: Azure Key Vault backup (soft delete + purge protection)
├─ Retention: 90 days (soft delete)
└─ Recovery: Can restore deleted keys

Log Analytics:
├─ Retention: 30 days (logs)
├─ Export: To storage account (long-term archive)
└─ Recovery: Query historical logs up to 30 days

Applications:
├─ Backup: Per-app backup policies (see tagging strategy)
├─ Frequency: Daily (prod) or weekly (nonprod)
└─ Recovery: Per-app RTO (varies)
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial architecture |

---

## Related Documents

- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Step-by-step Terraform deployment
- [SUBSCRIPTIONS.md](SUBSCRIPTIONS.md) - Subscription details
- [NAMING-CONVENTION.md](NAMING-CONVENTION.md) - Resource naming
- [SERVICE-PRINCIPALS.md](SERVICE-PRINCIPALS.md) - CI/CD authentication

---

**Questions?** Contact Platform Engineering Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

