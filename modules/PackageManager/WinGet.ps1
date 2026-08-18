<#
.SYNOPSIS
    WinGet integration layer for WinDevOpsHub.

.DESCRIPTION
    Provides detection, version checking, and installation via WinGet.

    All WinGet operations are wrapped in consistent error handling.
    Dry-run support is threaded through every mutating function.

    WinGet scope:
    - Default: user scope (no admin required)
    - System scope: opt-in, requires admin

.NOTES
    Part of WinDevOpsHub · modules/PackageManager
#>

#Requires -Version 7.0

$script:WinGetAvailableCache = $null
$script:WinGetVersionCache   = $null

function Test-WinGetAvailable {
    [OutputType([bool])]
    param()

    if ($null -eq $script:WinGetAvailableCache) {
        $script:WinGetAvailableCache = [bool](Get-Command 'winget' -ErrorAction SilentlyContinue)
    }
    return $script:WinGetAvailableCache
}

function Get-WinGetVersion {
    [OutputType([string])]
    param()

    if (-not (Test-WinGetAvailable)) { return $null }

    if ($null -eq $script:WinGetVersionCache) {
        try {
            $raw = winget --version 2>&1
            $script:WinGetVersionCache = ($raw -replace '^v','').Trim()
        }
        catch {
            $script:WinGetVersionCache = $null
        }
    }
    return $script:WinGetVersionCache
}

function Assert-WinGetAvailable {
    <#
    .SYNOPSIS
        Throw a clear error if WinGet is not available.
    #>
    if (-not (Test-WinGetAvailable)) {
        throw (
            "WinGet is not available on this system.`n" +
            "Install the App Installer from the Microsoft Store, or update Windows.`n" +
            "Reference: https://github.com/microsoft/winget-cli"
        )
    }
}

# ─── Package management ──────────────────────────────────────────────────────

function Test-WinGetPackageInstalled {
    <#
    .SYNOPSIS
        Return $true if a given package is already installed via WinGet.

    .PARAMETER PackageId
        The WinGet package ID (e.g. "Hashicorp.Terraform").
    #>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $PackageId
    )

    Assert-WinGetAvailable

    try {
        # --exact prevents partial matches; --accept-source-agreements avoids prompts
        $output = winget list --id $PackageId --exact --accept-source-agreements 2>&1
        # winget list exits 0 when found, non-zero when not found
        return ($LASTEXITCODE -eq 0) -and ($output -match $PackageId)
    }
    catch {
        return $false
    }
}

function Install-WinGetPackage {
    <#
    .SYNOPSIS
        Install a package via WinGet.

    .PARAMETER PackageId
        WinGet package identifier (e.g. "Git.Git").

    .PARAMETER Scope
        'user' (default) or 'machine'. Machine scope requires admin.

    .PARAMETER DryRun
        If $true, log the action but do not execute the install.

    .PARAMETER Silent
        If $true, suppress interactive prompts (equivalent to --silent).

    .OUTPUTS
        PSCustomObject with: Success [bool], ExitCode [int], Output [string]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $PackageId,
        [ValidateSet('user','machine')]
        [string] $Scope   = 'user',
        [bool]   $DryRun  = $false,
        [bool]   $Silent  = $true
    )

    Assert-WinGetAvailable

    if ($DryRun) {
        Write-Host "[DRYRUN] Would install via WinGet: $PackageId (scope: $Scope)" -ForegroundColor DarkCyan
        return [PSCustomObject]@{ Success = $true; ExitCode = 0; Output = '[DryRun]' }
    }

    $args = @(
        'install'
        '--id', $PackageId
        '--exact'
        '--scope', $Scope
        '--accept-package-agreements'
        '--accept-source-agreements'
    )
    if ($Silent) { $args += '--silent' }

    try {
        $output  = winget @args 2>&1
        $success = $LASTEXITCODE -eq 0

        return [PSCustomObject]@{
            Success  = $success
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    }
    catch {
        return [PSCustomObject]@{
            Success  = $false
            ExitCode = -1
            Output   = $_.Exception.Message
        }
    }
}

function Update-WinGetPackage {
    <#
    .SYNOPSIS
        Upgrade an installed WinGet package to its latest version.

    .PARAMETER PackageId
        WinGet package identifier.

    .PARAMETER DryRun
        If $true, log but do not upgrade.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $PackageId,
        [bool] $DryRun = $false
    )

    Assert-WinGetAvailable

    if ($DryRun) {
        Write-Host "[DRYRUN] Would upgrade via WinGet: $PackageId" -ForegroundColor DarkCyan
        return [PSCustomObject]@{ Success = $true; ExitCode = 0; Output = '[DryRun]' }
    }

    try {
        $output  = winget upgrade --id $PackageId --exact --accept-package-agreements --accept-source-agreements --silent 2>&1
        $success = $LASTEXITCODE -eq 0
        return [PSCustomObject]@{ Success = $success; ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    }
    catch {
        return [PSCustomObject]@{ Success = $false; ExitCode = -1; Output = $_.Exception.Message }
    }
}

