#Requires -Version 7.0

<#
.SYNOPSIS
    Terraform module for WinDevOpsHub — Terraform CLI detection and status.

.DESCRIPTION
    Provides helper functions to verify Terraform installation and version string.
#>

function Test-TerraformInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command terraform -ErrorAction SilentlyContinue)
}

function Get-TerraformVersionString {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not (Test-TerraformInstalled)) { return $null }
    try {
        $output = terraform version 2>$null | Select-Object -First 1
        if ($output -match 'Terraform v?([0-9\.]+)') {
            return $Matches[1]
        }
        return $output.Trim()
    }
    catch {
        return $null
    }
}
