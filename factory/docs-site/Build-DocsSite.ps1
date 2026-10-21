#Requires -Version 7.0
<#
.SYNOPSIS
    Builds the documentation site that GitHub Pages serves under /docs/.
.DESCRIPTION
    Renders the Markdown listed in docs-site.json into plain, self-contained HTML:
    one stylesheet, no scripts, no network fetches (the same posture the wizard
    under site/ is held to). Uses only the Markdown converter built into
    PowerShell 7, so the build adds no third-party action, package or download.

    The build is STRICT. It fails, listing every problem at once, when:
      - a relative link points at a file that does not exist (or exists only with
        different letter case, which would work on Windows and 404 on Pages);
      - a link names an anchor (#section) that the target page does not have;
      - the Markdown contains something the site does not allow: script, iframe,
        object, embed, form, style, link, meta or base elements, inline event
        handlers, javascript: URLs, or images (no image support yet);
      - two source files would produce the same output page.

    Link handling, in order:
      1. A link to another published page becomes a relative link to its .html.
      2. A link to a directory that is a published section becomes that section's
         index page.
      3. A link to any other file or directory in the repository becomes a link to
         that exact path at -Ref on GitHub (pass a commit SHA to make it permanent).
      4. Anything else is a build error.

    Heading anchors use GitHub's slug rules, so a link that works when the
    Markdown is read on GitHub keeps working on the site.
.PARAMETER OutputPath
    Directory to write the site into. Must not exist or must be empty.
.PARAMETER Ref
    Git ref (branch or commit SHA) used for links to files outside the site.
    The deploy workflow passes the commit being deployed.
.EXAMPLE
    ./factory/docs-site/Build-DocsSite.ps1 -OutputPath ./_pages/docs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$OutputPath,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'docs-site.json'),
    [string]$Repository = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { 'saulpatinojr/Template-LZDeployment' }),
    [string]$Ref = 'main',
    [string]$Commit = $env:GITHUB_SHA
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$errors = [System.Collections.Generic.List[string]]::new()
function Add-LzError([string]$Message) { $script:errors.Add($Message) }

# -- helpers ------------------------------------------------------------------

function ConvertTo-LzSlug {
    # GitHub's heading-anchor rule: lower-case, drop everything that is not a
    # letter, digit, mark, underscore, hyphen or space, then spaces become hyphens.
    param([string]$Html, [hashtable]$Seen)
    $text = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($Html, '<[^>]+>', '')).Trim().ToLowerInvariant()
    $base = ([regex]::Replace($text, '[^\p{L}\p{N}\p{M}_\s-]', '')) -replace '\s', '-'
    if (-not $Seen.ContainsKey($base)) { $Seen[$base] = 0; return $base }
    $Seen[$base]++
    return "$base-$($Seen[$base])"
}

function Get-LzRelativeUrl {
    # Relative URL from one output file to another (both relative to the site root).
    param([string]$FromOut, [string]$ToOut)
    $fromDir = Split-Path $FromOut -Parent
    if (-not $fromDir) { $fromDir = '.' }
    return ([IO.Path]::GetRelativePath($fromDir, $ToOut)) -replace '\\', '/'
}

function Test-LzExactPath {
    # True only when the path exists with EXACTLY this letter case. Windows would
    # accept a wrong-case link; GitHub Pages (Linux) would 404, so catch it here.
    param([string]$RepoRelative)
    $cursor = $RepoRoot
    foreach ($part in ($RepoRelative -split '/' | Where-Object { $_ })) {
        $names = @([IO.Directory]::EnumerateFileSystemEntries($cursor) | ForEach-Object { [IO.Path]::GetFileName($_) })
        if ($names -cnotcontains $part) { return $false }
        $cursor = Join-Path $cursor $part
    }
    return $true
}

