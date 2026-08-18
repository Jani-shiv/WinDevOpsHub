<#
.SYNOPSIS
    WinDevOpsHub PackageManager module loader.
#>
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

$pmFiles = @('WinGet.ps1', 'Choco.ps1', 'Installer.ps1')
foreach ($file in $pmFiles) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $fullPath)) { throw "PackageManager module component not found: $fullPath" }
    . $fullPath
}
