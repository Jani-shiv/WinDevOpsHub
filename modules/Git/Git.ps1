#Requires -Version 7.0

<#
.SYNOPSIS
    Git module for WinDevOpsHub — Git detection, version extraction, and diagnostics.

.DESCRIPTION
    Provides helper functions to detect Git status, check user configuration (name, email),
    and run basic health diagnostics.
#>

function Test-GitInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command git -ErrorAction SilentlyContinue)
}

function Get-GitVersionString {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not (Test-GitInstalled)) { return $null }
    try {
        $output = git --version 2>$null
        if ($output -match 'git version\s+([0-9\.]+)') {
            return $Matches[1]
        }
        return $output.Trim()
    }
    catch {
        return $null
    }
}

function Get-GitConfigSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if (-not (Test-GitInstalled)) {
        return [PSCustomObject]@{
            Installed    = $false
            Version      = $null
            UserName     = $null
            UserEmail    = $null
            DefaultBranch = $null
        }
    }

    $name   = (git config --global user.name 2>$null)?.Trim()
    $email  = (git config --global user.email 2>$null)?.Trim()
    $branch = (git config --global init.defaultBranch 2>$null)?.Trim()

    return [PSCustomObject]@{
        Installed     = $true
        Version       = Get-GitVersionString
        UserName      = $name
        UserEmail     = $email
        DefaultBranch = $branch
    }
}
