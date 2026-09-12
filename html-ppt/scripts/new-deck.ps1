<#
html-ppt :: new-deck.ps1 — scaffold a new deck with its assets attached
Works on Windows PowerShell 5.1 and PowerShell 7+.

By DEFAULT this copies the shared assets into <deck>/assets/, so the deck
folder is SELF-CONTAINED and portable anywhere — another drive, a USB stick,
a zip you mail to someone. That is the right choice for any deck that will
leave this machine.

Use -Link instead when you want the deck to keep tracking the skill's own
assets (live edits to base.css / themes show up immediately) and do not care
about portability. On Windows this needs a junction, which requires either a
same-drive relative path or Developer Mode / admin rights for a cross-drive
junction.

Usage:
  ./new-deck.ps1 <name>                 # -> .\<name>\index.html
  ./new-deck.ps1 <name> <parent-dir>    # -> <parent-dir>\<name>\index.html
  ./new-deck.ps1 <name> <parent> -Link  # reference skill assets, don't copy
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Name,
  [Parameter(Position = 1)][string]$Parent = (Get-Location).Path,
  [switch]$Link,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Relative path from $From to $To, or $null when no relative path exists
# (different drive). [System.IO.Path]::GetRelativePath is .NET Core only, so
# this stays compatible with Windows PowerShell 5.1.
function Get-RelativeDir {
  param([string]$From, [string]$To)
  $fromFull = [System.IO.Path]::GetFullPath($From).TrimEnd('\')
  $toFull   = [System.IO.Path]::GetFullPath($To).TrimEnd('\')
  if ([System.IO.Path]::GetPathRoot($fromFull) -ne [System.IO.Path]::GetPathRoot($toFull)) { return $null }
  $root   = [System.IO.Path]::GetPathRoot($fromFull)
  $fParts = $fromFull.Substring($root.Length).Split('\')
  $tParts = $toFull.Substring($root.Length).Split('\')
  $i = 0
  while ($i -lt $fParts.Count -and $i -lt $tParts.Count -and $fParts[$i] -eq $tParts[$i]) { $i++ }
  $segs = @()
  for ($j = $i; $j -lt $fParts.Count; $j++) { $segs += '..' }
  if ($i -lt $tParts.Count) { $segs += $tParts[$i..($tParts.Count - 1)] }
  if ($segs.Count -eq 0) { return '.' }
  return ($segs -join '/')
}

$skillRoot = Split-Path -Parent $PSScriptRoot
$template  = Join-Path $skillRoot 'templates\deck.html'
$assetsDir = Join-Path $skillRoot 'assets'

if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { throw "error: template not found at $template" }
if (-not (Test-Path -LiteralPath $assetsDir -PathType Container)) { throw "error: assets not found at $assetsDir" }

$outDir = Join-Path $Parent $Name
if (Test-Path -LiteralPath $outDir) {
  if (-not $Force) { throw "error: $outDir already exists (pass -Force to reuse it)" }
} else {
  $null = New-Item -ItemType Directory -Path $outDir -Force
}
$outFile = Join-Path $outDir 'index.html'

# ---------------------------------------------------------------------------
# Decide how the deck reaches the shared assets
# ---------------------------------------------------------------------------
$mode       = 'copy'
$prefix     = 'assets'
$linkTarget = $null
$warnings   = @()

if ($Link) {
  # Prefer a plain relative path (works when both live on the same drive).
  $rel = Get-RelativeDir -From $outDir -To $assetsDir
  if ($null -ne $rel) {
    $mode   = 'link-relative'
    $prefix = $rel
  } else {
    # Cross-drive: a relative path cannot exist. Fall back to a junction so the
    # markup can still use a short local path, and be loud about the tradeoff.
    $junction = Join-Path $outDir 'assets'
    $created  = $false
    try {
      $null = New-Item -ItemType Junction -Path $junction -Target $assetsDir -ErrorAction Stop
      $created = $true
    } catch {
      $warnings += "cross-drive junction failed: $($_.Exception.Message)"
    }
    if ($created) {
      $mode       = 'link-junction'
      $prefix     = 'assets'
      $linkTarget = $junction
    } else {
      # Last resort: an absolute file:// URI. Works on this machine only.
      $prefix = ([System.Uri]::new($assetsDir)).AbsoluteUri.TrimEnd('/')
      $mode   = 'link-file-uri'
    }
  }
}

if ($mode -eq 'copy') {
  $dest = Join-Path $outDir 'assets'
  if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
  Copy-Item -LiteralPath $assetsDir -Destination $dest -Recurse -Force
}

# ---------------------------------------------------------------------------
# Write index.html with the resolved asset prefix
# ---------------------------------------------------------------------------
$html = Get-Content -LiteralPath $template -Raw -Encoding UTF8
$html = $html.Replace('../assets/', "$prefix/")
[System.IO.File]::WriteAllText($outFile, $html, (New-Object System.Text.UTF8Encoding($false)))

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host "created $outFile"
switch ($mode) {
  'copy'          { Write-Host "assets      : copied into $outDir\assets\  ->  deck is self-contained and portable" }
  'link-relative' { Write-Host "assets      : linked via relative path  $prefix/" }
  'link-junction' { Write-Host "assets      : linked via junction  $linkTarget  ->  $assetsDir" }
  'link-file-uri' { Write-Host "assets      : linked via absolute URI  $prefix/" }
}

if ($mode -eq 'copy') {
  Write-Host "              (keep the assets/ folder next to index.html; if you use git,"
  Write-Host "               either commit it or accept that a fresh clone shows unstyled HTML)"
}
if ($mode -eq 'link-junction') {
  Write-Host ""
  Write-Host "WARNING: the deck and the skill live on different drives, so a relative"
  Write-Host "         path is impossible and a junction was used instead."
  Write-Host "         A junction does NOT survive copying this folder to another"
  Write-Host "         location (USB stick, zip, another machine) - those copies open"
  Write-Host "         as unstyled HTML. If this deck will be shared, re-run without"
  Write-Host "         -Link so the assets are copied in."
}
if ($mode -eq 'link-file-uri') {
  Write-Host ""
  Write-Host "WARNING: could not create a junction, so the markup points at an absolute"
  Write-Host "         file:// URI. This deck only works on THIS machine, at THIS path."
  Write-Host "         Re-run without -Link to get a portable deck."
}
foreach ($w in $warnings) { Write-Host "note: $w" }

Write-Host ""
Write-Host "next steps:"
Write-Host "  start `"$outFile`"      # open in browser"
Write-Host "  # press T to cycle themes, arrows to navigate, O for overview, S for presenter"
