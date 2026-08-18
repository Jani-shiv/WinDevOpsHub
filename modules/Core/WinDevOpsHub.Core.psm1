<#
.SYNOPSIS
    WinDevOpsHub Core module manifest.

.NOTES
    Dot-sources all Core sub-modules and re-exports their public functions.
    Part of WinDevOpsHub · modules/Core
#>

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Source order matters: Logger first (others may call it), then Platform, Errors, Config
$coreFiles = @(
    'Logger.ps1'
    'Platform.ps1'
    'Errors.ps1'
    'Config.ps1'
)

foreach ($file in $coreFiles) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $fullPath)) {
        throw "Core module component not found: $fullPath"
    }
    . $fullPath
}
