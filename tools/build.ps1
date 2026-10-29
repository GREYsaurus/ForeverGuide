# ForeverGuide build script (Windows PowerShell 5.1+ / PowerShell 7).
# Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
# SPDX-License-Identifier: GPL-3.0-only
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/build.ps1 <command>
#
# Commands:
#   fetch            Download pinned upstream inputs (tools/upstream.json) into .cache/ and verify checksums
#   import-questie   Regenerate ForeverGuide/Database/QuestieTBC/*.lua from the pinned QuestieDB source
#   import-client    Regenerate talent trees and race/class tables from client DB2 CSV exports
#   guides           Compile guides-src/*.guide into ForeverGuide/Guides/Compiled/*.lua
#   lint             Lua 5.1 syntax check + global usage audit of every shipped .lua file
#   validate         Content validation (guides, talents, coverage, manifest)
#   report           Write docs/COVERAGE_REPORT.md
#   routes           Route optimization model: walk every race/class route, write docs/ROUTE_AUDIT.md
#                    and docs/generated/route-metrics.csv (fails on impossible quest order / log overflow)
#   package          Build dist/ForeverGuide-<version>.zip (installable add-on + corresponding source).
#                    REFUSES while any release blocker is open (validate lists them).
#   package-test     Build dist/ForeverGuide-<version>-UNVERIFIED-TEST.zip for in-client testing only,
#                    even with blockers open. Never publish it.
#   all              guides, lint, validate, routes, report (package is separate while blockers exist)
#   test             Run the headless Lua 5.1 tests (needs lua5.1 on PATH, or Python with lupa)
#   zonequests "<Zone>" <Alliance|Horde>   Authoring aid: list a zone's quests from the bundled DB
#
# Nothing here is needed by players: the shipped add-on already contains all generated data.

param(
    [Parameter(Position = 0)][string]$Command = "all",
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AddOn = Join-Path $Root "ForeverGuide"
$Cache = Join-Path $Root ".cache"
$Upstream = Get-Content (Join-Path $PSScriptRoot "upstream.json") -Raw | ConvertFrom-Json

function Load-Tools {
    if ("ForeverGuideTools.LuaLiteralReader" -as [type]) { return }
    $src = Get-ChildItem (Join-Path $PSScriptRoot "src") -Filter *.cs | ForEach-Object { $_.FullName }
    Add-Type -Path $src -ReferencedAssemblies System.Core, System.Data, System.Xml, Microsoft.VisualBasic
}

function Get-QdbRoot { Join-Path $Cache "upstream\questiedb" }
function Get-Db2Root { Join-Path $Cache "upstream\db2" }

function Assert-UpstreamEnabled {
    if ($Upstream.disabled) {
        throw "BLOCKED: tools/upstream.json pins TBC Classic data, which does not describe WoW Forever (PH-DATA-QUESTDB). Pin a verified Forever source first."
    }
}

function Invoke-Fetch {
    Assert-UpstreamEnabled
    $ProgressPreference = 'SilentlyContinue'
    $q = $Upstream.questiedb
    $zip = Join-Path $Cache "questiedb-$($q.commit).zip"
    New-Item -ItemType Directory -Force $Cache | Out-Null
    if (-not (Test-Path $zip)) {
        Write-Host "Downloading QuestieDB @ $($q.commit)"
        Invoke-WebRequest $q.archiveUrl -OutFile $zip -UseBasicParsing
    }
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($hash -ne $q.archiveSha256) { throw "QuestieDB archive checksum mismatch: $hash (expected $($q.archiveSha256))" }
    Write-Host "QuestieDB archive SHA256 OK"
    $dest = Get-QdbRoot
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $z.Entries) {
            $rel = $e.FullName -replace '^[^/]+/', ''
            if ($e.Length -gt 0 -and ($q.files -contains $rel)) {
                $t = Join-Path $dest ($rel -replace '/', '\')
                New-Item -ItemType Directory -Force (Split-Path $t) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $t, $true)
            }
        }
    } finally { $z.Dispose() }
    foreach ($f in $q.files) {
        if (-not (Test-Path (Join-Path $dest $f))) { throw "Expected upstream file missing from archive: $f" }
    }
    $c = $Upstream.clientTables
    $dd = Get-Db2Root
    New-Item -ItemType Directory -Force $dd | Out-Null
    foreach ($t in $c.tables) {
        $out = Join-Path $dd "$t.csv"
        if (-not (Test-Path $out)) {
            $url = $c.urlTemplate.Replace("{table}", $t).Replace("{build}", $c.build)
            Write-Host "Downloading $t ($($c.build))"
            Invoke-WebRequest $url -OutFile $out -UseBasicParsing
        }
    }
    Write-Host "Upstream inputs ready in $Cache"
}

