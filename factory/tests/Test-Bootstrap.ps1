#Requires -Version 7.0
# Stage 9 broker contract tests. Added with Stage 9; execution was explicitly
# skipped in the implementation environment because required external binaries
# and authenticated services were not part of that environment.
#
# Covers both identity.cicdIdentityModel modes:
#   minimal (default)  - 2 identities total, subject list on apply, union RBAC
#   per-environment    - byte-for-byte the pre-change output (idempotent estates)
# plus the azurerm state data-plane grants and the hcp-terraform negative case.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Import-Module "$repo/factory/bootstrap/LZFactory.Bootstrap.psm1" -Force

$pass = 0; $fail = 0
function ok($name, $condition, $extra) {
    if ($condition) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name$(if ($extra) { ""  -> $extra"" })" }
}

$cfgRaw = Get-Content "$PSScriptRoot/fixtures/sample-config.json" -Raw
function Get-SampleConfig { $script:cfgRaw | ConvertFrom-Json -Depth 50 }
$schemaPath = "$repo/factory/schema/lz-config.schema.json"
$mgRootScope = '/providers/Microsoft.Management/managementGroups/mg-contoso'

# ---------------------------------------------------------------------------
# per-environment mode: the legacy contract, selected explicitly
# ---------------------------------------------------------------------------
$cfg = Get-SampleConfig
$cfg.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue 'per-environment'
$plan = New-LzBootstrapPlan -Config $cfg
$envCount = @($cfg.environments.platform).Count + @($cfg.environments.application).Count

ok 'plan is non-mutating by default' ($plan.mode -eq 'plan')
ok 'two identities per environment' (@($plan.identities).Count -eq ($envCount * 2))
ok 'all plan identities are Reader' (
    @($plan.identities | Where-Object { $_.kind -eq 'plan' -and @($_.roles) -notcontains 'Reader' }).Count -eq 0
)
ok 'workload apply identities are Contributor' (
    @($plan.identities | Where-Object {
        $_.kind -eq 'apply' -and $_.environment -ne 'bootstrap' -and
        @($_.roles) -notcontains 'Contributor'
    }).Count -eq 0
)
ok 'bootstrap apply uses management-group policy roles' (
    @($plan.identities | Where-Object {
        $_.kind -eq 'apply' -and $_.environment -eq 'bootstrap' -and
        @($_.roles) -contains 'Management Group Contributor' -and
        @($_.roles) -contains 'Resource Policy Contributor'
    }).Count -eq 1
)
ok 'plan subjects are pull_request plus the default branch (exact, no wildcards)' (
    @($plan.identities | Where-Object kind -eq 'plan' | Where-Object {
        @($_.subject).Count -ne 2 -or
        @($_.subject | Where-Object { $_ -match ':pull_request$' }).Count -ne 1 -or
        @($_.subject | Where-Object { $_ -match ':ref:refs/heads/[^*]+$' }).Count -ne 1
    }).Count -eq 0
)
ok 'apply subjects are exact environment subjects' (
    @($plan.identities | Where-Object { $_.kind -eq 'apply' -and $_.subject -notmatch ':environment:[^*]+$' }).Count -eq 0
)
ok 'no wildcard subjects' (
    @($plan.identities | Where-Object { $_.subject -match '\*' }).Count -eq 0
)
ok 'repository derived from config' ($plan.repository -eq 'contoso-platform/contoso_LZ_Deployment')
ok 'active layers retained' ($plan.layers -contains 'platform-connectivity' -and $plan.layers -contains 'platform-management' -and $plan.layers -contains 'global')

# Deployment branch policy: every GitHub environment the plan will reconcile
# must show protected_branches=true in plan-first mode (a workflow_dispatch
# executes the dispatched ref's workflow file; unrestricted environments let a
# write-capable actor run a stripped workflow copy past reviewers).
function Test-BranchPolicyCoverage($planObject) {
    @($planObject.githubEnvironments).Count -eq @($planObject.environments).Count -and
    @($planObject.githubEnvironments | Where-Object {
        $_.deploymentBranchPolicy.protectedBranches -ne $true -or
        $_.deploymentBranchPolicy.customBranchPolicies -ne $false
    }).Count -eq 0 -and
    @($planObject.environments | Where-Object { $_ -notin @($planObject.githubEnvironments | ForEach-Object name) }).Count -eq 0
}
ok 'plan surfaces protected-branches deployment policy for every environment (per-environment model)' (
    Test-BranchPolicyCoverage $plan
)

# Byte parity: per-environment output must be byte-for-byte the pinned broker
# output, so generated estates re-run idempotently with zero drift. The
# fixture was captured from the 0.10.0 module (azurerm-only, three-layer AVM
# architecture) with generatedAt normalized.
#
# DOCUMENTED DELTA (2026-08-02): githubEnvironments is stripped before the
# comparison. It is new GitHub-path metadata added so plan-first mode shows the
# deployment_branch_policy the broker now enforces; it changes nothing the
# Azure reconciliation consumes. Identity records, environments, layers, and
# every pre-existing field must still match the fixture byte-for-byte.
$plan.generatedAt = 'NORMALIZED'
$plan.PSObject.Properties.Remove('githubEnvironments')
$expected = Get-Content "$PSScriptRoot/fixtures/bootstrap-plan-per-environment.expected.json" -Raw
$actual = $plan | ConvertTo-Json -Depth 30
ok 'per-environment plan is byte-for-byte the pre-change output' ($actual -eq $expected) $(
    if ($actual -ne $expected) { 'diff at first mismatch index ' + (0..([Math]::Min($actual.Length, $expected.Length) - 1) | Where-Object { $actual[$_] -ne $expected[$_] } | Select-Object -First 1) }
)
ok 'per-environment plan carries no identityModel marker (shape parity)' (
    -not $plan.PSObject.Properties['identityModel']
)

# ---------------------------------------------------------------------------
# minimal mode: the default, key absent
# ---------------------------------------------------------------------------
$cfgMin = Get-SampleConfig
$planMin = New-LzBootstrapPlan -Config $cfgMin
$planRecord = @($planMin.identities | Where-Object kind -eq 'plan')
$applyRecord = @($planMin.identities | Where-Object kind -eq 'apply')