function ConvertTo-LzGitHubUrl {
    param([string]$RepoRelative, [bool]$IsDirectory, [string]$Fragment)
    $kind = if ($IsDirectory) { 'tree' } else { 'blob' }
    $path = ($RepoRelative -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $url = "https://github.com/$Repository/$kind/$Ref/$path"
    if ($Fragment) { $url += "#$Fragment" }
    return $url
}

function Edit-LzMatches {
    # Regex replace that lets the callback record errors instead of throwing from
    # inside a .NET delegate.
    param([string]$Text, [string]$Pattern, [scriptblock]$Callback)
    $builder = [System.Text.StringBuilder]::new()
    $last = 0
    foreach ($m in [regex]::Matches($Text, $Pattern, 'Singleline')) {
        [void]$builder.Append($Text, $last, $m.Index - $last)
        [void]$builder.Append([string](& $Callback $m))
        $last = $m.Index + $m.Length
    }
    [void]$builder.Append($Text, $last, $Text.Length - $last)
    return $builder.ToString()
}

# -- configuration and page inventory -----------------------------------------

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
if (Test-Path -LiteralPath $OutputPath) {
    if (@(Get-ChildItem -LiteralPath $OutputPath -Force).Count -gt 0) {
        throw "OutputPath '$OutputPath' exists and is not empty; refusing to build into it."
    }
}

$pagesBySource = @{}            # 'docs/guide/README.md' -> page
$sectionIndexByDir = @{}        # 'docs/guide' -> page (the section's index)
$pages = [System.Collections.Generic.List[object]]::new()
$outputsSeen = @{}

function Get-LzOutputPath([string]$Source) {
    $rel = $Source
    if ($rel.StartsWith('docs/')) { $rel = $rel.Substring(5) }
    $rel = $rel.ToLowerInvariant()
    if ($rel -match '(^|/)readme\.md$') { return ($rel -replace '(^|/)readme\.md$', '$1index.html') }
    return ($rel -replace '\.md$', '.html')
}

$sections = foreach ($s in $config.sections) {
    $dirFull = Join-Path $RepoRoot $s.dir
    if (-not (Test-Path -LiteralPath $dirFull -PathType Container)) { Add-LzError "Section '$($s.id)': directory '$($s.dir)' does not exist."; continue }
    $recurse = ($s.PSObject.Properties.Name -contains 'recurse') -and $s.recurse
    $found = @(Get-ChildItem -LiteralPath $dirFull -Filter '*.md' -File -Recurse:$recurse)
    $discovered = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $found) { $discovered.Add(([IO.Path]::GetRelativePath($RepoRoot, $f.FullName) -replace '\\', '/')) }
    # Ordinal, not culture-aware: the order (and so the sidebar) must be identical on
    # Windows, Linux and every locale.
    $discovered.Sort([StringComparer]::Ordinal)
    $indexSource = "$($s.dir)/README.md"
    $ordered = @($discovered | Where-Object { $_ -ceq $indexSource }) + @($discovered | Where-Object { $_ -cne $indexSource })
    if ($s.PSObject.Properties.Name -contains 'extra') {
        foreach ($extra in $s.extra) { if ($ordered -cnotcontains $extra) { $ordered += $extra } }  # listed order, after the rest
    }

    $sectionPages = [System.Collections.Generic.List[object]]::new()
    foreach ($source in $ordered) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $source) -PathType Leaf)) { Add-LzError "Section '$($s.id)': file '$source' does not exist."; continue }
        $out = Get-LzOutputPath $source
        if ($outputsSeen.ContainsKey($out)) { Add-LzError "Output collision: '$source' and '$($outputsSeen[$out])' both produce '$out'."; continue }
        $outputsSeen[$out] = $source
        $page = [pscustomobject]@{
            Source = $source; Out = $out; Section = $s.id; Title = $null; Body = $null
            Ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            Links = [System.Collections.Generic.List[object]]::new(); Synthetic = $false
        }
        $pagesBySource[$source] = $page
        $sectionPages.Add($page); $pages.Add($page)
        if ($source -ceq $indexSource) { $sectionIndexByDir[$s.dir] = $page }
    }
    if (-not $sectionIndexByDir.ContainsKey($s.dir)) {
        # No README: synthesise an index page listing the section.
        $out = ($s.dir -replace '^docs/', '').ToLowerInvariant() + '/index.html'
        if ($outputsSeen.ContainsKey($out)) { Add-LzError "Output collision on synthesised index '$out'." ; continue }
        $outputsSeen[$out] = "(index of $($s.dir))"
        $index = [pscustomobject]@{
            Source = $null; Out = $out; Section = $s.id; Title = $s.title; Body = $null
            Ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            Links = [System.Collections.Generic.List[object]]::new(); Synthetic = $true
        }
        $sectionIndexByDir[$s.dir] = $index
        $sectionPages.Insert(0, $index); $pages.Add($index)
    }
    [pscustomobject]@{ Id = $s.id; Title = $s.title; Description = $s.description; Dir = $s.dir; Pages = $sectionPages }
}
$sections = @($sections)