function Invoke-ImportQuestie {
    Assert-UpstreamEnabled
    Load-Tools
    $qdb = Get-QdbRoot
    if (-not (Test-Path $qdb)) { throw "Run 'fetch' first." }
    $prov = "QuestieDB commit $($Upstream.questiedb.commit) ($($Upstream.questiedb.release))."
    Write-Host "Parsing upstream TBC tables..."
    $data = [ForeverGuideTools.QuestieData]::Load($qdb)
    $corr = [ForeverGuideTools.QuestieCorrections]::Apply($data, $qdb)
    $out = Join-Path $AddOn "Database\QuestieTBC"
    $stats = [ForeverGuideTools.QuestieExporter]::Export($data, $out, $prov)
    $stats.GetEnumerator() | Sort-Object Key | ForEach-Object { Write-Host ("  {0,-10} {1}" -f $_.Key, $_.Value) }
    Write-Host ("  corrections applied: {0}, skipped: {1}" -f $corr.Applied, $corr.Skipped.Count)
    $log = Join-Path $Root "docs\generated\questie-import.log"
    New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
    $lines = @("QuestieDB import - $prov", "")
    $lines += $stats.GetEnumerator() | Sort-Object Key | ForEach-Object { "{0}: {1}" -f $_.Key, $_.Value }
    $lines += "", "Corrections applied: $($corr.Applied)", "Corrections skipped (could not be evaluated statically):"
    $lines += $corr.Skipped
    $lines += "", "Warnings:"
    $lines += $data.Warnings
    $lines | Set-Content $log -Encoding UTF8
    Write-Host "Wrote $out (log: $log)"
}

function Invoke-ImportClient {
    Assert-UpstreamEnabled
    Load-Tools
    $dd = Get-Db2Root
    if (-not (Test-Path $dd)) { throw "Run 'fetch' first." }
    $r = [ForeverGuideTools.ClientTables]::Export($dd, $AddOn, $Upstream.clientTables.build)
    Write-Host $r
}

function Invoke-Guides {
    Load-Tools
    $res = [ForeverGuideTools.GuideCompiler]::CompileAll((Join-Path $Root "guides-src"), $AddOn)
    Write-Host $res.Summary
    $log = Join-Path $Root "docs\generated\guide-warnings.log"
    New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
    (@($res.Errors | ForEach-Object { "ERROR $_" }) + @($res.Warnings)) | Set-Content $log -Encoding UTF8
    if ($res.Errors.Count -gt 0) {
        $res.Errors | Select-Object -First 200 | ForEach-Object { Write-Host "  ERROR $_" -ForegroundColor Red }
        throw "Guide compilation failed with $($res.Errors.Count) error(s)."
    }
    $res.Warnings | Select-Object -First 60 | ForEach-Object { Write-Host "  warn  $_" -ForegroundColor Yellow }
    if ($res.Warnings.Count -gt 60) { Write-Host "  ... $($res.Warnings.Count - 60) more warnings (see docs/generated/guide-warnings.log)" }
}

function Invoke-Lint {
    Load-Tools
    $r = [ForeverGuideTools.Linter]::Run($AddOn, (Join-Path $PSScriptRoot "wow_api_allowlist.txt"))
    $r.Messages | ForEach-Object { Write-Host $_ }
    Write-Host $r.Summary
    if ($r.Errors -gt 0) { throw "Lint failed with $($r.Errors) error(s)." }
}

function Invoke-Validate {
    Load-Tools
    $r = [ForeverGuideTools.Validator]::Run($Root, $AddOn)
    $r.Messages | ForEach-Object { Write-Host $_ }
    Write-Host $r.Summary
    if ($r.Errors -gt 0) { throw "Validation failed with $($r.Errors) error(s)." }
}

function Invoke-Routes {
    Load-Tools
    $a = [ForeverGuideTools.RouteAnalyzer]::Run($Root, $AddOn)
    [ForeverGuideTools.RouteAnalyzer]::Write($Root, $a)
    $a.Errors | Select-Object -First 40 | ForEach-Object { Write-Host "  ERROR $_" -ForegroundColor Red }
    Write-Host ("routes: {0} routes walked, {1} error(s), {2} warning(s). Report: docs/ROUTE_AUDIT.md" -f $a.Routes, $a.Errors.Count, $a.Warnings.Count)
    if ($a.Errors.Count -gt 0) { throw "Route audit failed with $($a.Errors.Count) error(s)." }
}

function Invoke-Report {
    Load-Tools
    $path = Join-Path $Root "docs\COVERAGE_REPORT.md"
    [ForeverGuideTools.Validator]::WriteCoverageReport($Root, $AddOn, $path)
    Write-Host "Wrote $path"
}