ok 'minimal is the default when the key is absent' ($planMin.identityModel -eq 'minimal')
ok 'plan surfaces protected-branches deployment policy for every environment (minimal model)' (
    Test-BranchPolicyCoverage $planMin
)
ok 'minimal emits exactly 2 identity records' (@($planMin.identities).Count -eq 2) (@($planMin.identities).Count)
ok 'minimal emits one plan and one apply record' ($planRecord.Count -eq 1 -and $applyRecord.Count -eq 1)
ok 'minimal display names have no environment segment' (
    $planRecord[0].displayName -eq 'sp-chg-plan' -and $applyRecord[0].displayName -eq 'sp-chg-apply'
)
ok 'minimal plan subjects are pull_request plus the default branch' (
    @($planRecord[0].subject).Count -eq 2 -and
    @($planRecord[0].subject | Where-Object { $_ -match ':pull_request$' }).Count -eq 1 -and
    @($planRecord[0].subject | Where-Object { $_ -match ':ref:refs/heads/[^*]+$' }).Count -eq 1
)
ok 'minimal plan identity is Reader at the MG root' (
    @($planRecord[0].roleAssignments | Where-Object { $_.role -eq 'Reader' -and $_.scope -eq $mgRootScope }).Count -eq 1
)
$applySubjects = @($applyRecord[0].subject)
ok 'minimal apply subject is a list with one entry per unique environment' (
    $applySubjects.Count -eq @($planMin.environments).Count
) ($applySubjects -join '; ')
ok 'every minimal apply subject is an exact environment subject' (
    @($applySubjects | Where-Object { $_ -notmatch ':environment:[^*]+$' }).Count -eq 0
)
ok 'contract #2: no pull_request subject on the apply record' (
    @($applySubjects | Where-Object { $_ -match 'pull_request' }).Count -eq 0
)
ok 'minimal apply covers every environment subject' (
    @($planMin.environments | Where-Object { $applySubjects -notcontains "repo:$($planMin.repository):environment:$_" }).Count -eq 0
)
ok 'no wildcard subjects in minimal mode' (
    @($applySubjects + @($planRecord[0].subject) | Where-Object { $_ -match '\*' }).Count -eq 0
)

# Union RBAC: MG-root roles from the bootstrap entry plus Contributor once per
# distinct subscription, plus the state data-plane grant (azurerm backend —
# ADR 0015). Fixture: management ...001, connectivity ...002, prod ...003 =>
# 2 MG-root roles + 3 Contributor + 1 Storage Blob Data Contributor = 6.
$applyAssignments = @($applyRecord[0].roleAssignments)
ok 'minimal apply RBAC is the deduplicated union (6 assignments)' ($applyAssignments.Count -eq 6) ($applyAssignments | ConvertTo-Json -Compress)
ok 'minimal apply keeps both MG-root bootstrap roles' (
    @($applyAssignments | Where-Object { $_.scope -eq $mgRootScope -and $_.role -in @('Management Group Contributor', 'Resource Policy Contributor') }).Count -eq 2
)
ok 'minimal apply grants Contributor once per distinct subscription' (
    @($applyAssignments | Where-Object role -eq 'Contributor').Count -eq 3 -and
    (@($applyAssignments | Where-Object role -eq 'Contributor' | ForEach-Object scope | Sort-Object -Unique).Count -eq 3)
)
ok 'no duplicate role+scope pairs in the union' (
    @($applyAssignments | ForEach-Object { "$($_.role)|$($_.scope)" } | Sort-Object -Unique).Count -eq $applyAssignments.Count
)

# Explicit 'minimal' must equal the absent-key default.
$cfgExplicit = Get-SampleConfig
$cfgExplicit.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue 'minimal'
$planExplicit = New-LzBootstrapPlan -Config $cfgExplicit
$planMin.generatedAt = 'NORMALIZED'; $planExplicit.generatedAt = 'NORMALIZED'
ok 'explicit minimal equals absent-key default' (
    ($planExplicit | ConvertTo-Json -Depth 30) -eq ($planMin | ConvertTo-Json -Depth 30)
)

# ---------------------------------------------------------------------------
# azurerm is the only backend (ADR 0015): state data-plane roles are ALWAYS
# planned, in both identity modes.
# ---------------------------------------------------------------------------
ok 'minimal plan grants storage data-plane roles' (
    ($planMin | ConvertTo-Json -Depth 30) -match 'Storage Blob Data'
)
ok 'per-environment plan grants storage data-plane roles' (
    $actual -match 'Storage Blob Data'
)

# ---------------------------------------------------------------------------
# azurerm backend: state data-plane grants (defect fix - the broker previously
# granted no data-plane roles although backend.tf sets use_azuread_auth)
# ---------------------------------------------------------------------------
function ConvertTo-AzurermBackendConfig([object]$Config) {
    $Config.backend.type = 'azurerm'
    $Config.backend | Add-Member -Force -NotePropertyName azurerm -NotePropertyValue ([pscustomobject]@{
        resourceGroupName = 'rg-chg-tfstate'
        storageAccountName = 'chgtfstate'
        containerName = 'tfstate'
        subscriptionId = 'aaaaaaaa-0000-0000-0000-000000000001'
        useAzureAdAuth = $true
    })
    return $Config
}
# Container scope (not account scope): each identity touches exactly its own
# state container.
$stateScope = '/subscriptions/aaaaaaaa-0000-0000-0000-000000000001/resourceGroups/rg-chg-tfstate/providers/Microsoft.Storage/storageAccounts/chgtfstate/blobServices/default/containers/tfstate'

$cfgAzMin = ConvertTo-AzurermBackendConfig (Get-SampleConfig)
$planAzMin = New-LzBootstrapPlan -Config $cfgAzMin
$azPlanRec = @($planAzMin.identities | Where-Object kind -eq 'plan')[0]
$azApplyRec = @($planAzMin.identities | Where-Object kind -eq 'apply')[0]
ok 'azurerm minimal: plan identity gets Storage Blob Data Reader on state' (
    @($azPlanRec.roleAssignments | Where-Object { $_.role -eq 'Storage Blob Data Reader' -and $_.scope -eq $stateScope }).Count -eq 1
)
ok 'azurerm minimal: apply identity gets Storage Blob Data Contributor on state' (
    @($azApplyRec.roleAssignments | Where-Object { $_.role -eq 'Storage Blob Data Contributor' -and $_.scope -eq $stateScope }).Count -eq 1
)
ok 'azurerm minimal: no Contributor-level state grant on the plan identity' (
    @($azPlanRec.roleAssignments | Where-Object { $_.scope -eq $stateScope -and $_.role -ne 'Storage Blob Data Reader' }).Count -eq 0
)

$cfgAzPer = ConvertTo-AzurermBackendConfig (Get-SampleConfig)
$cfgAzPer.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue 'per-environment'
$planAzPer = New-LzBootstrapPlan -Config $cfgAzPer
ok 'azurerm per-environment: every plan record carries the Reader state grant' (
    @($planAzPer.identities | Where-Object kind -eq 'plan' | Where-Object {
        @($_.stateRoleAssignments | Where-Object { $_.role -eq 'Storage Blob Data Reader' -and $_.scope -eq $stateScope }).Count -ne 1
    }).Count -eq 0
)
ok 'azurerm per-environment: every apply record carries the Contributor state grant' (
    @($planAzPer.identities | Where-Object kind -eq 'apply' | Where-Object {
        @($_.stateRoleAssignments | Where-Object { $_.role -eq 'Storage Blob Data Contributor' -and $_.scope -eq $stateScope }).Count -ne 1
    }).Count -eq 0
)
ok 'azurerm per-environment: control-plane records otherwise unchanged' (
    @($planAzPer.identities).Count -eq ($envCount * 2) -and
    @($planAzPer.identities | Where-Object { $_.kind -eq 'plan' -and @($_.roles) -notcontains 'Reader' }).Count -eq 0
)

