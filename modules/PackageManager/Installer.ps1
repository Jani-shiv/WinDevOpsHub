<#
.SYNOPSIS
    Unified tool installer for WinDevOpsHub.

.DESCRIPTION
    Install-Tool is the single entry point for installing any tool defined
    in the tool registry. It:

    1. Looks up the tool definition from the registry.
    2. Checks if the tool is already installed (idempotency gate).
    3. Routes to the appropriate package manager (WinGet first, Choco fallback).
    4. Verifies the installation by checking the command in PATH.
    5. Returns a structured result object.

    Dry-run support is honoured throughout.

.NOTES
    Part of WinDevOpsHub · modules/PackageManager
#>

#Requires -Version 7.0

# Dot-source sibling package managers (when loaded outside the module loader)
if (-not (Get-Command 'Test-WinGetAvailable' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'WinGet.ps1')
}
if (-not (Get-Command 'Test-ChocoAvailable' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Choco.ps1')
}

# ─── Public API ───────────────────────────────────────────────────────────────

function Test-ToolInstalled {
    <#
    .SYNOPSIS
        Return $true if a tool's command is reachable on PATH.

    .PARAMETER ToolDefinition
        A tool definition object from the registry (must have .command property).
    #>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [PSCustomObject] $ToolDefinition
    )

    if (-not $ToolDefinition.command) { return $false }
    return $null -ne (Get-Command $ToolDefinition.command -ErrorAction SilentlyContinue)
}

function Get-ToolVersion {
    <#
    .SYNOPSIS
        Return the version string of an installed tool, or $null.
        Guarded with a 3-second timeout to prevent hanging.

    .PARAMETER ToolDefinition
        A tool definition object from the registry.
    #>
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [PSCustomObject] $ToolDefinition
    )

    $cmd = $ToolDefinition.command
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        return $null
    }

    $verArg = if ($ToolDefinition.versionArg) { $ToolDefinition.versionArg } else { '--version' }

    # For pwsh itself, $PSVersionTable is instant, reliable across all platforms
    if ($ToolDefinition.id -eq 'pwsh' -or $cmd -eq 'pwsh') {
        if ($PSVersionTable.PSVersion) {
            return "PowerShell $($PSVersionTable.PSVersion)"
        }
    }

    # Execute version check with ProcessStartInfo and 3-second timeout protection
    try {
        $cmdInfo = Get-Command $cmd -ErrorAction SilentlyContinue
        $cmdPath = if ($cmdInfo.Source) { $cmdInfo.Source } else { $cmd }

        $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError  = $true
        $pinfo.UseShellExecute        = $false
        $pinfo.CreateNoWindow         = $true

        if ($cmdPath -match '\.ps1$') {
            $pinfo.FileName  = 'pwsh'
            $pinfo.Arguments = "-NoProfile -Command `"& '$cmdPath' $verArg`""
        }
        elseif ($cmdPath -match '\.(cmd|bat)$') {
            $pinfo.FileName  = 'cmd.exe'
            $pinfo.Arguments = "/c `"$cmdPath`" $verArg"
        }
        else {
            $pinfo.FileName  = $cmdPath
            $pinfo.Arguments = $verArg
        }

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        if ($null -ne $proc) {
            $finished = $proc.WaitForExit(3000)
            if ($finished) {
                $out = $proc.StandardOutput.ReadToEnd()
                if ([string]::IsNullOrWhiteSpace($out)) {
                    $out = $proc.StandardError.ReadToEnd()
                }
                if (-not [string]::IsNullOrWhiteSpace($out)) {
                    $firstLine = ($out -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1)
                    if ($firstLine) { return $firstLine.Trim() }
                }
            }
            else {
                try { $proc.Kill() } catch { }
            }
        }
    }
    catch { }

    # Fallback to direct PowerShell invocation
    try {
        $argsList = $verArg -split ' '
        $raw = & $cmd @argsList 2>&1
        $version = $raw |
            ForEach-Object { $_.ToString().Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -First 1

        if (-not [string]::IsNullOrWhiteSpace($version)) {
            return $version
        }
    }
    catch { }

    return $null
}

