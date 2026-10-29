# ForeverGuide - self-tests for the build tooling (runs without a Lua interpreter).
# Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
# SPDX-License-Identifier: GPL-3.0-only
#
#   powershell -ExecutionPolicy Bypass -File tests/tools-selftest.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$src = Get-ChildItem (Join-Path $Root "tools\src") -Filter *.cs | ForEach-Object { $_.FullName }
Add-Type -Path $src -ReferencedAssemblies System.Core, System.Data, System.Xml, Microsoft.VisualBasic

$fail = 0; $pass = 0
function Check($cond, $msg) { if ($cond) { $script:pass++ } else { $script:fail++; Write-Host "FAIL: $msg" -ForegroundColor Red } }
function SyntaxOk($code) { try { [void][ForeverGuideTools.LuaChecker]::Check($code); return $true } catch { return $false } }

# Lua checker must accept valid and reject invalid Lua 5.1
Check (SyntaxOk 'local t = {a=1,[2]=3,"x";} print(t.a)') "table constructor"
Check (SyntaxOk 'local function f(...) return ... end') "vararg function"
Check (SyntaxOk 'for i=1,2 do if i then break end end') "break inside if inside for"
Check (SyntaxOk 'local s = [==[ long ]] ]==]') "long bracket level"
Check (-not (SyntaxOk 'local x = = 1')) "rejects double equals"
Check (-not (SyntaxOk 'if x then')) "rejects missing end"
Check (-not (SyntaxOk 'local function f() return ... end')) "rejects ... outside vararg"
Check (-not (SyntaxOk 'x = "unterminated')) "rejects unterminated string"
Check (-not (SyntaxOk 'return 1 print(2)')) "rejects statement after return"

# Global tracking
$c = [ForeverGuideTools.LuaChecker]::Check('local a = 1; b = 2; print(c.d)')
Check (($c.Globals | Where-Object { $_.Name -eq 'b' -and $_.Write }).Count -eq 1) "detects global write"
Check (($c.Globals | Where-Object { $_.Name -eq 'c' -and $_.Field -eq 'd' }).Count -eq 1) "detects global read with field"
Check (($c.Globals | Where-Object { $_.Name -eq 'a' }).Count -eq 0) "locals are not globals"

# Literal reader round trip
$t = [ForeverGuideTools.LuaLiteralReader]::ParseValue('return {1,nil,{x=2},"s\"q",[10]=-3.5,flag=true}', 'test')
$lua = [ForeverGuideTools.LuaWriter]::Value($t)
$t2 = [ForeverGuideTools.LuaLiteralReader]::ParseValue($lua, 'test2')
Check ([ForeverGuideTools.LuaWriter]::Value($t2) -eq $lua) "literal round trip: $lua"
Check ($t.Get(1) -eq 1 -and $null -eq $t.Get(2) -and $t.Get(4) -eq 's"q') "positional values with holes"

# ForeverGuide: no game database ships (PH-DATA-QUESTDB); the loader must cope with that.
$addOn = Join-Path $Root "ForeverGuide"
$db = [ForeverGuideTools.BundledDb]::Load($addOn)
Check ($db.Quests.Count -eq 0 -and $db.ZoneByName.Count -eq 0) "empty database loads without error"
$ph = [ForeverGuideTools.GuideCompiler]::LoadPlaceholderIds($addOn)
Check ($ph.Contains("PH-PLATFORM-INTERFACE") -and $ph.Contains("PH-ROUTE-ALLIANCE-START")) "placeholder ids are read from Config/Placeholders.lua"
Check ([ForeverGuideTools.Validator]::ReleaseBlockers($addOn).Count -gt 0) "release blockers are reported while the interface is unverified"
Check ([ForeverGuideTools.Validator]::ManifestFiles($addOn).Count -eq 0) "every file the TOC loads exists"

# Guide compiler: placeholder rules. Each case is compiled on its own from a temporary folder.
$head = "@guide T_X`n@name T`n@faction Alliance`n@chapter Azeroth`n"
function Compile($text) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("fg-selftest-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir "t.guide"), $text)
    try { return [ForeverGuideTools.GuideCompiler]::CompileAll($dir, $addOn, $false) } finally { Remove-Item $dir -Recurse -Force -Confirm:$false }
}
$pendingHead = $head + "@status placeholder`n@levels ?`n@zone ?`n"
$r = Compile ($pendingHead + "pending Something [id=a.1; ph=PH-ROUTE-LEVELING]`n")
Check ($r.Errors.Count -eq 0 -and $r.Guides[0].Steps[0].Sid -eq "a.1") "valid pending guide compiles ($($r.Errors -join '; '))"
Check ((Compile ($pendingHead + "pending Something [ph=PH-ROUTE-LEVELING]`n")).Errors.Count -gt 0) "step without [id] is an error"
Check ((Compile ($pendingHead + "pending Something [id=a.1]`n")).Errors.Count -gt 0) "pending step without ph is an error"
Check ((Compile ($pendingHead + "pending Something [id=a.1; ph=PH-NOT-REAL]`n")).Errors.Count -gt 0) "unknown placeholder id is an error"
Check ((Compile ($pendingHead + "pending Something [id=a.1; ph=PH-ROUTE-LEVELING; at=40,40]`n")).Errors.Count -gt 0) "pending step with coordinates is an error"
Check ((Compile ($pendingHead + "pending A [id=a.1; ph=PH-ROUTE-LEVELING]`npending B [id=a.1; ph=PH-ROUTE-LEVELING]`n")).Errors.Count -gt 0) "duplicate step id is an error"
Check ((Compile ($pendingHead + "note Real-looking step [id=a.1]`n")).Errors.Count -gt 0) "non-pending step in a placeholder guide is an error"
Check ((Compile ($head + "@status verified`n@levels ?`n@zone ?`nnote x [id=a.1]`n")).Errors.Count -gt 0) "unknown levels/zone in a verified guide is an error"
Check ((Compile ($head + "@status verified`n@levels 1-5`n@zone Elwynn Forest`naccept 783 [id=a.1]`n")).Errors.Count -gt 0) "TBC quest/zone references fail without verified data"
Check ((Compile ($pendingHead + "@races Draenei`n@start`npending x [id=a.1; ph=PH-ROUTE-LEVELING]`n")).Errors.Count -gt 0) "races not playable in Forever are rejected"
Check ((Compile ($head + "@levels ?`n@zone ?`npending x [id=a.1; ph=PH-ROUTE-LEVELING]`n")).Errors.Count -gt 0) "missing @status is an error"

Write-Host ("tools self-test: {0} passed, {1} failed" -f $pass, $fail)
if ($fail -gt 0) { exit 1 }