# ---------------------------------------------------------------------------
# constrained sandbox RBAC Administrator grant. platform-management renders
# azurerm_role_assignment.sandbox_cleanup whenever azure.subscriptions.sandbox
# is set, and writing it needs Microsoft.Authorization/roleAssignments/write in
# the sandbox subscription. The grant must appear exactly when the sandbox
# subscription is set (both models), on the identity that applies
# platform-management, ABAC-constrained to Contributor-to-ServicePrincipal.
#
# Parity note: the per-environment parity fixture sets NO sandbox subscription
# (asserted below), so byte parity against the pre-change output holds. For
# sandbox-enabled per-environment configs the optional delegatedRoleAssignments
# property is a deliberate, documented delta from the pre-change output - the
# pre-change broker never created this grant, which is the defect being fixed.
# ---------------------------------------------------------------------------
$sandboxSub = 'aaaaaaaa-0000-0000-0000-000000000004'
$sandboxScope = "/subscriptions/$sandboxSub"
$contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
# Exact expressions mirrored from scripts/Start-LandingZoneBootstrap.ps1
# (attribute source differs per action: Request for write, Resource for delete).
$expectedCondition = (
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR " +
    "(@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$contributorRoleId} AND " +
    "@Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'})) AND " +
    "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR " +
    "(@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$contributorRoleId} AND " +
    "@Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}))"
)
function Add-SandboxSubscription([object]$Config) {
    $Config.azure.subscriptions | Add-Member -NotePropertyName sandbox -NotePropertyValue $script:sandboxSub
    return $Config
}
function Test-SandboxGrant($spec) {
    $spec.role -eq 'Role Based Access Control Administrator' -and
    $spec.scope -eq $script:sandboxScope -and
    $spec.conditionVersion -eq '2.0' -and
    $spec.condition -eq $script:expectedCondition
}

# Negative space first: the parity premise and the never-otherwise rule.
$fixtureCfg = Get-SampleConfig
ok 'parity premise holds: fixture sets no sandbox subscription' (
    -not $fixtureCfg.azure.subscriptions.PSObject.Properties['sandbox']
)
ok 'no sandbox: minimal plan contains no RBAC Administrator grant' (
    ($planMin | ConvertTo-Json -Depth 30) -notmatch 'Role Based Access Control Administrator'
)
ok 'no sandbox: per-environment plan contains no RBAC Administrator grant' (
    $actual -notmatch 'Role Based Access Control Administrator' -and
    @($plan.identities | Where-Object { $_.PSObject.Properties['delegatedRoleAssignments'] }).Count -eq 0
)

# minimal + sandbox: the grant lands in the shared apply union, once.
$cfgSbxMin = Add-SandboxSubscription (Get-SampleConfig)
$planSbxMin = New-LzBootstrapPlan -Config $cfgSbxMin
$sbxApply = @($planSbxMin.identities | Where-Object kind -eq 'apply')[0]
$sbxPlan = @($planSbxMin.identities | Where-Object kind -eq 'plan')[0]
$sbxGrants = @($sbxApply.roleAssignments | Where-Object { $_.role -eq 'Role Based Access Control Administrator' })
ok 'sandbox minimal: exactly one RBAC Administrator grant on the shared apply' ($sbxGrants.Count -eq 1)
ok 'sandbox minimal: grant is sandbox-scoped with the exact ABAC condition' (
    $sbxGrants.Count -eq 1 -and (Test-SandboxGrant $sbxGrants[0])
) ($sbxGrants | ConvertTo-Json -Compress)
ok 'sandbox minimal: union is otherwise unchanged (6 + 1 assignments)' (
    @($sbxApply.roleAssignments).Count -eq 7
)
ok 'sandbox minimal: plan identity never carries the grant' (
    ($sbxPlan.roleAssignments | ConvertTo-Json -Depth 10) -notmatch 'Role Based Access Control Administrator'
)

# per-environment + sandbox: the grant lands on the management apply identity
# (the one that applies platform-management), and nowhere else.
$cfgSbxPer = Add-SandboxSubscription (Get-SampleConfig)
$cfgSbxPer.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue 'per-environment'
$planSbxPer = New-LzBootstrapPlan -Config $cfgSbxPer
$carriers = @($planSbxPer.identities | Where-Object { $_.PSObject.Properties['delegatedRoleAssignments'] })
ok 'sandbox per-environment: exactly one record carries the grant' ($carriers.Count -eq 1)
ok 'sandbox per-environment: the carrier is the management apply identity' (
    $carriers.Count -eq 1 -and $carriers[0].environment -eq 'management' -and $carriers[0].kind -eq 'apply'
)
ok 'sandbox per-environment: grant is sandbox-scoped with the exact ABAC condition' (
    $carriers.Count -eq 1 -and @($carriers[0].delegatedRoleAssignments).Count -eq 1 -and
    (Test-SandboxGrant @($carriers[0].delegatedRoleAssignments)[0])
)
ok 'sandbox per-environment: control-plane fields of the carrier are unchanged' (
    $carriers.Count -eq 1 -and
    @($carriers[0].roles) -contains 'Contributor' -and
    $carriers[0].scope -eq '/subscriptions/aaaaaaaa-0000-0000-0000-000000000001' -and
    $carriers[0].subject -eq 'repo:contoso-platform/contoso_LZ_Deployment:environment:management'
)
ok 'sandbox per-environment: no plan record carries any RBAC Administrator grant' (
    @($planSbxPer.identities | Where-Object { $_.kind -eq 'plan' -and (($_ | ConvertTo-Json -Depth 10) -match 'Role Based Access Control Administrator') }).Count -eq 0
)

# ---------------------------------------------------------------------------
# schema: identity.cicdIdentityModel accepts both enum values, rejects others,
# and the fixture without the key (the minimal default) stays valid
# ---------------------------------------------------------------------------
ok 'schema: fixture without the key validates' (Test-Json -Json $cfgRaw -SchemaFile $schemaPath -ErrorAction SilentlyContinue)
foreach ($value in @('minimal', 'per-environment')) {
    $c = Get-SampleConfig
    $c.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue $value
    ok "schema: cicdIdentityModel '$value' validates" (
        Test-Json -Json ($c | ConvertTo-Json -Depth 50) -SchemaFile $schemaPath -ErrorAction SilentlyContinue
    )
}
$cBad = Get-SampleConfig
$cBad.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue 'per-subscription'
ok 'schema: an unknown cicdIdentityModel value is rejected' (
    -not (Test-Json -Json ($cBad | ConvertTo-Json -Depth 50) -SchemaFile $schemaPath -ErrorAction SilentlyContinue)
)

