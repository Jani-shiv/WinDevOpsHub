<#
.SYNOPSIS
    WinDevOpsHub Bootstrap — Make Windows DevOps-Ready

.DESCRIPTION
    The primary entry point for WinDevOpsHub.

    Detects the current system state, then installs the tools defined by the
    selected profile. All operations are idempotent: already-installed tools
    are skipped with a clear status message.

    Profiles:
        Minimal    — Git, shell tools, utilities
        DevOps     — Minimal + Docker, kubectl, Helm, Terraform
        AWS        — DevOps + AWS CLI
        Azure      — DevOps + Azure CLI
        Kubernetes — DevOps + full k8s toolchain
        Full       — All stable tools

    Safety:
        -DryRun      Show what would happen without making any changes
        -Confirm     Prompt before each install (default: true)

.PARAMETER Profile
    Installation profile to apply. Default: Minimal

.PARAMETER DryRun
    Do not install anything. Show what would be installed.

.PARAMETER Confirm
    Prompt for confirmation before installing each tool. Default: $true

.PARAMETER Scope
    WinGet installation scope: 'user' (default) or 'machine' (requires admin).

.PARAMETER LogFile
    Optional path to write a log file.

.EXAMPLE
    .\scripts\bootstrap.ps1

.EXAMPLE
    .\scripts\bootstrap.ps1 -Profile DevOps -DryRun

.EXAMPLE
    .\scripts\bootstrap.ps1 -Profile Full -Scope machine

.NOTES
    WinDevOpsHub — scripts/bootstrap.ps1
    https://github.com/Jani-shiv/WinDevOpsHub
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Minimal','DevOps','AWS','Azure','Kubernetes','Full')]
    [string] $Profile = 'Minimal',

    [switch] $DryRun,

    [switch] $NonInteractive,

    [ValidateSet('user','machine')]
    [string] $Scope = 'user',

    [string] $LogFile = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ─── Banner ──────────────────────────────────────────────────────────────────

function Write-Banner {
    $banner = @'

  ██╗    ██╗██╗███╗   ██╗██████╗ ███████╗██╗   ██╗ ██████╗ ██████╗ ███████╗
  ██║    ██║██║████╗  ██║██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔══██╗██╔════╝
  ██║ █╗ ██║██║██╔██╗ ██║██║  ██║█████╗  ██║   ██║██║   ██║██████╔╝███████╗
  ██║███╗██║██║██║╚██╗██║██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║██╔═══╝ ╚════██║
  ╚███╔███╔╝██║██║ ╚████║██████╔╝███████╗ ╚████╔╝ ╚██████╔╝██║     ███████║
   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═╝     ╚══════╝

  WinDevOpsHub — Make Windows DevOps-Ready
  https://github.com/Jani-shiv/WinDevOpsHub

'@
    Write-Host $banner -ForegroundColor Cyan
}

# ─── Module loader ────────────────────────────────────────────────────────────

$scriptDir  = $PSScriptRoot
$repoRoot   = Split-Path $scriptDir -Parent
$modulesDir = Join-Path $repoRoot 'modules'

function Import-WDOHModule {
    param([string]$Name)
    $candidates = @(
        (Join-Path $modulesDir $Name "WinDevOpsHub.$Name.psm1"),
        (Join-Path $modulesDir $Name "$Name.psm1")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { Import-Module $c -Force -Global; return }
    }
    # Fallback: dot-source all .ps1 files
    $dir = Join-Path $modulesDir $Name
    if (Test-Path $dir) {
        Get-ChildItem $dir -Filter '*.ps1' | ForEach-Object { . $_.FullName }
        return
    }
    throw "Module '$Name' not found."
}

Import-WDOHModule 'Core'
Import-WDOHModule 'PackageManager'
Import-WDOHModule 'System'

# ─── Initialise logger ───────────────────────────────────────────────────────

Initialize-Logger -LogFile $LogFile -Level INFO

# ─── Entry point ─────────────────────────────────────────────────────────────

Write-Banner

if ($DryRun) {
    Write-Host '  ┌─────────────────────────────────────────────┐' -ForegroundColor Yellow
    Write-Host '  │  DRY RUN MODE — No changes will be made     │' -ForegroundColor Yellow
    Write-Host '  └─────────────────────────────────────────────┘' -ForegroundColor Yellow
    Write-Host ''
}

# ─── Step 1: Platform validation ─────────────────────────────────────────────

Write-LogSection 'Platform Check'

try { Assert-Windows }
catch {
    Write-LogError "Not running on Windows. WinDevOpsHub requires Windows."
    exit 1
}

