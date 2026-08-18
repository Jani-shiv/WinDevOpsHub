<#
.SYNOPSIS
    Chocolatey fallback integration for WinDevOpsHub.

.DESCRIPTION
    Provides Chocolatey-based install/detect as a fallback when WinGet is
    unavailable or a package is not in the WinGet catalogue.

.NOTES
    Part of WinDevOpsHub · modules/PackageManager
#>

#Requires -Version 7.0

function Test-ChocoAvailable {
    [OutputType([bool])]
    param()
    return $null -ne (Get-Command 'choco' -ErrorAction SilentlyContinue)
}

function Get-ChocoVersion {
    [OutputType([string])]
    param()
    if (-not (Test-ChocoAvailable)) { return $null }
    try {
        $raw = choco --version 2>&1
        return $raw.Trim()
    }
    catch { return $null }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Install a package via Chocolatey.

    .PARAMETER PackageId
        Chocolatey package name (e.g. "terraform").

    .PARAMETER DryRun
        If $true, log the action but do not install.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $PackageId,
        [bool] $DryRun = $false
    )

    if (-not (Test-ChocoAvailable)) {
        return [PSCustomObject]@{
            Success  = $false
            ExitCode = -1
            Output   = 'Chocolatey is not available on this system.'
        }
    }

    if ($DryRun) {
        Write-Host "[DRYRUN] Would install via Chocolatey: $PackageId" -ForegroundColor DarkCyan
        return [PSCustomObject]@{ Success = $true; ExitCode = 0; Output = '[DryRun]' }
    }

    try {
        $output  = choco install $PackageId --yes --no-progress 2>&1
        $success = $LASTEXITCODE -eq 0
        return [PSCustomObject]@{ Success = $success; ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    }
    catch {
        return [PSCustomObject]@{ Success = $false; ExitCode = -1; Output = $_.Exception.Message }
    }
}