function Install-Tool {
    <#
    .SYNOPSIS
        Install a tool by its registry ID, with full idempotency and dry-run support.

    .PARAMETER ToolId
        The tool identifier (e.g. "terraform", "git", "kubectl").

    .PARAMETER DryRun
        If $true, log what would happen but make no changes.

    .PARAMETER Force
        If $true, install even if the tool is already detected on PATH.

    .PARAMETER Scope
        Installation scope: 'user' (default) or 'machine' (requires admin).

    .OUTPUTS
        PSCustomObject:
            ToolId      [string]
            AlreadyInstalled [bool]
            Installed   [bool]
            Skipped     [bool]
            DryRun      [bool]
            Error       [string]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $ToolId,
        [bool]   $DryRun = $false,
        [bool]   $Force  = $false,
        [ValidateSet('user','machine')]
        [string] $Scope  = 'user'
    )

    # Load tool definition from registry
    try {
        # Config module must already be imported by the caller (bootstrap.ps1 imports all)
        $tool = Get-ToolDefinition -ToolId $ToolId
    }
    catch {
        return [PSCustomObject]@{
            ToolId           = $ToolId
            AlreadyInstalled = $false
            Installed        = $false
            Skipped          = $false
            DryRun           = $DryRun
            Error            = "Registry lookup failed: $_"
        }
    }

    # Idempotency gate: check if already installed
    if (-not $Force -and (Test-ToolInstalled -ToolDefinition $tool)) {
        $ver = Get-ToolVersion -ToolDefinition $tool
        Write-Host "✓ $($tool.name) already installed ($ver)" -ForegroundColor Green
        return [PSCustomObject]@{
            ToolId           = $ToolId
            AlreadyInstalled = $true
            Installed        = $false
            Skipped          = $false
            DryRun           = $DryRun
            Error            = $null
        }
    }

    # Special case: windows-feature packages (e.g. OpenSSH)
    if ($tool.packageManager -eq 'windows-feature') {
        return Install-WindowsFeatureTool -Tool $tool -DryRun $DryRun
    }

    # Route to package manager
    $result = $null

    if ($tool.packageManager -eq 'winget' -and (Test-WinGetAvailable)) {
        Write-Host "· Installing $($tool.name) via WinGet..." -ForegroundColor Cyan
        $result = Install-WinGetPackage -PackageId $tool.packageId -DryRun $DryRun -Scope $Scope
    }
    elseif (Test-ChocoAvailable) {
        Write-Host "· Installing $($tool.name) via Chocolatey (WinGet unavailable or not preferred)..." -ForegroundColor Cyan
        # Chocolatey package IDs are typically lowercase tool names
        $chocoId = if ($tool.PSObject.Properties['chocoId']) { $tool.chocoId } else { $tool.id }
        $result  = Install-ChocoPackage -PackageId $chocoId -DryRun $DryRun
    }
    else {
        $result = [PSCustomObject]@{ Success = $false; ExitCode = -1; Output = 'No package manager available.' }
    }

    if ($result.Success -and -not $DryRun) {
        # Post-install verification
        if (Test-ToolInstalled -ToolDefinition $tool) {
            $ver = Get-ToolVersion -ToolDefinition $tool
            Write-Host "✓ $($tool.name) installed successfully ($ver)" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ $($tool.name) installed but command '$($tool.command)' not found on PATH. A shell restart may be required." -ForegroundColor Yellow
        }
    }
    elseif (-not $result.Success -and -not $DryRun) {
        Write-Host "✗ $($tool.name) installation failed (exit code $($result.ExitCode))" -ForegroundColor Red
        Write-Host "  $($result.Output)" -ForegroundColor DarkGray
    }

    return [PSCustomObject]@{
        ToolId           = $ToolId
        AlreadyInstalled = $false
        Installed        = $result.Success
        Skipped          = $false
        DryRun           = $DryRun
        Error            = if (-not $result.Success) { $result.Output } else { $null }
    }
}

function Install-ToolSet {
    <#
    .SYNOPSIS
        Install a list of tools, returning a summary result.

    .PARAMETER ToolIds
        Array of tool ID strings from the registry.

    .PARAMETER DryRun
        Apply dry-run to all operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $ToolIds,
        [bool]   $DryRun = $false,
        [string] $Scope  = 'user'
    )

    $results = @()
    foreach ($id in $ToolIds) {
        $results += Install-Tool -ToolId $id -DryRun $DryRun -Scope $Scope
    }
    return $results
}

# ─── Internal helpers ─────────────────────────────────────────────────────────

function Install-WindowsFeatureTool {
    param(
        [PSCustomObject] $Tool,
        [bool]           $DryRun
    )

    # OpenSSH and similar Windows Optional Features require admin
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "⚠ $($Tool.name) requires administrator privileges to install." -ForegroundColor Yellow
        Write-Host "  Run this script as Administrator, or install manually:" -ForegroundColor Yellow
        Write-Host "  Add-WindowsCapability -Online -Name '$($Tool.packageId)'" -ForegroundColor DarkGray
        return [PSCustomObject]@{
            ToolId           = $Tool.id
            AlreadyInstalled = $false
            Installed        = $false
            Skipped          = $true
            DryRun           = $DryRun
            Error            = "Requires administrator privileges"
        }
    }

    if ($DryRun) {
        Write-Host "[DRYRUN] Would install Windows Feature: $($Tool.packageId)" -ForegroundColor DarkCyan
        return [PSCustomObject]@{
            ToolId = $Tool.id; AlreadyInstalled = $false
            Installed = $true; Skipped = $false; DryRun = $true; Error = $null
        }
    }

    try {
        Add-WindowsCapability -Online -Name $Tool.packageId -ErrorAction Stop | Out-Null
        return [PSCustomObject]@{
            ToolId = $Tool.id; AlreadyInstalled = $false
            Installed = $true; Skipped = $false; DryRun = $false; Error = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            ToolId = $Tool.id; AlreadyInstalled = $false
            Installed = $false; Skipped = $false; DryRun = $false
            Error = $_.Exception.Message
        }
    }
}