# -- link resolution ----------------------------------------------------------

function Resolve-LzHref {
    # Returns the rewritten href for one link found in $Page.
    param([string]$Href, $Page)
    $decoded = [System.Net.WebUtility]::HtmlDecode($Href)
    if ($decoded -match '^(?i:https?:|mailto:)') { return $Href }
    if ($decoded.StartsWith('#')) {
        $Page.Links.Add([pscustomobject]@{ Target = $Page; Fragment = $decoded.Substring(1); Original = $decoded })
        return $Href
    }
    $pathPart, $frag = $decoded -split '#', 2
    $pathPart = [uri]::UnescapeDataString($pathPart)
    $full = [IO.Path]::GetFullPath((Join-Path (Join-Path $RepoRoot (Split-Path $Page.Source -Parent)) $pathPart))
    $rootWithSep = $RepoRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not ($full + [IO.Path]::DirectorySeparatorChar).StartsWith($rootWithSep, [StringComparison]::Ordinal)) {
        Add-LzError "$($Page.Source): link '$decoded' leaves the repository."
        return $Href
    }
    $rel = ([IO.Path]::GetRelativePath($RepoRoot, $full) -replace '\\', '/').TrimEnd('/')
    if ($pagesBySource.ContainsKey($rel)) {
        $target = $pagesBySource[$rel]
        $Page.Links.Add([pscustomobject]@{ Target = $target; Fragment = $frag; Original = $decoded })
        $url = Get-LzRelativeUrl $Page.Out $target.Out
        if ($frag) { $url += "#$frag" }
        return [System.Net.WebUtility]::HtmlEncode($url)
    }
    if ($sectionIndexByDir.ContainsKey($rel) -and (Test-Path -LiteralPath $full -PathType Container)) {
        $target = $sectionIndexByDir[$rel]
        $Page.Links.Add([pscustomobject]@{ Target = $target; Fragment = $frag; Original = $decoded })
        $url = Get-LzRelativeUrl $Page.Out $target.Out
        if ($frag) { $url += "#$frag" }
        return [System.Net.WebUtility]::HtmlEncode($url)
    }
    if ((Test-Path -LiteralPath $full) -and (Test-LzExactPath $rel)) {
        $isDir = Test-Path -LiteralPath $full -PathType Container
        return [System.Net.WebUtility]::HtmlEncode((ConvertTo-LzGitHubUrl $rel $isDir $frag))
    }
    if (Test-Path -LiteralPath $full) {
        Add-LzError "$($Page.Source): link '$decoded' matches a file only when letter case is ignored; use the exact case ('$rel')."
    } else {
        Add-LzError "$($Page.Source): broken link '$decoded' ($rel does not exist)."
    }
    return $Href
}

# -- render each Markdown page ------------------------------------------------

$forbidden = @(
    @{ Pattern = '(?i)<\s*(script|iframe|object|embed|form|style|link|meta|base)\b'; Why = 'an element the site does not allow' }
    # Only inside a tag: prose and code that merely MENTION these must keep building.
    @{ Pattern = '(?i)<[a-z][^>]*\son[a-z]+\s*='; Why = 'an inline event handler' }
    @{ Pattern = '(?i)\b(?:href|src|action|formaction)\s*=\s*["'']?\s*javascript\s*:'; Why = 'a javascript: URL' }
    @{ Pattern = '(?i)<\s*img\b'; Why = 'an image (the site does not support images yet)' }
)