# Zip a folder (including the folder name) with forward-slash entry names, as the zip spec requires.
# ZipFile.CreateFromDirectory on .NET Framework writes backslashes, which some extractors mishandle.
function New-Zip([string]$dir, [string]$zipPath) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $base = Split-Path -Parent $dir
    $fs = [IO.File]::Open($zipPath, [IO.FileMode]::Create)
    $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in Get-ChildItem $dir -Recurse -File) {
            $name = $f.FullName.Substring($base.Length).TrimStart('\', '/').Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $name, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
}

function Invoke-Package([bool]$TestBuild = $false) {
    Load-Tools
    $blockers = [ForeverGuideTools.Validator]::ReleaseBlockers($AddOn)
    if ($blockers.Count -gt 0 -and -not $TestBuild) {
        $blockers | ForEach-Object { Write-Host "  BLOCKED $_" -ForegroundColor Red }
        throw "Release packaging is blocked ($($blockers.Count) open blocker(s)). Use 'package-test' for an in-client test build."
    }
    $toc = Get-Content (Join-Path $AddOn "ForeverGuide.toc")
    $ver = ($toc | Where-Object { $_ -match '^## Version:' }) -replace '^## Version:\s*', ''
    if ($TestBuild) { $ver = "$ver-UNVERIFIED-TEST" }
    $dist = Join-Path $Root "dist"
    $stage = Join-Path $dist "stage"
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $stage | Out-Null
    Copy-Item $AddOn (Join-Path $stage "ForeverGuide") -Recurse
    if ($TestBuild) {
        "UNVERIFIED TEST BUILD - NOT A RELEASE. Built with open release blockers: $($blockers -join "; "). For in-client testing only (docs/SMOKE_TEST.md). Do not publish." |
            Set-Content (Join-Path $stage "ForeverGuide/TEST-BUILD-NOT-A-RELEASE.txt") -Encoding UTF8
    }
    # GPL: ship licence + attribution inside the add-on folder, and the full corresponding source alongside.
    foreach ($f in "LICENSE", "NOTICE.md", "THIRD_PARTY_LICENSES.md", "README.md") {
        Copy-Item (Join-Path $Root $f) (Join-Path $stage "ForeverGuide\$f")
    }
    $srcStage = Join-Path $stage "ForeverGuide-source"
    New-Item -ItemType Directory -Force $srcStage | Out-Null
    foreach ($d in "ForeverGuide", "guides-src", "tools", "tests", "docs") { Copy-Item (Join-Path $Root $d) (Join-Path $srcStage $d) -Recurse }
    foreach ($f in "LICENSE", "COPYING", "NOTICE.md", "THIRD_PARTY_LICENSES.md", "README.md", "INSTALL.md", "CHANGELOG.md", ".gitignore") {
        Copy-Item (Join-Path $Root $f) (Join-Path $srcStage $f)
    }
    $addonZip = Join-Path $dist "ForeverGuide-$ver.zip"
    $srcZip = Join-Path $dist "ForeverGuide-$ver-source.zip"
    foreach ($z in $addonZip, $srcZip) { if (Test-Path $z) { Remove-Item $z -Force -Confirm:$false } }
    New-Zip (Join-Path $stage "ForeverGuide") $addonZip
    New-Zip $srcStage $srcZip
    Remove-Item $stage -Recurse -Force -Confirm:$false
    Write-Host "Packaged $addonZip"
    Write-Host "Packaged $srcZip"
}

function Invoke-Tests {
    $lua = Get-Command lua5.1 -ErrorAction SilentlyContinue
    Push-Location $Root
    try {
        if ($lua) { & $lua.Source tests/run_tests.lua }
        else { python tests/run_with_lupa.py }
        if ($LASTEXITCODE -ne 0) { throw "Tests failed." }
    } finally { Pop-Location }
}

switch ($Command) {
    "fetch" { Invoke-Fetch }
    "import-questie" { Invoke-ImportQuestie }
    "import-client" { Invoke-ImportClient }
    "guides" { Invoke-Guides }
    "lint" { Invoke-Lint }
    "validate" { Invoke-Validate }
    "report" { Invoke-Report }
    "routes" { Invoke-Routes }
    "package" { Invoke-Package }
    "package-test" { Invoke-Package $true }
    "test" { Invoke-Tests }
    "zonequests" { Load-Tools; [ForeverGuideTools.QuestLister]::List($AddOn, $Arg1, $Arg2) }
    "all" { Invoke-Guides; Invoke-Lint; Invoke-Validate; Invoke-Routes; Invoke-Report }
    default { throw "Unknown command '$Command'. See the header of tools/build.ps1." }
}
