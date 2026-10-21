#Requires -Version 7.0
# Documentation-site contract (factory/docs-site/Build-DocsSite.ps1).
# Part 1 drives the builder against a tiny throwaway repository so every rule the
# build enforces is shown to FAIL the build when broken. Part 2 builds the real
# docs and checks every generated page: it is what stops a pull request that
# breaks a docs link from reaching the published site.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$builder = Join-Path $repo 'factory/docs-site/Build-DocsSite.ps1'
$realConfig = Join-Path $repo 'factory/docs-site/docs-site.json'
$pass = 0; $fail = 0
function ok($name, $condition) {
    if ($condition) { $script:pass++; Write-Host "  PASS $name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  FAIL $name" -ForegroundColor Red }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("lz-docs-site-test-" + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $work)

function Write-Text([string]$Root, [string]$Relative, [string]$Text) {
    $path = Join-Path $Root $Relative
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent))
    Set-Content -LiteralPath $path -Value $Text -Encoding utf8NoBOM
}

function New-Fixture {
    param([string]$Name)
    $root = Join-Path $work $Name
    Write-Text $root 'docs/guide/README.md' @'
# Guide

See [one](one.md), [a section](one.md#second-part), [the notes](../notes/),
[the todo](../../TODO.md#top-task), [a script](../../scripts/x.ps1),
[outside](https://example.com/page) and [mail](mailto:a@b.example).
'@
    Write-Text $root 'docs/guide/one.md' (@'
# One

## Second part

First. Prose may MENTION `javascript:` links and say one = 1 or onclick = x without tripping the safety rules.

## Second part

Second. [Jump](#second-part-1)

## 1. Fork (or copy) the factory

## A {EMDASH} B
'@).Replace('{EMDASH}', [string][char]0x2014)
    Write-Text $root 'docs/notes/a.md' "# Note A`n`nBody."
    Write-Text $root 'TODO.md' '# Todo'
    Write-Text $root 'scripts/x.ps1' '# script'
    Write-Text $root 'config.json' @'
{
  "title": "Fixture docs",
  "intro": "A fixture.",
  "sections": [
    { "id": "guide", "title": "Guide", "description": "The guide.", "dir": "docs/guide" },
    { "id": "notes", "title": "Notes", "description": "The notes.", "dir": "docs/notes" }
  ]
}
'@
    return $root
}

function Invoke-Build {
    param([string]$Root, [string]$OutName, [string[]]$Extra = @())
    $out = Join-Path $work $OutName
    $text = (& pwsh -NoLogo -NoProfile -File $builder -RepoRoot $Root -ConfigPath (Join-Path $Root 'config.json') `
            -OutputPath $out -Repository 'o/r' -Ref 'abc123' @Extra 2>&1 | Out-String)
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = $text; Out = $out }
}

function Get-TreeHash([string]$Dir) {
    (Get-ChildItem -LiteralPath $Dir -Recurse -File | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Dir, $_.FullName)):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    }) -join "`n"
}

try {
    Write-Host "`n== Builder rules (fixture repository) ==" -ForegroundColor Cyan
    $fx = New-Fixture 'good'
    $good = Invoke-Build $fx 'good-out'
    ok 'a clean fixture builds' ($good.Exit -eq 0)
    $guideIndex = Get-Content (Join-Path $good.Out 'guide/index.html') -Raw
    $one = Get-Content (Join-Path $good.Out 'guide/one.html') -Raw
    ok 'README becomes index.html' (Test-Path (Join-Path $good.Out 'guide/index.html'))
    ok 'link to another page becomes a relative .html link' ($guideIndex -match 'href="one\.html"')
    ok 'link keeps its anchor' ($guideIndex -match 'href="one\.html#second-part"')
    ok 'link to a section directory becomes that section index' ($guideIndex -match 'href="\.\./notes/index\.html"')
    ok 'section without a README gets a generated index listing its pages' (
        (Test-Path (Join-Path $good.Out 'notes/index.html')) -and ((Get-Content (Join-Path $good.Out 'notes/index.html') -Raw) -match 'Note A'))
    ok 'link outside the site becomes a GitHub link at the given ref, with its anchor' ($guideIndex -match 'href="https://github\.com/o/r/blob/abc123/TODO\.md#top-task"')
    ok 'link to a script becomes a GitHub link' ($guideIndex -match 'href="https://github\.com/o/r/blob/abc123/scripts/x\.ps1"')
    ok 'external links are left alone and marked noopener' ($guideIndex -match 'rel="noopener" href="https://example\.com/page"')
    ok 'mailto links are left alone' ($guideIndex -match 'href="mailto:a@b\.example"')
    ok 'duplicate headings get -1 like GitHub' ($one -match 'id="second-part"' -and $one -match 'id="second-part-1"')
    ok 'heading ids follow GitHub (digits and punctuation)' ($one -match 'id="1-fork-or-copy-the-factory"')
    ok 'heading ids follow GitHub (dash between words)' ($one -match 'id="a--b"')
    ok 'sub-headings carry a permalink' ($one -match 'class="anchor" href="#second-part"')
    ok 'pages carry an edit link and the source link' ($one -match 'edit/main/docs/guide/one\.md')
    ok 'the stylesheet is written once, locally' (Test-Path (Join-Path $good.Out 'assets/docs.css'))
    ok 'every page sets a restrictive content-security policy' ($one -match "default-src 'none'")

    $again = Invoke-Build $fx 'good-out-2'
    ok 'building twice gives byte-identical output' ((Get-TreeHash $good.Out) -ceq (Get-TreeHash $again.Out))

    $cases = @(
        @{ Name = 'a broken link fails the build'; File = 'docs/guide/one.md'; Add = "`n[gone](missing.md)`n"; Expect = 'broken link' }
        @{ Name = 'a bad anchor fails the build'; File = 'docs/guide/one.md'; Add = "`n[x](#no-such-heading)`n"; Expect = 'anchor that does not exist' }
        @{ Name = 'an anchor missing on another page fails the build'; File = 'docs/guide/one.md'; Add = "`n[x](README.md#nope)`n"; Expect = 'anchor that does not exist' }
        @{ Name = 'a wrong-case link fails the build'; File = 'docs/guide/one.md'; Add = "`n[x](../../Scripts/x.ps1)`n"; Expect = '(broken link|letter case)' }
        @{ Name = 'a link that leaves the repository fails the build'; File = 'docs/guide/one.md'; Add = "`n[x](../../../outside.md)`n"; Expect = 'leaves the repository' }
        @{ Name = 'a script element fails the build'; File = 'docs/guide/one.md'; Add = "`n<script>alert(1)</script>`n"; Expect = 'does not allow' }
        @{ Name = 'an iframe fails the build'; File = 'docs/guide/one.md'; Add = "`n<iframe src=`"x`"></iframe>`n"; Expect = 'does not allow' }
        @{ Name = 'an inline event handler fails the build'; File = 'docs/guide/one.md'; Add = "`n<a href=`"#top`" onclick=`"x()`">y</a>`n"; Expect = 'event handler' }
        @{ Name = 'a javascript: link fails the build'; File = 'docs/guide/one.md'; Add = "`n[x](javascript:alert(1))`n"; Expect = 'javascript' }
        @{ Name = 'an image fails the build'; File = 'docs/guide/one.md'; Add = "`n![alt](pic.png)`n"; Expect = 'image' }
    )
    $n = 0
    foreach ($case in $cases) {
        $n++
        $bad = New-Fixture "bad$n"
        $path = Join-Path $bad $case.File
        Add-Content -LiteralPath $path -Value $case.Add -Encoding utf8NoBOM
        $r = Invoke-Build $bad "bad$n-out"
        ok $case.Name ($r.Exit -ne 0 -and $r.Text -match $case.Expect)
    }

    $noTitle = New-Fixture 'notitle'
    Write-Text $noTitle 'docs/guide/one.md' "Just text, no heading.`n"
    $r = Invoke-Build $noTitle 'notitle-out'
    ok 'a page with no top-level heading fails the build' ($r.Exit -ne 0 -and $r.Text -match 'no top-level heading')

    $reportAll = New-Fixture 'multi'
    Add-Content -LiteralPath (Join-Path $reportAll 'docs/guide/one.md') -Value "`n[a](nope1.md) [b](nope2.md)`n" -Encoding utf8NoBOM
    $r = Invoke-Build $reportAll 'multi-out'
    ok 'every problem is reported in one run, not just the first' ($r.Text -match 'nope1' -and $r.Text -match 'nope2')

    $full = Join-Path $work 'not-empty'
    Write-Text $full 'keep.txt' 'x'
    $r = & pwsh -NoLogo -NoProfile -File $builder -RepoRoot $fx -ConfigPath (Join-Path $fx 'config.json') -OutputPath $full 2>&1 | Out-String
    ok 'refuses to build into a directory that already has files' ($LASTEXITCODE -ne 0 -and (Test-Path (Join-Path $full 'keep.txt')) -and $r -match 'not empty')

    Write-Host "`n== The real documentation site ==" -ForegroundColor Cyan
    $real = Join-Path $work 'real'
    $text = (& pwsh -NoLogo -NoProfile -File $builder -OutputPath $real -Ref 'abc1234' 2>&1 | Out-String)
    ok 'the real docs build with no broken link or anchor' ($LASTEXITCODE -eq 0)
    if ($LASTEXITCODE -ne 0) { Write-Host $text }

    if (Test-Path $real) {
        $config = Get-Content -LiteralPath $realConfig -Raw | ConvertFrom-Json
        $expected = 1  # landing page
        foreach ($s in $config.sections) {
            $files = @(Get-ChildItem -LiteralPath (Join-Path $repo $s.dir) -Filter '*.md' -File -Recurse:([bool]($s.PSObject.Properties.Name -contains 'recurse' -and $s.recurse)))
            $extra = if ($s.PSObject.Properties.Name -contains 'extra') { @($s.extra).Count } else { 0 }
            $expected += $files.Count + $extra
            if (-not (Test-Path (Join-Path $repo "$($s.dir)/README.md"))) { $expected++ }
        }
        $htmlFiles = @(Get-ChildItem -LiteralPath $real -Recurse -File -Filter '*.html')
        ok "every Markdown page is published (expected $expected, built $($htmlFiles.Count))" ($htmlFiles.Count -eq $expected)
        ok 'the operator guide index is published' (Test-Path (Join-Path $real 'guide/index.html'))
        ok 'the checklist is published' (Test-Path (Join-Path $real 'user-checklist.html'))
        ok 'the decision records are published' (@(Get-ChildItem (Join-Path $real 'decisions') -Filter '*.html').Count -ge 27)

        $realRoot = [IO.Path]::GetFullPath($real)
        $problems = [System.Collections.Generic.List[string]]::new()
        $idCache = @{}
        function Get-Ids([string]$File) {
            if (-not $idCache.ContainsKey($File)) {
                $idCache[$File] = @([regex]::Matches((Get-Content -LiteralPath $File -Raw), '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
            }
            return $idCache[$File]
        }
        foreach ($file in $htmlFiles) {
            $name = [IO.Path]::GetRelativePath($realRoot, $file.FullName) -replace '\\', '/'
            $html = Get-Content -LiteralPath $file.FullName -Raw
            if ($html -notmatch '<title>[^<]+</title>') { $problems.Add("${name}: no title") }
            if ($html -notmatch '<main id="content">') { $problems.Add("${name}: no main landmark") }
            if ($html -notmatch "default-src 'none'") { $problems.Add("${name}: no content-security policy") }
            if ([regex]::Matches($html, '<h1[\s>]').Count -ne 1) { $problems.Add("${name}: not exactly one h1") }
            if ($html -match '(?i)<script') { $problems.Add("${name}: contains a script") }
            if ($html -match '(?i)<(?:img|iframe|link|source|audio|video)[^>]+(?:src|href)\s*=\s*"https?://') { $problems.Add("${name}: loads an external resource") }
            foreach ($m in [regex]::Matches($html, '<a\s[^>]*?href="([^"]*)"')) {
                $href = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
                if ($href -match '^(?i:https?:|mailto:)') { continue }
                $path, $frag = $href -split '#', 2
                $target = if ($path) { [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $path)) } else { $file.FullName }
                if ($target -ceq [IO.Path]::GetFullPath((Join-Path $realRoot '../index.html'))) { continue }  # the wizard link, outside the docs tree
                if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $problems.Add("${name}: link to missing file '$href'"); continue }
                if ($frag -and ((Get-Ids $target) -cnotcontains [uri]::UnescapeDataString($frag))) { $problems.Add("${name}: link '$href' has no such anchor") }
            }
        }
        ok 'every generated page is well-formed, script-free and self-contained' ($problems.Count -eq 0)
        ok 'every link on every generated page resolves, anchors included' ($problems.Count -eq 0)
        if ($problems.Count -gt 0) { $problems | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }

        $css = Get-Content -LiteralPath (Join-Path $real 'assets/docs.css') -Raw
        ok 'the stylesheet loads nothing from the network' ($css -notmatch '(?i)url\s*\(\s*["'']?https?:' -and $css -notmatch '(?i)@import')
        ok 'the stylesheet supports dark mode and print' ($css -match 'prefers-color-scheme: dark' -and $css -match '@media print')

        $landing = Get-Content -LiteralPath (Join-Path $real 'index.html') -Raw
        ok 'the landing page links every section' (($config.sections | Where-Object { $landing -match [regex]::Escape([System.Net.WebUtility]::HtmlEncode($_.title)) } | Measure-Object).Count -eq @($config.sections).Count)

        $workflow = Get-Content -LiteralPath (Join-Path $repo '.github/workflows/deploy-pages.yml') -Raw
        ok 'the Pages workflow builds the docs into _pages/docs' ($workflow -match 'Build-DocsSite\.ps1' -and $workflow -match '_pages/docs')
        ok 'the Pages workflow passes the deployed commit as the link ref' ($workflow -match 'Build-DocsSite\.ps1[^\r\n]*-Ref')
        ok 'the Pages workflow redeploys when docs or the builder change' (
            $workflow -match "'docs/guide/\*\*'" -and $workflow -match "'docs/decisions/\*\*'" -and $workflow -match "'factory/docs-site/\*\*'")
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n== Results: $pass passed, $fail failed ==" -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }
