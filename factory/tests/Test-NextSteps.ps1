#Requires -Version 7.0
# Wizard NEXT-STEPS.md command contract.
#
# The wizard (site/app.js, nextStepsMarkdown) writes a command sheet that an operator
# follows line by line. Nothing used to check that sheet against the scripts it names,
# so it could (and did) drift: guide page 03 once warned that it listed flags that do
# not exist. This test renders the sheet for every configuration that changes its text
# and checks each script path, each flag, each allowed value and each LZ_* environment
# variable against the real source. A flag is checked against the script of the section
# it appears in, so a flag that exists on a different script still fails.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$pass = 0; $fail = 0
function ok($name, $condition, $extra) {
    if ($condition) { $script:pass++; Write-Host "  PASS $name" -ForegroundColor Green }
    else {
        $script:fail++
        Write-Host "  FAIL $name$(if ($extra) { "  -> $extra" })" -ForegroundColor Red
    }
}

# --- 1. Render NEXT-STEPS.md for each variant, with the wizard's own test harness -----------
$work = Join-Path ([IO.Path]::GetTempPath()) ("lz-next-steps-test-" + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $work)
try {
    $js = @'
const A = require(process.argv[2]);
const clone = (o) => JSON.parse(JSON.stringify(o));
const base = A.buildConfig();
const variants = {};
variants.create = clone(base);
variants.existing = clone(base);
variants.existing.azure.subscriptions.mode = 'existing';
variants.privateEndpoint = clone(base);
variants.privateEndpoint.backend.type = 'azurerm';
variants.privateEndpoint.backend.azurerm.privateEndpoint = { enabled: true };
variants.brownfield = clone(base);
variants.brownfield.deploymentStrategy.mode = 'brownfield';
const out = {};
for (const [name, cfg] of Object.entries(variants)) out[name] = A.nextStepsMarkdown(cfg);
require('fs').writeFileSync(process.argv[3], JSON.stringify(out), 'utf8');
'@
    $jsPath = Join-Path $work 'render.js'
    $outPath = Join-Path $work 'next-steps.json'
    Set-Content -LiteralPath $jsPath -Value $js -Encoding utf8NoBOM
    & node $jsPath (Join-Path $repo 'factory/tests/harness.js') $outPath
    if ($LASTEXITCODE -ne 0) { throw "node failed to render NEXT-STEPS.md (exit $LASTEXITCODE)." }
    $rendered = Get-Content -LiteralPath $outPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 2. What each section's command is allowed to accept, read from the real source ----------
function Get-ParameterInfo([string]$RelativePath, [string]$Function) {
    $path = Join-Path $repo $RelativePath
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "$RelativePath does not parse: $($errors[0].Message)" }
    if ($Function) {
        $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Function }, $true)
        if (-not $fn) { throw "$Function not found in $RelativePath." }
        $block = $fn.Body.ParamBlock
    }
    else { $block = $ast.ParamBlock }
    $info = @{}
    foreach ($parameter in @($block.Parameters)) {
        $allowed = @()
        foreach ($attribute in $parameter.Attributes) {
            if ($attribute -is [System.Management.Automation.Language.AttributeAst] -and $attribute.TypeName.Name -eq 'ValidateSet') {
                $allowed = @($attribute.PositionalArguments | ForEach-Object { $_.Value })
            }
        }
        $info[$parameter.Name.VariablePath.UserPath] = $allowed
    }
    $info
}

# Section title (after "## N. ") -> the script it drives.
$sections = @(
    @{ Title = '^Create the subscriptions'; Path = 'scripts/New-LzSubscriptions.ps1'; Function = $null }
    @{ Title = '^Run discovery';            Path = 'factory/discovery/Invoke-Discovery.ps1'; Function = $null }
    @{ Title = '^Bootstrap';                Path = 'bootstrap-broker.ps1'; Function = $null }
    @{ Title = '^Render';                   Path = 'factory/renderer/public/Invoke-LzRender.ps1'; Function = 'Invoke-LzRender' }
    @{ Title = '^Scaffold';                 Path = 'scaffold-copy.ps1'; Function = $null }
)
foreach ($section in $sections) {
    $section.Parameters = Get-ParameterInfo $section.Path $section.Function
}

# Every LZ_* variable the sheet mentions must exist somewhere in the real scripts and modules.
$sourceText = (Get-ChildItem -LiteralPath $repo -Recurse -File -Include *.ps1, *.psm1, *.sh -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|site|tests)[\\/]' } |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

# --- 3. Check every variant ------------------------------------------------------------------
foreach ($variant in $rendered.Keys | Sort-Object) {
    Write-Host "`n== NEXT-STEPS.md ($variant) ==" -ForegroundColor Cyan
    $markdown = [string]$rendered[$variant]
    $parts = [regex]::Split($markdown, '(?m)^## \d+\. ')
    $found = 0

    foreach ($part in $parts | Select-Object -Skip 1) {
        $title = ($part -split "`r?`n", 2)[0]
        $section = $sections | Where-Object { $title -match $_.Title } | Select-Object -First 1
        if (-not $section) { continue }
        $found++

        # pwsh's own switches (pwsh -Command ...) belong to the shell, not to the script being called.
        $scanText = [regex]::Replace($part, 'pwsh\s+-(?:Command|NoProfile|NoLogo|File)\b', 'pwsh')
        $flags = @([regex]::Matches($scanText, '(?<![\w-])-([A-Za-z][A-Za-z0-9]*)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $unknown = @($flags | Where-Object { -not $section.Parameters.ContainsKey($_) })
        ok "'$title': every flag exists on $($section.Path)" ($unknown.Count -eq 0) ("not a parameter: -" + ($unknown -join ', -'))
        ok "'$title': the sheet shows at least one command flag" ($flags.Count -gt 0)

        foreach ($match in [regex]::Matches($part, '-(?<name>[A-Za-z][A-Za-z0-9]*)\s+(?<value>[A-Za-z]+(?:,[A-Za-z]+)*)')) {
            $name = $match.Groups['name'].Value
            if ($section.Parameters.ContainsKey($name) -and @($section.Parameters[$name]).Count -gt 0) {
                $bad = @($match.Groups['value'].Value -split ',' | Where-Object { $_ -notin $section.Parameters[$name] })
                ok "'$title': -$name only uses allowed values" ($bad.Count -eq 0) ("not allowed: " + ($bad -join ', '))
            }
        }
    }

    # 'existing' subscriptions skips the vending section; every other variant has all five.
    $expectedSections = if ($variant -eq 'existing') { 4 } else { 5 }
    ok "the sheet has the $expectedSections command sections this check covers" ($found -eq $expectedSections) "found $found"

    foreach ($scriptPath in [regex]::Matches($markdown, '(?<![\w/.])\./((?:[\w.-]+/)*[\w.-]+\.(?:ps1|psd1))') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) {
        if ($scriptPath -like 'generated-output/*') { continue }
        ok "path exists: $scriptPath" (Test-Path -LiteralPath (Join-Path $repo $scriptPath))
    }

    $variables = @([regex]::Matches($markdown, '\bLZ_[A-Z0-9_]+\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $missing = @($variables | Where-Object { $sourceText -notmatch ('\b' + [regex]::Escape($_) + '\b') })
    ok "every LZ_* variable the sheet names is read by a real script ($($variables.Count) checked)" ($missing.Count -eq 0) ("unknown: " + ($missing -join ', '))
}

Write-Host "`n== Results: $pass passed, $fail failed ==" -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }
