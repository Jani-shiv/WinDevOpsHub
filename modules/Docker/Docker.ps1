#Requires -Version 7.0

<#
.SYNOPSIS
    Docker module for WinDevOpsHub — Docker CLI & Daemon diagnostics.

.DESCRIPTION
    Provides functions to verify Docker installation, daemon running state,
    and server/client info without throwing unhandled exceptions.
#>

function Test-DockerInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command docker -ErrorAction SilentlyContinue)
}

function Test-DockerDaemonRunning {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-DockerInstalled)) { return $false }
    try {
        $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
        $pinfo.FileName               = 'docker'
        $pinfo.Arguments              = 'info'
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError  = $true
        $pinfo.UseShellExecute        = $false
        $pinfo.CreateNoWindow         = $true

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        if ($null -eq $proc) { return $false }

        $finished = $proc.WaitForExit(2500)
        if (-not $finished) {
            try { $proc.Kill() } catch { }
            return $false
        }
        return ($proc.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

function Get-DockerSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $installed = Test-DockerInstalled
    $daemonRunning = $false
    $version = $null

    if ($installed) {
        try {
            $verOutput = docker --version 2>$null
            if ($verOutput -match 'Docker version\s+([0-9\.]+)') {
                $version = $Matches[1]
            }
            else {
                $version = $verOutput.Trim()
            }
        }
        catch { }

        $daemonRunning = Test-DockerDaemonRunning
    }

    return [PSCustomObject]@{
        Installed     = $installed
        DaemonRunning = $daemonRunning
        Version       = $version
    }
}