try { Assert-PowerShellVersion -Minimum '7.0' }
catch {
    Write-LogError $_
    exit 1
}

$platform = Get-PlatformInfo
Write-LogSuccess "$($platform.Caption) — Build $($platform.BuildNumber) — $($platform.Architecture)"
Write-LogInfo   "PowerShell $($platform.PSVersion) ($($platform.PSEdition))"
Write-LogInfo   "Execution Policy: $($platform.ExecutionPolicy)"

if ($Scope -eq 'machine' -and -not $platform.IsAdmin) {
    Write-LogError "Machine-scope installation requires administrator privileges."
    Write-LogError "Re-run this script as Administrator, or use -Scope user."
    exit 1
}

if (-not $platform.IsAdmin) {
    Write-LogWarn "Running as standard user. Some tools may require admin for system-wide install."
    Write-LogInfo "Using user scope (no elevation required)."
}

# ─── Step 2: Package manager check ───────────────────────────────────────────

Write-LogSection 'Package Manager'

if (Test-WinGetAvailable) {
    Write-LogSuccess "WinGet v$(Get-WinGetVersion) available"
}
else {
    Write-LogWarn "WinGet not found."
    if (Test-ChocoAvailable) {
        Write-LogInfo "Chocolatey v$(Get-ChocoVersion) available as fallback."
    }
    else {
        Write-LogError "No supported package manager found (WinGet or Chocolatey)."
        Write-LogError "Install WinGet: https://github.com/microsoft/winget-cli"
        exit 1
    }
}

# ─── Step 3: Resolve profile ─────────────────────────────────────────────────

Write-LogSection "Profile: $Profile"

try {
    $resolvedProfile = Get-Profile -ProfileName $Profile
}
catch {
    Write-LogError "Failed to load profile '$Profile': $_"
    exit 1
}

Write-LogInfo "$($resolvedProfile.Name) — $($resolvedProfile.Description)"
Write-LogInfo "Tools in this profile ($($resolvedProfile.Tools.Count)):"
foreach ($t in $resolvedProfile.Tools) { Write-Host "    · $t" -ForegroundColor Gray }
Write-Host ''

# ─── Step 4: Confirmation ────────────────────────────────────────────────────

if (-not $DryRun -and -not $NonInteractive) {
    Write-Host "Proceed with installation of profile '$Profile'? " -NoNewline -ForegroundColor Yellow
    $answer = Read-Host "[y/N]"
    if ($answer -notmatch '^[yY]') {
        Write-LogInfo "Installation cancelled by user."
        exit 0
    }
}

# ─── Step 5: Install tools ───────────────────────────────────────────────────

Write-LogSection 'Installing Tools'

$results = Install-ToolSet -ToolIds $resolvedProfile.Tools -DryRun $DryRun.IsPresent -Scope $Scope

# ─── Step 6: Summary ─────────────────────────────────────────────────────────

Write-LogSection 'Summary'

$alreadyInstalled = @($results | Where-Object { $_.AlreadyInstalled })
$installed        = @($results | Where-Object { $_.Installed -and -not $_.AlreadyInstalled })
$skipped          = @($results | Where-Object { $_.Skipped })
$failed           = @($results | Where-Object { -not $_.AlreadyInstalled -and -not $_.Installed -and -not $_.Skipped })

if ($alreadyInstalled.Count -gt 0) {
    Write-LogSuccess "Already installed ($($alreadyInstalled.Count)): $($alreadyInstalled.ToolId -join ', ')"
}
if ($installed.Count -gt 0) {
    Write-LogSuccess "Newly installed ($($installed.Count)): $($installed.ToolId -join ', ')"
}
if ($skipped.Count -gt 0) {
    Write-LogWarn "Skipped (needs admin) ($($skipped.Count)): $($skipped.ToolId -join ', ')"
}
if ($failed.Count -gt 0) {
    Write-LogError "Failed ($($failed.Count)):"
    foreach ($f in $failed) {
        Write-Host "    ✗ $($f.ToolId): $($f.Error)" -ForegroundColor Red
    }
}

Write-Host ''
if ($DryRun) {
    Write-Host '  Dry run complete. No changes were made.' -ForegroundColor Yellow
}
elseif ($failed.Count -eq 0) {
    Write-Host '  ✓ Bootstrap complete. Run .\scripts\doctor.ps1 to verify your environment.' -ForegroundColor Green
}
else {
    Write-Host '  ⚠ Bootstrap completed with errors. Run .\scripts\doctor.ps1 for details.' -ForegroundColor Yellow
}
Write-Host ''

exit ($failed.Count -gt 0 ? 1 : 0)