# ---------------------------------------------------------------------------
# apply-path environment resolution (TODO.md Factory Bootstrap defect):
# Invoke-LzBootstrap -Apply resolves a subscription for every plan.environments
# entry (Set-LzGitHubEnvironment) and for every layer's environment
# (AZURE_SUBSCRIPTION_IDS). 'bootstrap' is in every default wizard export's
# platform plane and previously hit the fail-closed default throw, so every
# broker apply against a default export failed after identity reconciliation.
# These are dry exercises of the exact resolution calls the apply path makes,
# run inside module scope because the helpers are deliberately not exported.
# ---------------------------------------------------------------------------
$module = Get-Module LZFactory.Bootstrap
$resolveSubscription = {
    param($Config, $Environment)
    Get-LzEnvironmentSubscription -Config $Config -Environment $Environment
}
$resolveLayerEnvironment = {
    param($Config, $Layer)
    Get-LzLayerEnvironment -Config $Config -Layer $Layer
}

foreach ($model in @('minimal', 'per-environment')) {
    $cfgResolve = Get-SampleConfig
    $cfgResolve.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue $model
    $planResolve = New-LzBootstrapPlan -Config $cfgResolve
    $resolutionErrors = @()
    # Set-LzGitHubEnvironment path: one resolution per GitHub environment.
    foreach ($environment in @($planResolve.environments)) {
        try { & $module $resolveSubscription $cfgResolve $environment | Out-Null }
        catch { $resolutionErrors += "$environment -> $($_.Exception.Message)" }
    }
    # AZURE_SUBSCRIPTION_IDS path: one resolution per layer's environment.
    foreach ($layer in @($planResolve.layers)) {
        $layerEnvironment = & $module $resolveLayerEnvironment $cfgResolve $layer
        try { & $module $resolveSubscription $cfgResolve $layerEnvironment | Out-Null }
        catch { $resolutionErrors += "$layer ($layerEnvironment) -> $($_.Exception.Message)" }
    }
    ok "apply path resolves every default-export environment ($model model)" (
        $resolutionErrors.Count -eq 0
    ) ($resolutionErrors -join '; ')
}

# The chosen resolution rule: bootstrap anchors to the management subscription,
# because the global layer maps to the bootstrap environment and its azurerm
# provider is pinned to management_subscription_id.
$cfgRule = Get-SampleConfig
ok 'bootstrap environment anchors to the management subscription' (
    (& $module $resolveSubscription $cfgRule 'bootstrap') -eq $cfgRule.azure.subscriptions.management
)

# Full schema coverage: every environment name the schema can emit
# (unique(platform-enum + application-enum)) resolves without throwing,
# including optional planes that fall back to the management subscription.
$cfgFull = Get-SampleConfig
$cfgFull.environments.platform = @('bootstrap', 'identity', 'connectivity', 'management', 'shared-services')
$cfgFull.environments.application = @('sandbox', 'dev', 'test', 'uat', 'prod')
$fullErrors = @()
foreach ($model in @('minimal', 'per-environment')) {
    $cfgModel = Get-SampleConfig
    $cfgModel.environments.platform = $cfgFull.environments.platform
    $cfgModel.environments.application = $cfgFull.environments.application
    $cfgModel.identity | Add-Member -NotePropertyName cicdIdentityModel -NotePropertyValue $model
    $planFull = New-LzBootstrapPlan -Config $cfgModel
    foreach ($environment in @($planFull.environments)) {
        try { & $module $resolveSubscription $cfgModel $environment | Out-Null }
        catch { $fullErrors += "$model/$environment -> $($_.Exception.Message)" }
    }
}
ok 'every schema-emittable environment resolves in both models' ($fullErrors.Count -eq 0) ($fullErrors -join '; ')
ok 'optional planes fall back to the management subscription' (
    (& $module $resolveSubscription $cfgFull 'identity') -eq $cfgFull.azure.subscriptions.management -and
    (& $module $resolveSubscription $cfgFull 'shared-services') -eq $cfgFull.azure.subscriptions.management -and
    (& $module $resolveSubscription $cfgFull 'dev') -eq $cfgFull.azure.subscriptions.management
)

# Fail-closed default is preserved: an environment name outside the schema set
# must still throw rather than silently anchor somewhere unreviewed.
$unknownThrew = $false
try { & $module $resolveSubscription $cfgFull 'hub' | Out-Null }
catch { $unknownThrew = $true }
ok 'unknown environment still fails closed' $unknownThrew

# ---------------------------------------------------------------------------
# decision 0006 (operator-ratified 2026-08-07): broker-time resource-provider
# registration. One authoritative namespace list (Get-LzRequiredResourceProviders)
# consumed by the broker apply step, the PF-D preflight finding, and the
# Factory CI coverage check — these tests pin the list, the type->namespace
# mapping edge cases, target-subscription derivation, PF-D behavior through an
# injected read seam, and the CI check's pass/fail branches against the real
# corpus and seeded corpora (item-1.3 seeded-failure precedent).
# ---------------------------------------------------------------------------
$providerSpec = Get-LzRequiredResourceProviders
$expectedRequired = @(
    'Microsoft.Automation', 'Microsoft.DataProtection', 'Microsoft.Insights',
    'Microsoft.KeyVault', 'Microsoft.Management', 'Microsoft.Network',
    'Microsoft.OperationalInsights', 'Microsoft.PolicyInsights',
    'Microsoft.RecoveryServices', 'Microsoft.Security', 'Microsoft.Storage'
)
ok 'RP list is exactly decision 0006''s 11 namespaces' (
    (@($providerSpec.required | Sort-Object) -join ',') -eq ($expectedRequired -join ',')
) (@($providerSpec.required) -join ', ')
ok 'RP exclusions are explicit: Authorization and Resources only' (
    (@($providerSpec.excluded | Sort-Object) -join ',') -eq 'Microsoft.Authorization,Microsoft.Resources'
)
ok 'RP required and excluded sets are disjoint' (
    @($providerSpec.required | Where-Object { $_ -in @($providerSpec.excluded) }).Count -eq 0
)

