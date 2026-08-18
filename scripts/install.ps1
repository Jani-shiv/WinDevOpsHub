<#
.SYNOPSIS
    Install one or more WinDevOpsHub tools by ID.

.DESCRIPTION
    Installs specific tools from the WinDevOpsHub tool registry.
    Tools are identified by their registry ID (e.g. "terraform", "kubectl").

    Run .\scripts\install.ps1 -ListTools to see all available tool IDs.

.PARAMETER Tool
    One or more tool IDs to install.

.PARAMETER DryRun
    Show what would be installed without making changes.

.PARAMETER Scope
    WinGet installation scope: 'user' (default) or 'machine'.

.PARAMETER ListTools
    List all available tool IDs and exit.

.EXAMPLE
    .\scripts\install.ps1 -Tool terraform
    .\scripts\install.ps1 -Tool terraform,kubectl,helm -DryRun
    .\scripts\install.ps1 -ListTools

.NOTES
    WinDevOpsHub — scripts/install.ps1
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string[]] $Tool,

    [switch] $DryRun,

    [ValidateSet('user','machine')]
    [string] $Scope = 'user',

    [switch] $ListTools
)

$ErrorActionPreference = 'Stop'

# Load modules
$repoRoot   = Split-Path $PSScriptRoot -Parent
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
    $dir = Join-Path $modulesDir $Name
    if (Test-Path $dir) { Get-ChildItem $dir -Filter '*.ps1' | ForEach-Object { . $_.FullName }; return }
    throw "Module '$Name' not found."
}

Import-WDOHModule 'Core'
Import-WDOHModule 'PackageManager'
Import-WDOHModule 'System'

# List tools mode
if ($ListTools) {
    Write-Host "`nAvailable tools in the WinDevOpsHub registry:" -ForegroundColor Cyan
    Write-Host ('─' * 60) -ForegroundColor DarkGray
    $registry = Get-ToolRegistry
    $registry | Sort-Object category, id |
        Format-Table -Property @(
            @{L='ID';E={$_.id}},
            @{L='Name';E={$_.name}},
            @{L='Category';E={$_.category}},
            @{L='Command';E={$_.command}}
        ) -AutoSize
    exit 0
}

if (-not $Tool -or $Tool.Count -eq 0) {
    Write-Host "Usage: .\install.ps1 -Tool <tool-id> [,<tool-id>...]" -ForegroundColor Yellow
    Write-Host "       .\install.ps1 -ListTools" -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host "WinDevOpsHub Tool Installer" -ForegroundColor Cyan
Write-Host ('─' * 40) -ForegroundColor DarkGray

if ($DryRun) {
    Write-Host "[DRY RUN — no changes will be made]" -ForegroundColor Yellow
}
Write-Host ''

$results = Install-ToolSet -ToolIds $Tool -DryRun $DryRun.IsPresent -Scope $Scope

$failed = @($results | Where-Object { -not $_.AlreadyInstalled -and -not $_.Installed -and -not $_.Skipped })

if ($failed.Count -gt 0) {
    Write-Host "`n⚠ $($failed.Count) tool(s) failed to install. Run .\scripts\doctor.ps1 for diagnostics." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✓ Done. Run .\scripts\doctor.ps1 to verify your environment." -ForegroundColor Green
exit 0
