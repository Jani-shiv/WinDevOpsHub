<#
.SYNOPSIS
    System information and PATH management for WinDevOpsHub.

.DESCRIPTION
    Provides:
    - Safe PATH inspection, deduplication, and additive modification
    - System resource information (RAM, disk)
    - Windows service inspection

    PATH rules:
    - Never replace the full PATH.
    - Never remove existing entries.
    - Never add duplicates.
    - Always operate at User scope unless explicitly requested to use Machine.

.NOTES
    Part of WinDevOpsHub · modules/System
#>

#Requires -Version 7.0

# ─── PATH Management ─────────────────────────────────────────────────────────

function Get-CurrentPath {
    <#
    .SYNOPSIS
        Return the effective PATH as an array of individual entries (deduplicated).
    #>
    [OutputType([string[]])]
    param()

    $raw = [System.Environment]::GetEnvironmentVariable('PATH', 'Process')
    if (-not $raw) { return @() }

    return ($raw -split ';' |
            Where-Object { $_ -ne '' } |
            ForEach-Object { $_.TrimEnd('\') } |
            Select-Object -Unique)
}

function Test-PathContains {
    <#
    .SYNOPSIS
        Return $true if the given directory is already in the effective PATH.

    .PARAMETER Directory
        Full path to test (trailing backslash is normalised).
    #>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Directory
    )

    $normalised = $Directory.TrimEnd('\').ToLowerInvariant()
    $current    = Get-CurrentPath

    foreach ($entry in $current) {
        if ($entry.TrimEnd('\').ToLowerInvariant() -eq $normalised) { return $true }
    }
    return $false
}

function Add-ToUserPath {
    <#
    .SYNOPSIS
        Add a directory to the current user's persistent PATH if not already present.

    .PARAMETER Directory
        The directory to add.

    .PARAMETER DryRun
        If $true, log what would happen but do not modify.

    .RETURNS
        $true if added, $false if already present or dry-run skipped.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Directory,
        [bool] $DryRun = $false
    )

    if (-not (Test-Path $Directory)) {
        Write-Warning "Add-ToUserPath: directory does not exist: $Directory"
        return $false
    }

    if (Test-PathContains -Directory $Directory) {
        Write-Host "· PATH already contains: $Directory" -ForegroundColor Gray
        return $false
    }

    if ($DryRun) {
        Write-Host "[DRYRUN] Would add to User PATH: $Directory" -ForegroundColor DarkCyan
        return $false
    }

    # Read current User PATH (persistent), append new entry, write back
    $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries  = if ($userPath) { ($userPath -split ';' | Where-Object { $_ -ne '' }) } else { @() }

    # Deduplicate before appending
    $norm = $Directory.TrimEnd('\').ToLowerInvariant()
    if ($entries | Where-Object { $_.TrimEnd('\').ToLowerInvariant() -eq $norm }) {
        return $false  # Already in user PATH
    }

    $entries += $Directory
    $newPath  = $entries -join ';'

    [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')

    # Also update the current process PATH so tools are immediately accessible
    $env:PATH = $env:PATH + ';' + $Directory

    Write-Host "✓ Added to User PATH: $Directory" -ForegroundColor Green
    return $true
}

function Get-PathDuplicates {
    <#
    .SYNOPSIS
        Return an array of PATH entries that appear more than once.
    #>
    [OutputType([string[]])]
    param()

    $raw = [System.Environment]::GetEnvironmentVariable('PATH', 'Process')
    if (-not $raw) { return @() }

    $entries = $raw -split ';' | Where-Object { $_ -ne '' } |
               ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }

    $grouped = $entries | Group-Object
    return @($grouped | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
}

# ─── System Information ──────────────────────────────────────────────────────

function Get-SystemSummary {
    <#
    .SYNOPSIS
        Return a summary of key system metrics.
    #>
    [OutputType([PSCustomObject])]
    param()

    $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs  = Get-CimInstance Win32_ComputerSystem  -ErrorAction Stop
    $cpu = Get-CimInstance Win32_Processor       -ErrorAction Stop | Select-Object -First 1

    $totalRAMGB  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRAMGB   = [math]::Round($os.FreePhysicalMemory  / 1MB, 2)  # FreePhysicalMemory is in KB

    # Disk — C: drive
    $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    $diskFreeGB  = if ($disk) { [math]::Round($disk.Free  / 1GB, 2) } else { 'N/A' }
    $diskUsedGB  = if ($disk) { [math]::Round($disk.Used  / 1GB, 2) } else { 'N/A' }

    return [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        CPUName      = $cpu.Name
        CPUCores     = $cpu.NumberOfCores
        TotalRAMGB   = $totalRAMGB
        FreeRAMGB    = $freeRAMGB
        DiskCFreeGB  = $diskFreeGB
        DiskCUsedGB  = $diskUsedGB
        Uptime       = (Get-Date) - $os.LastBootUpTime
    }
}