# Mapping edge cases — the namespaces that are NOT Microsoft.<second-token>,
# plus one representative per straightforward family.
$mappingCases = @(
    @{ Type = 'azurerm_monitor_metric_alert';                       Namespace = 'Microsoft.Insights' }
    @{ Type = 'azurerm_application_insights';                       Namespace = 'Microsoft.Insights' }
    @{ Type = 'azurerm_log_analytics_workspace';                    Namespace = 'Microsoft.OperationalInsights' }
    @{ Type = 'azurerm_management_group';                           Namespace = 'Microsoft.Management' }
    @{ Type = 'azurerm_management_group_subscription_association';  Namespace = 'Microsoft.Management' }
    @{ Type = 'azurerm_management_group_policy_assignment';         Namespace = 'Microsoft.PolicyInsights' }
    @{ Type = 'azurerm_role_assignment';                            Namespace = 'Microsoft.Authorization' }
    @{ Type = 'azurerm_policy_definition';                          Namespace = 'Microsoft.Authorization' }
    @{ Type = 'azurerm_policy_set_definition';                      Namespace = 'Microsoft.Authorization' }
    @{ Type = 'azurerm_resource_group';                             Namespace = 'Microsoft.Resources' }
    @{ Type = 'azurerm_network_watcher_flow_log';                   Namespace = 'Microsoft.Network' }
    @{ Type = 'azurerm_firewall_policy';                            Namespace = 'Microsoft.Network' }
    @{ Type = 'azurerm_virtual_network_peering';                    Namespace = 'Microsoft.Network' }
    @{ Type = 'azurerm_private_dns_zone';                           Namespace = 'Microsoft.Network' }
    @{ Type = 'azurerm_storage_account';                            Namespace = 'Microsoft.Storage' }
    @{ Type = 'azurerm_key_vault';                                  Namespace = 'Microsoft.KeyVault' }
    @{ Type = 'azurerm_data_protection_backup_vault';               Namespace = 'Microsoft.DataProtection' }
    @{ Type = 'azurerm_recovery_services_vault';                    Namespace = 'Microsoft.RecoveryServices' }
    @{ Type = 'azurerm_security_center_subscription_pricing';       Namespace = 'Microsoft.Security' }
    @{ Type = 'azurerm_automation_runbook';                         Namespace = 'Microsoft.Automation' }
)
$mappingMisses = @(foreach ($case in $mappingCases) {
    $resolved = Resolve-LzResourceTypeNamespace -ResourceType $case.Type
    if ($resolved -ne $case.Namespace) { "$($case.Type) -> $resolved (expected $($case.Namespace))" }
})
ok 'type->namespace mapping resolves every edge case' ($mappingMisses.Count -eq 0) ($mappingMisses -join '; ')
ok 'client_config is a provider-context data source with no namespace' (
    $null -eq (Resolve-LzResourceTypeNamespace -ResourceType 'azurerm_client_config')
)
$unknownMessage = $null
try { Resolve-LzResourceTypeNamespace -ResourceType 'azurerm_kusto_cluster' | Out-Null }
catch { $unknownMessage = $_.Exception.Message }
ok 'unknown type fails closed with the extension pointer' (
    $unknownMessage -match 'azurerm_kusto_cluster' -and
    $unknownMessage -match 'Resolve-LzResourceTypeNamespace' -and
    $unknownMessage -match 'Get-LzRequiredResourceProviders' -and
    $unknownMessage -match 'decision 0006'
) $unknownMessage

# Target subscriptions: distinct across configured environments, plus the
# azurerm state backend subscription, deduplicated.
$resolveTargets = { param($Config) Get-LzTargetSubscriptions -Config $Config }
$targetsHcp = @(& $module $resolveTargets (Get-SampleConfig))
ok 'targets: fixture yields the 3 distinct subscriptions (bootstrap dedups into management)' (
    $targetsHcp.Count -eq 3 -and
    $targetsHcp -contains 'aaaaaaaa-0000-0000-0000-000000000001' -and
    $targetsHcp -contains 'aaaaaaaa-0000-0000-0000-000000000002' -and
    $targetsHcp -contains 'aaaaaaaa-0000-0000-0000-000000000003'
) ($targetsHcp -join ', ')
$targetsAzurerm = @(& $module $resolveTargets (ConvertTo-AzurermBackendConfig (Get-SampleConfig)))
ok 'targets: azurerm state backend subscription dedups into the same 3' ($targetsAzurerm.Count -eq 3)
$cfgTargetsSandbox = Add-SandboxSubscription (Get-SampleConfig)
$cfgTargetsSandbox.environments.application = @('prod', 'sandbox')
$targetsSandbox = @(& $module $resolveTargets $cfgTargetsSandbox)
ok 'targets: a sandbox environment adds its dedicated subscription' (
    $targetsSandbox.Count -eq 4 -and $targetsSandbox -contains $sandboxSub
) ($targetsSandbox -join ', ')

# PF-D through the injected read seam. Layers=@() isolates PF-D from PF-A..C.
$sampleConfigPath = "$PSScriptRoot/fixtures/sample-config.json"
$allRegisteredReader = {
    param([string]$SubscriptionId)
    @($expectedRequired | ForEach-Object { [pscustomobject]@{ namespace = $_; state = 'Registered' } })
}
$pfdClean = @(Test-LzFirstApplyPreflight -Config (Get-SampleConfig) -ConfigPath $sampleConfigPath -Layers @() -ProviderStateReader $allRegisteredReader)
ok 'PF-D: fully registered subscriptions yield no findings' (
    @($pfdClean | Where-Object { $_.id -like 'PF-D*' }).Count -eq 0
) ($pfdClean | ConvertTo-Json -Compress)

$partialReader = {
    param([string]$SubscriptionId)
    @($expectedRequired | ForEach-Object {
        $state = if ($_ -eq 'Microsoft.Network' -and $SubscriptionId -eq 'aaaaaaaa-0000-0000-0000-000000000002') { 'NotRegistered' } else { 'Registered' }
        [pscustomobject]@{ namespace = $_; state = $state }
    })
}
$pfdPartial = @(Test-LzFirstApplyPreflight -Config (Get-SampleConfig) -ConfigPath $sampleConfigPath -Layers @() -ProviderStateReader $partialReader)
$pfdWarnings = @($pfdPartial | Where-Object id -eq 'PF-D1')
ok 'PF-D: one WARN per subscription with unregistered namespaces' (
    $pfdWarnings.Count -eq 1 -and $pfdWarnings[0].severity -eq 'WARN'
) ($pfdPartial | ConvertTo-Json -Compress)
ok 'PF-D: finding names the subscription, the namespace, and the failure mode' (
    $pfdWarnings.Count -eq 1 -and
    $pfdWarnings[0].message -match 'aaaaaaaa-0000-0000-0000-000000000002' -and
    $pfdWarnings[0].message -match 'Microsoft\.Network' -and
    $pfdWarnings[0].message -match 'MissingSubscriptionRegistration'
)
ok 'PF-D: remediation carries the exact az provider register command' (
    $pfdWarnings.Count -eq 1 -and
    $pfdWarnings[0].remediation -match [regex]::Escape('az provider register --namespace Microsoft.Network --subscription aaaaaaaa-0000-0000-0000-000000000002')
)