foreach ($page in @($pages | Where-Object { -not $_.Synthetic })) {
    $html = (ConvertFrom-Markdown -LiteralPath (Join-Path $RepoRoot $page.Source)).Html
    foreach ($rule in $forbidden) {
        if ($html -match $rule.Pattern) { Add-LzError "$($page.Source): contains $($rule.Why)." }
    }

    # Headings: GitHub-style ids plus a permalink on h2-h6.
    $seen = @{}
    $html = Edit-LzMatches $html '<h([1-6])(?:\s+id="[^"]*")?>(.*?)</h\1>' {
        param($m)
        $level = $m.Groups[1].Value; $inner = $m.Groups[2].Value
        $id = ConvertTo-LzSlug $inner $seen
        [void]$page.Ids.Add($id)
        if ($level -eq '1') { return "<h1 id=`"$id`">$inner</h1>" }
        return "<h$level id=`"$id`">$inner<a class=`"anchor`" href=`"#$id`" aria-label=`"Link to this section`">#</a></h$level>"
    }
    $h1 = [regex]::Match($html, '<h1[^>]*>(.*?)</h1>', 'Singleline')
    if (-not $h1.Success) { Add-LzError "$($page.Source): has no top-level heading (# Title), so the page has no title."; $page.Title = $page.Source }
    else { $page.Title = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($h1.Groups[1].Value, '<[^>]+>', '')).Trim() }

    # Links.
    $html = Edit-LzMatches $html '(<a\s[^>]*?href=")([^"]*)(")' {
        param($m)
        $new = Resolve-LzHref $m.Groups[2].Value $page
        $external = $new -match '^(?i:https?:)'
        $tag = $m.Groups[1].Value + $new + $m.Groups[3].Value
        if ($external -and $tag -notmatch 'rel=') { $tag = $tag -replace '^<a ', '<a rel="noopener" ' }
        return $tag
    }
    # Tables scroll sideways on narrow screens instead of breaking the layout.
    $html = $html -replace '<table>', '<div class="table-wrap"><table>' -replace '</table>', '</table></div>'
    $page.Body = $html
}

# -- synthesised section indexes ----------------------------------------------

