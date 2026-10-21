#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# The wizard (site/) is published to GitHub Pages (deploy-pages.yml) and must make
# no network requests. (The legacy frontend/ page was retired by decision 0032.)
$scanRoots = @(
    (Join-Path $repo 'site')
)
$findings = @()
$patterns = [ordered]@{
    '\bfetch\s*\(' = 'fetch'
    '\b(?:new\s+)?XMLHttpRequest\s*\(' = 'XMLHttpRequest'
    '\bWebSocket\s*\(' = 'WebSocket'
    '\bEventSource\s*\(' = 'EventSource'
    '\bsendBeacon\s*\(' = 'sendBeacon'
    '\bimport\s*\(' = 'dynamic import'
    '<script[^>]+src\s*=\s*["'']https?://' = 'external script'
    '<link[^>]+href\s*=\s*["'']https?://' = 'external stylesheet'
    '<(?:img|iframe|audio|video|source)[^>]+src\s*=\s*["'']https?://' = 'external media'
    '<form[^>]+action\s*=\s*["'']https?://' = 'external form action'
    'url\s*\(\s*["'']?https?://' = 'external CSS asset'
}
$allFiles = @($scanRoots | Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ -Recurse -File -Include *.js,*.html,*.css })
foreach ($file in $allFiles) {
    $text = Get-Content $file.FullName -Raw
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($text -match $entry.Key) {
            $findings += [pscustomobject]@{
                file = $file.FullName.Substring($repo.Length).TrimStart('\', '/')
                policy = $entry.Value
            }
        }
    }
}
if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize
    throw 'The static wizard contains a forbidden network primitive.'
}
Write-Host 'Site no-network policy passed.'