$unreadableReader = { param([string]$SubscriptionId) $null }
$pfdUnverified = @(Test-LzFirstApplyPreflight -Config (Get-SampleConfig) -ConfigPath $sampleConfigPath -Layers @() -ProviderStateReader $unreadableReader)
$pfdSkips = @($pfdUnverified | Where-Object id -eq 'PF-D0')
ok 'PF-D: unreadable provider state degrades to a single INFO finding, never an error' (
    $pfdSkips.Count -eq 1 -and $pfdSkips[0].severity -eq 'INFO' -and
    @($pfdUnverified | Where-Object id -eq 'PF-D1').Count -eq 0
)
ok 'PF-D: the skip finding lists every unverified subscription and points at the broker step' (
    $pfdSkips.Count -eq 1 -and
    @($targetsHcp | Where-Object { $pfdSkips[0].message -notmatch [regex]::Escape($_) }).Count -eq 0 -and
    $pfdSkips[0].remediation -match 'broker'
)

# Plan-mode broker run end to end (no az, no gh): the audit file must record
# the registration INTENT — status planned, the 11 namespaces, the target
# subscriptions — and the preflight array must carry the PF-D0 degradation
# (az is unavailable in this environment; that absence is the test).
$planModeOut = Join-Path $PSScriptRoot '.out/rp-plan-mode'
if (Test-Path $planModeOut) { Remove-Item $planModeOut -Recurse -Force }
New-Item -ItemType Directory -Path $planModeOut -Force | Out-Null
@'
{ "readOnly": true, "readiness": { "failCount": 0 } }
'@ | Set-Content (Join-Path $planModeOut 'discovery.json') -Encoding utf8
$bootstrapResult = Invoke-LzBootstrap -ConfigPath $sampleConfigPath -DiscoveryPath (Join-Path $planModeOut 'discovery.json') -OutputDirectory $planModeOut
$auditRecord = Get-Content $bootstrapResult.AuditPath -Raw | ConvertFrom-Json -Depth 40
ok 'plan-mode audit records registration intent as planned' (
    $auditRecord.resourceProviders.status -eq 'planned'
)
ok 'plan-mode audit intent carries the full namespace list and target subscriptions' (
    (@($auditRecord.resourceProviders.requiredNamespaces | Sort-Object) -join ',') -eq ($expectedRequired -join ',') -and
    @($auditRecord.resourceProviders.subscriptions).Count -eq 3
)
ok 'plan-mode audit preflight degrades PF-D to the unverified INFO finding' (
    @($auditRecord.preflight | Where-Object { $_.id -eq 'PF-D0' }).Count -eq 1
)
ok 'plan mode stays non-mutating (mode recorded as plan)' ($auditRecord.mode -eq 'plan')

# State blobs (decision 0031): plan mode records the INTENT in the audit, and only there.
# bootstrap-plan.json is under a byte-parity contract with pre-change fixtures, so it must not change.
$planRecord = Get-Content (Join-Path $planModeOut 'bootstrap-plan.json') -Raw | ConvertFrom-Json -Depth 40
$planLayersForBlobs = @($planRecord.layers)
ok 'plan-mode audit lists the per-layer state blobs apply would create' (
    $planLayersForBlobs.Count -gt 0 -and
    (@($auditRecord.backend.stateBlobs | ForEach-Object { $_.key }) -join ',') -eq ((@($planLayersForBlobs | ForEach-Object { "$_.tfstate" })) -join ',') -and
    @($auditRecord.backend.stateBlobs | Where-Object { $_.status -ne 'planned' }).Count -eq 0
)
ok 'bootstrap-plan.json carries no state-blob detail (its byte-parity contract)' (
    (Get-Content (Join-Path $planModeOut 'bootstrap-plan.json') -Raw) -notmatch 'stateBlobs|\.tfstate'
)

# Factory CI coverage check: green against the REAL corpus, and the seeded
# failure modes fire (item-1.3 precedent: prove the check fails, do not trust
# a check that has only ever passed).
$coverageScript = "$repo/factory/ci/Test-ResourceProviderCoverage.ps1"
$coverageOutput = @(& $coverageScript *>&1 | ForEach-Object { "$_" })
$coverageExit = $LASTEXITCODE
ok 'coverage check passes on the real template corpus' ($coverageExit -eq 0) ($coverageOutput -join ' | ')
ok 'coverage check names KeyVault as a deliberate broker look-ahead, not drift' (
    ($coverageOutput -join ' ') -match 'ahead of the corpus' -and ($coverageOutput -join ' ') -match 'Microsoft\.KeyVault'
)

$coverageSeed = Join-Path $PSScriptRoot '.out/rp-coverage-seed'
if (Test-Path $coverageSeed) { Remove-Item $coverageSeed -Recurse -Force }
New-Item -ItemType Directory -Path $coverageSeed -Force | Out-Null
@'
resource "azurerm_storage_account" "seeded" {
  name = "seed"
}
'@ | Set-Content (Join-Path $coverageSeed 'seed.tf') -Encoding utf8
$seededOutput = @(& $coverageScript -TemplateRoot $coverageSeed -RequiredNamespaces @('Microsoft.Network') *>&1 | ForEach-Object { "$_" })
$seededExit = $LASTEXITCODE
ok 'seeded mismatch fails the coverage check' ($seededExit -eq 1) ($seededOutput -join ' | ')
ok 'mismatch finding names the type, the namespace, and the extension point' (
    ($seededOutput -join ' ') -match 'azurerm_storage_account' -and
    ($seededOutput -join ' ') -match 'Microsoft\.Storage' -and
    ($seededOutput -join ' ') -match 'Get-LzRequiredResourceProviders'
)

$unmappedSeed = Join-Path $PSScriptRoot '.out/rp-unmapped-seed'
if (Test-Path $unmappedSeed) { Remove-Item $unmappedSeed -Recurse -Force }
New-Item -ItemType Directory -Path $unmappedSeed -Force | Out-Null
@'
resource "azurerm_kusto_cluster" "seeded" {
  name = "seed"
}
'@ | Set-Content (Join-Path $unmappedSeed 'seed.tf.tmpl') -Encoding utf8
$unmappedOutput = @(& $coverageScript -TemplateRoot $unmappedSeed *>&1 | ForEach-Object { "$_" })
$unmappedExit = $LASTEXITCODE
ok 'an unmapped type (in a .tf.tmpl) fails the coverage check' ($unmappedExit -eq 1) ($unmappedOutput -join ' | ')
ok 'unmapped finding tells the author where to extend the mapping' (
    ($unmappedOutput -join ' ') -match 'azurerm_kusto_cluster' -and
    ($unmappedOutput -join ' ') -match 'Resolve-LzResourceTypeNamespace'
)