foreach ($section in $sections) {
    foreach ($page in @($section.Pages | Where-Object { $_.Synthetic })) {
        $items = foreach ($p in ($section.Pages | Where-Object { -not $_.Synthetic })) {
            '<li><a href="{0}">{1}</a></li>' -f (Get-LzRelativeUrl $page.Out $p.Out), [System.Net.WebUtility]::HtmlEncode($p.Title)
        }
        $page.Body = "<h1 id=`"$(ConvertTo-LzSlug $section.Title @{})`">$([System.Net.WebUtility]::HtmlEncode($section.Title))</h1>`n" +
            "<p>$([System.Net.WebUtility]::HtmlEncode($section.Description))</p>`n<ul class=`"page-list`">`n$($items -join "`n")`n</ul>"
        [void]$page.Ids.Add((ConvertTo-LzSlug $section.Title @{}))
    }
}

# -- anchors must exist on their target page ----------------------------------

foreach ($page in $pages) {
    foreach ($link in $page.Links) {
        if (-not $link.Fragment) { continue }
        $fragment = [uri]::UnescapeDataString($link.Fragment)
        if (-not $link.Target.Ids.Contains($fragment)) {
            Add-LzError "$($page.Source): link '$($link.Original)' names an anchor that does not exist on $($link.Target.Source)."
        }
    }
}

if ($errors.Count -gt 0) {
    # One problem per line, unwrapped, so a CI log reads cleanly.
    foreach ($problem in ($errors | Sort-Object -Unique)) { Write-Host "ERROR: $problem" }
    throw "Docs site build failed with $($errors.Count) problem(s); see the ERROR lines above."
}

# -- write the site -----------------------------------------------------------

$css = @'
:root {
  color-scheme: light dark;
  --bg: #ffffff; --fg: #1b1f24; --muted: #57606a; --line: #d0d7de; --soft: #f6f8fa;
  --accent: #0b5cad; --accent-fg: #ffffff; --note: #fff8c5; --note-line: #d4a72c;
  --code-bg: #eff1f3;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117; --fg: #e6edf3; --muted: #9da7b3; --line: #30363d; --soft: #161b22;
    --accent: #58a6ff; --accent-fg: #0d1117; --note: #272115; --note-line: #9e6a03;
    --code-bg: #1c2128;
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body { margin: 0; background: var(--bg); color: var(--fg); line-height: 1.6;
  font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
a { color: var(--accent); }
a:focus-visible, summary:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; border-radius: 3px; }
.skip { position: absolute; left: -999px; top: 0; background: var(--accent); color: var(--accent-fg); padding: .5rem 1rem; z-index: 10; }
.skip:focus { left: 0; }
.top { display: flex; flex-wrap: wrap; gap: .5rem 1.5rem; align-items: center; justify-content: space-between;
  padding: .75rem 1rem; border-bottom: 1px solid var(--line); background: var(--soft); }
.brand { font-weight: 650; text-decoration: none; color: var(--fg); }
.top nav { display: flex; gap: 1rem; flex-wrap: wrap; font-size: .95rem; }
.layout { display: grid; grid-template-columns: 17rem minmax(0, 1fr); gap: 0; max-width: 78rem; margin: 0 auto; }
.side { padding: 1rem; border-right: 1px solid var(--line); font-size: .93rem;
  position: sticky; top: 0; align-self: start; max-height: 100vh; overflow-y: auto; }
.side details { margin-bottom: .5rem; }
.side summary { cursor: pointer; font-weight: 600; padding: .25rem 0; }
.side ul { list-style: none; margin: .25rem 0 .5rem; padding-left: .75rem; border-left: 2px solid var(--line); }
.side li { margin: .15rem 0; }
.side a { text-decoration: none; display: block; padding: .1rem .4rem; border-radius: 4px; }
.side a:hover { background: var(--soft); text-decoration: underline; }
.side a[aria-current="page"] { background: var(--accent); color: var(--accent-fg); font-weight: 600; }
main { padding: 1.5rem clamp(1rem, 4vw, 3rem) 3rem; min-width: 0; }
article { max-width: 52rem; }
h1 { font-size: 2rem; line-height: 1.25; margin-top: 0; }
h2 { font-size: 1.5rem; margin-top: 2.2rem; padding-bottom: .3rem; border-bottom: 1px solid var(--line); }
h3 { font-size: 1.2rem; margin-top: 1.8rem; }
h2, h3, h4, h5, h6 { line-height: 1.3; scroll-margin-top: 1rem; }
.anchor { margin-left: .4rem; text-decoration: none; opacity: 0; font-weight: 400; }
h2:hover .anchor, h3:hover .anchor, h4:hover .anchor, .anchor:focus { opacity: .7; }
code, pre { font: .9em/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
code { background: var(--code-bg); padding: .1em .35em; border-radius: 4px; }
pre { background: var(--code-bg); padding: .9rem 1rem; border-radius: 6px; overflow-x: auto; border: 1px solid var(--line); }
pre code { background: none; padding: 0; }
blockquote { margin: 1rem 0; padding: .6rem 1rem; background: var(--note); border-left: 4px solid var(--note-line); border-radius: 0 6px 6px 0; }
blockquote > :first-child { margin-top: 0; } blockquote > :last-child { margin-bottom: 0; }
.table-wrap { overflow-x: auto; margin: 1rem 0; }
table { border-collapse: collapse; width: 100%; font-size: .95rem; }
th, td { border: 1px solid var(--line); padding: .4rem .7rem; text-align: left; vertical-align: top; }
th { background: var(--soft); }
hr { border: 0; border-top: 1px solid var(--line); margin: 2rem 0; }
.page-list { padding-left: 1.2rem; } .page-list li { margin: .2rem 0; }
.cards { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr)); padding: 0; list-style: none; }
.cards li { border: 1px solid var(--line); border-radius: 8px; padding: 1rem; background: var(--soft); }
.cards h2 { font-size: 1.15rem; margin: 0 0 .4rem; border: 0; padding: 0; }
.cards p { margin: 0 0 .6rem; color: var(--muted); font-size: .95rem; }
.meta { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--line); color: var(--muted); font-size: .88rem; }
@media (max-width: 52rem) {
  .layout { display: flex; flex-direction: column; }
  main { order: 1; }
  .side { order: 2; position: static; max-height: none; border-right: 0; border-top: 1px solid var(--line); }
}
@media print { .side, .top, .skip, .anchor { display: none; } .layout { display: block; } }
'@

function New-LzNav {
    param($CurrentPage)
    $out = [System.Text.StringBuilder]::new()
    foreach ($section in $sections) {
        $isCurrent = $CurrentPage -and ($CurrentPage.Section -eq $section.Id)
        $open = if ($isCurrent -or (-not $CurrentPage -and $section.Id -eq $sections[0].Id)) { ' open' } else { '' }
        [void]$out.Append("<details$open><summary>$([System.Net.WebUtility]::HtmlEncode($section.Title))</summary><ul>")
        foreach ($p in $section.Pages) {
            $from = if ($CurrentPage) { $CurrentPage.Out } else { 'index.html' }
            $current = if ($CurrentPage -and $p.Out -eq $CurrentPage.Out) { ' aria-current="page"' } else { '' }
            [void]$out.Append("<li><a href=`"$(Get-LzRelativeUrl $from $p.Out)`"$current>$([System.Net.WebUtility]::HtmlEncode($p.Title))</a></li>")
        }
        [void]$out.Append('</ul></details>')
    }
    return $out.ToString()
}

function New-LzDocument {
    param([string]$Out, [string]$PageTitle, [string]$Body, $CurrentPage, [string]$Source)
    $siteTitle = [System.Net.WebUtility]::HtmlEncode($config.title)
    $titleText = if ($Out -eq 'index.html') { $siteTitle } else { "$([System.Net.WebUtility]::HtmlEncode($PageTitle)) - $siteTitle" }
    $cssUrl = Get-LzRelativeUrl $Out 'assets/docs.css'
    $homeUrl = Get-LzRelativeUrl $Out 'index.html'
    $wizard = Get-LzRelativeUrl $Out '../index.html'
    $meta = ''
    if ($Source) {
        $meta = "<p class=`"meta`">Source: <a href=`"https://github.com/$Repository/blob/$Ref/$Source`">$Source</a> &middot; " +
            "<a href=`"https://github.com/$Repository/edit/main/$Source`">Edit this page on GitHub</a>"
        if ($Commit) { $meta += " &middot; Built from commit <a href=`"https://github.com/$Repository/commit/$Commit`">$($Commit.Substring(0, [Math]::Min(7, $Commit.Length)))</a>" }
        $meta += '</p>'
    }
    return @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'">
<meta name="color-scheme" content="light dark">
<title>$titleText</title>
<link rel="stylesheet" href="$cssUrl">
</head>
<body>
<a class="skip" href="#content">Skip to content</a>
<header class="top">
<a class="brand" href="$homeUrl">$siteTitle</a>
<nav aria-label="Site"><a href="$wizard">Configuration wizard</a><a href="https://github.com/$Repository">Repository on GitHub</a></nav>
</header>
<div class="layout">
<nav class="side" aria-label="Documentation">
$(New-LzNav $CurrentPage)
</nav>
<main id="content">
<article>
$Body
$meta
</article>
</main>
</div>
</body>
</html>
"@
}

function Write-LzFile([string]$Relative, [string]$Content) {
    $path = Join-Path $OutputPath $Relative
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent))
    [IO.File]::WriteAllText($path, ($Content -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
}

Write-LzFile 'assets/docs.css' $css

foreach ($page in $pages) {
    Write-LzFile $page.Out (New-LzDocument -Out $page.Out -PageTitle $page.Title -Body $page.Body -CurrentPage $page -Source $page.Source)
}

# Landing page.
$cards = foreach ($section in $sections) {
    $first = $section.Pages | Select-Object -First 1
    $count = @($section.Pages | Where-Object { -not $_.Synthetic }).Count
    $countLabel = if ($count -eq 1) { '1 page' } else { "$count pages" }
    '<li><h2><a href="{0}">{1}</a></h2><p>{2}</p><p>{3}</p></li>' -f
        (Get-LzRelativeUrl 'index.html' $first.Out),
        [System.Net.WebUtility]::HtmlEncode($section.Title),
        [System.Net.WebUtility]::HtmlEncode($section.Description),
        $countLabel
}
$landing = "<h1 id=`"top`">$([System.Net.WebUtility]::HtmlEncode($config.title))</h1>`n<p>$([System.Net.WebUtility]::HtmlEncode($config.intro))</p>`n<ul class=`"cards`">`n$($cards -join "`n")`n</ul>"
Write-LzFile 'index.html' (New-LzDocument -Out 'index.html' -PageTitle $config.title -Body $landing -CurrentPage $null -Source $null)

Write-Host ("Docs site built: {0} page(s) in {1} section(s) -> {2}" -f (@($pages | Where-Object { -not $_.Synthetic }).Count + 1), $sections.Count, $OutputPath)
