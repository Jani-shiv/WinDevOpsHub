#Requires -Version 7.0

<#
.SYNOPSIS
    Common script helper functions for WinDevOpsHub.

.DESCRIPTION
    Shared utilities for script entry points, path resolution, and module loading.
#>

function Get-RepoRootPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $CallingScriptPath = $PSScriptRoot
    )

    $current = $CallingScriptPath
    while ($current -and -not (Test-Path (Join-Path $current 'modules'))) {
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $current
}