# ---------------------------------------------------------------------------
# State blob initialisation (decision 0031, issue #140). Terraform's azurerm backend writes an
# empty state the first time it initialises a layer whose blob does not exist, which the read-only
# plan identity cannot do. The broker therefore creates any missing blob under the operator's
# session. These tests pin the file format, the never-overwrite rule, and the contract with the
# backend.hcl template.
# ---------------------------------------------------------------------------
$emptyStateBlock = { param($Version) New-LzEmptyTerraformState -TerraformVersion $Version }
$stateVersionBlock = { Get-LzStateFileTerraformVersion }
$stateKeyBlock = { param($Layer) Get-LzStateBlobKey -Layer $Layer }
$initBlobsBlock = { param($Config, $Layers) Initialize-LzStateBlobs -Config $Config -Layers $Layers }

$stateText = & $module $emptyStateBlock '1.12.0'
$stateObject = $stateText | ConvertFrom-Json -Depth 10
$lineageGuid = [guid]::Empty
ok 'the empty state is Terraform state format 4' ($stateObject.version -eq 4)
ok 'the empty state records the version it is given' ($stateObject.terraform_version -eq '1.12.0')
ok 'the empty state starts at serial 1, as Terraform writes a first state' ($stateObject.serial -eq 1)
ok 'the empty state carries a real lineage' ([guid]::TryParse([string]$stateObject.lineage, [ref]$lineageGuid))
ok 'the empty state has no outputs and no resources' (
    @($stateObject.outputs.PSObject.Properties).Count -eq 0 -and @($stateObject.resources).Count -eq 0
)
ok 'the empty state has exactly the keys Terraform writes' (
    (($stateObject.PSObject.Properties.Name | Sort-Object) -join ',') -eq 'check_results,lineage,outputs,resources,serial,terraform_version,version'
)
ok 'check_results is null, as Terraform writes it' ($null -eq $stateObject.check_results)
ok 'the state text has no byte-order mark and ends with a newline' (
    $stateText[0] -ne [char]0xFEFF -and $stateText[$stateText.Length - 1] -eq [char]10
)
ok 'every blob gets its own lineage' (
    $stateObject.lineage -ne ((& $module $emptyStateBlock '1.12.0') | ConvertFrom-Json).lineage
)

$factoryVersionDoc = Get-Content "$repo/factory-version.json" -Raw | ConvertFrom-Json
$requiredMinimum = [regex]::Match([string]$factoryVersionDoc.toolchain.terraform.required, '>=\s*(\d+\.\d+\.\d+)').Groups[1].Value
ok 'the state file records the MINIMUM supported Terraform version' (
    $requiredMinimum -ne '' -and (& $module $stateVersionBlock) -eq $requiredMinimum
)

# The real Terraform binary must accept the file. Read-only commands only. Skipped (not passed)
# when terraform is not installed, and the check is shown to be able to fail.
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    $tfProof = Join-Path $PSScriptRoot '.out/state-blob-terraform'
    if (Test-Path $tfProof) { Remove-Item $tfProof -Recurse -Force }
    New-Item -ItemType Directory -Path $tfProof -Force | Out-Null
    "terraform {`n  required_version = `">= 1.12.0`"`n}`n" | Set-Content (Join-Path $tfProof 'main.tf') -Encoding utf8NoBOM
    (& $module $emptyStateBlock $requiredMinimum) | Set-Content (Join-Path $tfProof 'terraform.tfstate') -Encoding utf8NoBOM -NoNewline
    Push-Location $tfProof
    try {
        $tfShow = @(& terraform show -no-color 2>&1); $tfShowExit = $LASTEXITCODE
        $tfList = @(& terraform state list 2>&1); $tfListExit = $LASTEXITCODE
        '{ "version": 4, "serial": 1 ' | Set-Content 'terraform.tfstate' -Encoding utf8NoBOM
        $tfBad = @(& terraform state list 2>&1); $tfBadExit = $LASTEXITCODE
    }
    finally { Pop-Location }
    ok 'real Terraform accepts the generated state (show)' ($tfShowExit -eq 0 -and ($tfShow -join ' ') -match 'state file is empty')
    ok 'real Terraform accepts the generated state (state list)' ($tfListExit -eq 0 -and $tfList.Count -eq 0)
    ok 'the same check rejects a corrupt state, so it can fail' ($tfBadExit -ne 0)
    Remove-Item $tfProof -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Host 'SKIP real-Terraform acceptance of the generated state (terraform is not installed here)'
}

# Cross-file contract: the broker creates exactly the blob Terraform will look for. If
# backend.hcl.tmpl's key ever changed, the blobs created here would silently be the wrong ones.
$backendHclTemplate = Get-Content "$repo/factory/templates/terraform/live/_layer/backend.hcl.tmpl" -Raw
$keyMatch = [regex]::Match($backendHclTemplate, '(?m)^key\s*=\s*"\{\{FACTORY-RAW:layer\}\}(?<suffix>[^"]*)"')
ok 'backend.hcl.tmpl names each layer''s state blob <layer>.tfstate' ($keyMatch.Success -and $keyMatch.Groups['suffix'].Value -eq '.tfstate')
$allLayers = @('platform-management', 'global', 'platform-connectivity', 'state-hardening')
ok 'the broker names the same blob as the template, for every layer the factory can emit' (
    @($allLayers | Where-Object { (& $module $stateKeyBlock $_) -ne ($_ + $keyMatch.Groups['suffix'].Value) }).Count -eq 0
)
$brokerSource = Get-Content "$repo/factory/bootstrap/LZFactory.Bootstrap.psm1" -Raw
ok 'apply hands the plan''s layers to the backend step (static wiring check)' (
    $brokerSource -match 'Set-LzAzurermBackend -Config \$config -Layers @\(\$plan\.layers\)'
)

# --- Initialize-LzStateBlobs against a recording fake of the az CLI --------------------------
function global:az {
    $callArgs = @($args)
    $global:LzFakeAz.Calls += , $callArgs
    $global:LASTEXITCODE = 0
    if ($callArgs[0] -eq 'storage' -and $callArgs[1] -eq 'blob' -and $callArgs[2] -eq 'exists') {
        if ($global:LzFakeAz.ExistsFails) { $global:LASTEXITCODE = 1; return 'ERROR: AuthorizationPermissionMismatch' }
        $name = $callArgs[[array]::IndexOf($callArgs, '--name') + 1]
        return (@{ exists = ($global:LzFakeAz.Existing -contains $name) } | ConvertTo-Json -Compress)
    }
    if ($callArgs[0] -eq 'storage' -and $callArgs[1] -eq 'blob' -and $callArgs[2] -eq 'upload') {
        $name = $callArgs[[array]::IndexOf($callArgs, '--name') + 1]
        $file = $callArgs[[array]::IndexOf($callArgs, '--file') + 1]
        $global:LzFakeAz.Uploaded[$name] = Get-Content -LiteralPath $file -Raw
        if ($global:LzFakeAz.UploadError) { $global:LASTEXITCODE = 1; return $global:LzFakeAz.UploadError }
        return
    }
    $global:LASTEXITCODE = 1
    return "unexpected az call: $($callArgs -join ' ')"
}
function Invoke-FakeAzScenario {
    param([string[]]$Layers, [string[]]$Existing = @(), $UploadError = $null, [bool]$ExistsFails = $false)
    $global:LzFakeAz = @{ Calls = @(); Existing = @($Existing); Uploaded = @{}; UploadError = $UploadError; ExistsFails = $ExistsFails }
    $outcome = [pscustomobject]@{ Results = @(); Error = $null; Fake = $null }
    try { $outcome.Results = @(& $module $initBlobsBlock (Get-SampleConfig) $Layers) }
    catch { $outcome.Error = $_.Exception.Message }
    $outcome.Fake = $global:LzFakeAz
    return $outcome
}
function Get-FakeArg($Call, [string]$Flag) { $Call[[array]::IndexOf($Call, $Flag) + 1] }

try {
    $blobConfig = Get-SampleConfig
    $blobAccount = $blobConfig.backend.azurerm.storageAccountName
    $blobContainer = if ($blobConfig.backend.azurerm.PSObject.Properties['containerName']) { $blobConfig.backend.azurerm.containerName } else { 'tfstate' }
    $three = @('platform-management', 'global', 'platform-connectivity')

    # A: nothing exists -> one create-only upload per layer.
    $a = Invoke-FakeAzScenario -Layers $three
    $aUploads = @($a.Fake.Calls | Where-Object { $_[2] -eq 'upload' })
    ok 'no blobs exist: one upload per layer, all reported initialized' (
        $null -eq $a.Error -and $aUploads.Count -eq 3 -and @($a.Results | Where-Object { $_.status -eq 'initialized' }).Count -eq 3
    ) $a.Error
    ok 'each upload names the right account, container and <layer>.tfstate blob' (
        (@($aUploads | ForEach-Object { Get-FakeArg $_ '--name' }) -join ',') -eq (($three | ForEach-Object { "$_.tfstate" }) -join ',') -and
        @($aUploads | Where-Object { (Get-FakeArg $_ '--account-name') -ne $blobAccount -or (Get-FakeArg $_ '--container-name') -ne $blobContainer }).Count -eq 0
    )
    ok 'every upload is create-only (--overwrite false), never true' (
        @($aUploads | Where-Object { (Get-FakeArg $_ '--overwrite') -ne 'false' }).Count -eq 0
    )
    ok 'every az call authenticates with the operator login, and no key or SAS is ever used' (
        @($a.Fake.Calls | Where-Object { (Get-FakeArg $_ '--auth-mode') -ne 'login' }).Count -eq 0 -and
        @($a.Fake.Calls | Where-Object { ($_ -join ' ') -match 'account-key|sas-token|connection-string' }).Count -eq 0
    )
    $uploadedStates = @($a.Fake.Uploaded.Keys | ForEach-Object { $a.Fake.Uploaded[$_] | ConvertFrom-Json })
    ok 'the uploaded content is a valid empty Terraform state with its own lineage per blob' (
        $uploadedStates.Count -eq 3 -and
        @($uploadedStates | Where-Object { $_.version -ne 4 -or $_.serial -ne 1 -or @($_.resources).Count -ne 0 }).Count -eq 0 -and
        @($uploadedStates | ForEach-Object { $_.lineage } | Select-Object -Unique).Count -eq 3
    )
    ok 'the content type is JSON' (@($aUploads | Where-Object { (Get-FakeArg $_ '--content-type') -ne 'application/json' }).Count -eq 0)

    # B: one blob already exists -> it is left completely alone.
    $b = Invoke-FakeAzScenario -Layers $three -Existing @('global.tfstate')
    $bUploadNames = @($b.Fake.Calls | Where-Object { $_[2] -eq 'upload' } | ForEach-Object { Get-FakeArg $_ '--name' })
    ok 'an existing blob is never uploaded to' ($bUploadNames -notcontains 'global.tfstate' -and $bUploadNames.Count -eq 2)
    ok 'an existing blob is reported as existing, the others as initialized' (
        ($b.Results | Where-Object { $_.key -eq 'global.tfstate' }).status -eq 'exists' -and
        @($b.Results | Where-Object { $_.status -eq 'initialized' }).Count -eq 2
    )
    ok 'nothing is ever deleted or overwritten' (
        @($b.Fake.Calls + $a.Fake.Calls | Where-Object { ($_ -join ' ') -match 'delete|--overwrite true|--overwrite True' }).Count -eq 0
    )

    # C: every blob exists (the re-run case) -> no upload at all.
    $c = Invoke-FakeAzScenario -Layers $three -Existing @($three | ForEach-Object { "$_.tfstate" })
    ok 're-running changes nothing: every blob exists, so there are no uploads' (
        @($c.Fake.Calls | Where-Object { $_[2] -eq 'upload' }).Count -eq 0 -and @($c.Results | Where-Object { $_.status -eq 'exists' }).Count -eq 3
    )

    # D: another run creates the blob between our check and our upload -> fine, untouched.
    $d = Invoke-FakeAzScenario -Layers @('global') -UploadError 'ERROR: BlobAlreadyExists The specified blob already exists.'
    ok 'a blob created in the meantime is treated as existing, not as a failure' ($null -eq $d.Error -and $d.Results[0].status -eq 'exists') $d.Error

    # E: no permission to write -> a clear error that names the role.
    $e = Invoke-FakeAzScenario -Layers @('global') -UploadError 'ERROR: AuthorizationPermissionMismatch This request is not authorized to perform this operation using this permission.'
    ok 'an upload that is not authorized fails loudly and names Storage Blob Data Contributor' (
        $e.Error -match 'Storage Blob Data Contributor' -and $e.Error -match 'global\.tfstate'
    ) $e.Error
    $f = Invoke-FakeAzScenario -Layers @('global') -ExistsFails $true
    ok 'a check that is not authorized fails loudly and names Storage Blob Data Contributor' (
        $f.Error -match 'Storage Blob Data Contributor' -and $f.Error -match 'global\.tfstate'
    ) $f.Error

    # F: no layers -> no az call at all.
    $g = Invoke-FakeAzScenario -Layers @()
    ok 'with no layers the step does nothing' ($null -eq $g.Error -and $g.Fake.Calls.Count -eq 0 -and $g.Results.Count -eq 0)
}
finally {
    Remove-Item Function:\global:az -ErrorAction SilentlyContinue
    Remove-Variable LzFakeAz -Scope Global -ErrorAction SilentlyContinue
}

Write-Host "$pass passed, $fail failed"
exit $(if ($fail) { 1 } else { 0 })
