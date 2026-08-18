<#
.SYNOPSIS
    WinDevOpsHub uninstall — remove managed tools via WinGet.

.DESCRIPTION
    Uninstalls tools that were installed by WinDevOpsHub.
    Always asks for confirmation before uninstalling.
    Does NOT remove tools that were not installed by WinGet.

.PARAMETER Tool
    One or more tool IDs to uninstall (from the registry).

.PARAMETER DryRun
    Show what would be uninstalled without making changes.

.EXAMPLE
    .\scripts\uninstall.ps1 -Tool terraform
    .\scripts\uninstall.ps1 -Tool terraform,kubectl -DryRun

.NOTES
    WinDevOpsHub — scripts/uninstall.ps1
#>

#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)]
    [string[]] $Tool,

    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path $PSScriptRoot -Parent
$modulesDir = Join-Path $repoRoot 'modules'

function Import-WDOHModule {
    param([string]$Name)
    $candidates = @(
        (Join-Path $modulesDir $Name "WinDevOpsHub.$Name.psm1"),
        (Join-Path $modulesDir $Name "$Name.psm1")
    )
    foreach ($c in $candidates) { if (Test-Path $c) { Import-Module $c -Force -Global; return } }
    $dir = Join-Path $modulesDir $Name
    if (Test-Path $dir) { Get-ChildItem $dir -Filter '*.ps1' | ForEach-Object { . $_.FullName }; return }
    throw "Module '$Name' not found."
}

Import-WDOHModule 'Core'
Import-WDOHModule 'PackageManager'

Write-Host ''
Write-Host 'WinDevOpsHub — Uninstall' -ForegroundColor Cyan
Write-Host ('─' * 40) -ForegroundColor DarkGray

if ($DryRun) {
    Write-Host '[DRY RUN]' -ForegroundColor Yellow
    Write-Host ''
}

foreach ($toolId in $Tool) {
    try {
        $toolDef = Get-ToolDefinition -ToolId $toolId

        if (-not (Test-ToolInstalled -ToolDefinition $toolDef)) {
            Write-Host "· $($toolDef.name) is not currently installed — skipping." -ForegroundColor Gray
            continue
        }

        if ($DryRun) {
            Write-Host "[DRYRUN] Would uninstall: $($toolDef.name) (WinGet ID: $($toolDef.packageId))" -ForegroundColor DarkCyan
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($toolDef.name, 'Uninstall')) { continue }

        Write-Host "Uninstalling $($toolDef.name)..." -ForegroundColor Cyan
        $out = winget uninstall --id $toolDef.packageId --exact --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $($toolDef.name) uninstalled." -ForegroundColor Green
        }
        else {
            Write-Host "✗ Uninstall failed (exit $LASTEXITCODE):" -ForegroundColor Red
            Write-Host "  $($out -join ' ')" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "✗ Error processing '$toolId': $_" -ForegroundColor Red
    }
}

Write-Host ''
