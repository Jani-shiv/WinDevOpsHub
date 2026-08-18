<#
.SYNOPSIS
    WinDevOpsHub Environment Doctor

.DESCRIPTION
    Inspects the current system and reports the health of every tool and
    subsystem that WinDevOpsHub manages.

    For each check, the doctor reports:
      ✓  Present and working
      ⚠  Present but with a concern (wrong version, PATH issue, etc.)
      ✗  Missing — with a specific suggested remediation

    Usage:
        .\scripts\doctor.ps1
        .\scripts\doctor.ps1 -Category System
        .\scripts\doctor.ps1 -Json

.PARAMETER Category
    Optional. Limit checks to a specific category:
    All | System | Development | Containers | Kubernetes | Infrastructure | Cloud | Network

.PARAMETER Json
    If specified, output results as JSON (suitable for machine consumption).

.EXAMPLE
    .\scripts\doctor.ps1

.EXAMPLE
    .\scripts\doctor.ps1 -Category Cloud -Json

.NOTES
    Part of WinDevOpsHub — scripts/doctor.ps1
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('All','System','Development','Containers','Kubernetes','Infrastructure','Cloud','Network','Git')]
    [string] $Category = 'All',

    [switch] $Json
)

$ErrorActionPreference = 'Stop'

# ─── Bootstrap: locate and load modules ──────────────────────────────────────

$scriptDir  = $PSScriptRoot
$repoRoot   = Split-Path $scriptDir -Parent
$modulesDir = Join-Path $repoRoot 'modules'

function Import-WDOHModule {
    param([string]$Name)
    $psm1 = Join-Path $modulesDir $Name "$Name.psm1" -ErrorAction SilentlyContinue
    # Try WinDevOpsHub.Name.psm1 naming convention
    $candidates = @(
        (Join-Path $modulesDir $Name "WinDevOpsHub.$Name.psm1"),
        (Join-Path $modulesDir $Name "$Name.psm1")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { Import-Module $c -Force -Global; return }
    }
    # Fallback: dot-source all .ps1 files in the module dir
    $dir = Join-Path $modulesDir $Name
    if (Test-Path $dir) {
        Get-ChildItem $dir -Filter '*.ps1' | ForEach-Object { . $_.FullName }
        return
    }
    throw "Module '$Name' not found at $modulesDir\$Name"
}

# Load in dependency order
Import-WDOHModule 'Core'
Import-WDOHModule 'PackageManager'
Import-WDOHModule 'System'
Import-WDOHModule 'Git'
Import-WDOHModule 'Docker'
Import-WDOHModule 'Kubernetes'
Import-WDOHModule 'Terraform'
Import-WDOHModule 'Cloud'
Import-WDOHModule 'Terminal'
Import-WDOHModule 'Utilities'

# ─── Check result model ───────────────────────────────────────────────────────

$script:AllResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function New-CheckResult {
    param(
        [string] $Category,
        [string] $Name,
        [ValidateSet('Pass','Warn','Fail','Skip')]
        [string] $Status,
        [string] $Detail    = '',
        [string] $Version   = '',
        [string] $Suggested = ''
    )
    return [PSCustomObject]@{
        Category  = $Category
        Name      = $Name
        Status    = $Status
        Detail    = $Detail
        Version   = $Version
        Suggested = $Suggested
    }
}

function Add-Check {
    param([PSCustomObject] $Result)
    $script:AllResults.Add($Result)
}

# ─── Check helpers ────────────────────────────────────────────────────────────

function Invoke-ToolCheck {
    param(
        [string] $Cat,
        [string] $ToolId,
        [string] $DisplayName,
        [string] $Suggested = ''
    )

    try {
        $tool = Get-ToolDefinition -ToolId $ToolId
        if (Test-ToolInstalled -ToolDefinition $tool) {
            $ver = Get-ToolVersion -ToolDefinition $tool
            Add-Check (New-CheckResult -Category $Cat -Name $DisplayName -Status Pass -Version $ver)
        }
        else {
            $suggest = if ($Suggested) { $Suggested } else { "winops install $ToolId  (or: .\scripts\install.ps1 -Tool $ToolId)" }
            Add-Check (New-CheckResult -Category $Cat -Name $DisplayName -Status Fail `
                -Detail "$($tool.command) not found in PATH" `
                -Suggested $suggest)
        }
    }
    catch {
        Add-Check (New-CheckResult -Category $Cat -Name $DisplayName -Status Warn `
            -Detail "Registry lookup failed: $_")
    }
}

# ─── Individual checks ────────────────────────────────────────────────────────

function Test-System {
    # OS
    $platform = Get-PlatformInfo
    Add-Check (New-CheckResult -Category System -Name 'Operating System' -Status Pass `
        -Detail "$($platform.Caption) (Build $($platform.BuildNumber))")

    # Architecture
    Add-Check (New-CheckResult -Category System -Name 'Architecture' -Status Pass `
        -Detail $platform.Architecture)

    # PowerShell version
    if ($platform.PSVersion -ge [version]'7.0') {
        Add-Check (New-CheckResult -Category System -Name 'PowerShell' -Status Pass `
            -Version "v$($platform.PSVersion)" -Detail $platform.PSEdition)
    }
    else {
        Add-Check (New-CheckResult -Category System -Name 'PowerShell' -Status Warn `
            -Version "v$($platform.PSVersion)" `
            -Detail 'PowerShell 7+ recommended' `
            -Suggested 'winget install Microsoft.PowerShell')
    }

    # Admin privileges
    if ($platform.IsAdmin) {
        Add-Check (New-CheckResult -Category System -Name 'Admin Privileges' -Status Pass `
            -Detail 'Running as Administrator')
    }
    else {
        Add-Check (New-CheckResult -Category System -Name 'Admin Privileges' -Status Warn `
            -Detail 'Running as standard user — some installs may require elevation')
    }

    # WinGet
    if (Test-WinGetAvailable) {
        $wgv = Get-WinGetVersion
        Add-Check (New-CheckResult -Category System -Name 'WinGet' -Status Pass -Version "v$wgv")
    }
    else {
        Add-Check (New-CheckResult -Category System -Name 'WinGet' -Status Fail `
            -Detail 'winget not found' `
            -Suggested 'Install "App Installer" from the Microsoft Store or update Windows.')
    }

    # PATH duplicates
    $dups = Get-PathDuplicates
    if ($dups.Count -gt 0) {
        Add-Check (New-CheckResult -Category System -Name 'PATH Duplicates' -Status Warn `
            -Detail "Duplicate PATH entries detected: $($dups -join ', ')" `
            -Suggested 'Clean duplicate entries from User and System PATH environment variables.')
    }
    else {
        Add-Check (New-CheckResult -Category System -Name 'PATH' -Status Pass -Detail 'No duplicates detected')
    }

    # Execution Policy
    $policy = (Get-ExecutionPolicy).ToString()
    if ($policy -in @('RemoteSigned','Unrestricted','Bypass')) {
        Add-Check (New-CheckResult -Category System -Name 'Execution Policy' -Status Pass `
            -Detail "LocalMachine: $policy")
    }
    else {
        Add-Check (New-CheckResult -Category System -Name 'Execution Policy' -Status Fail `
            -Detail "Policy '$policy' may block scripts" `
            -Suggested 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser')
    }
}

function Test-Development {
    Invoke-ToolCheck -Cat Development -ToolId git          -DisplayName 'Git'
    Invoke-ToolCheck -Cat Development -ToolId github-cli   -DisplayName 'GitHub CLI (gh)'
    Invoke-ToolCheck -Cat Development -ToolId vscode       -DisplayName 'VS Code'
}

function Test-Git {
    # More detailed Git checks beyond simple presence
    Invoke-ToolCheck -Cat Git -ToolId git -DisplayName 'Git'

    if (Get-Command git -ErrorAction SilentlyContinue) {
        # Check user.name
        $userName = git config --global user.name 2>&1
        if ($userName -and $LASTEXITCODE -eq 0) {
            Add-Check (New-CheckResult -Category Git -Name 'git user.name' -Status Pass -Detail $userName)
        }
        else {
            Add-Check (New-CheckResult -Category Git -Name 'git user.name' -Status Warn `
                -Detail 'Not configured' -Suggested 'git config --global user.name "Your Name"')
        }

        # Check user.email
        $userEmail = git config --global user.email 2>&1
        if ($userEmail -and $LASTEXITCODE -eq 0) {
            Add-Check (New-CheckResult -Category Git -Name 'git user.email' -Status Pass -Detail $userEmail)
        }
        else {
            Add-Check (New-CheckResult -Category Git -Name 'git user.email' -Status Warn `
                -Detail 'Not configured' -Suggested 'git config --global user.email "you@example.com"')
        }

        # Check default branch
        $defaultBranch = git config --global init.defaultBranch 2>&1
        if ($defaultBranch -and $LASTEXITCODE -eq 0) {
            Add-Check (New-CheckResult -Category Git -Name 'Default Branch' -Status Pass -Detail $defaultBranch)
        }
        else {
            Add-Check (New-CheckResult -Category Git -Name 'Default Branch' -Status Warn `
                -Detail 'init.defaultBranch not set (defaults to master)' `
                -Suggested 'git config --global init.defaultBranch main')
        }
    }
}

function Test-Containers {
    Invoke-ToolCheck -Cat Containers -ToolId docker -DisplayName 'Docker'

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        if (Test-DockerDaemonRunning) {
            Add-Check (New-CheckResult -Category Containers -Name 'Docker Engine' -Status Pass `
                -Detail 'Daemon is running')
        }
        else {
            Add-Check (New-CheckResult -Category Containers -Name 'Docker Engine' -Status Fail `
                -Detail 'Docker daemon is not running' `
                -Suggested 'Start Docker Desktop from the Start menu or system tray.')
        }
    }
}

function Test-Kubernetes {
    Invoke-ToolCheck -Cat Kubernetes -ToolId kubectl    -DisplayName 'kubectl'
    Invoke-ToolCheck -Cat Kubernetes -ToolId helm       -DisplayName 'Helm'
    Invoke-ToolCheck -Cat Kubernetes -ToolId k9s        -DisplayName 'k9s'
}

function Test-Infrastructure {
    Invoke-ToolCheck -Cat Infrastructure -ToolId terraform -DisplayName 'Terraform'
}

function Test-Cloud {
    Invoke-ToolCheck -Cat Cloud -ToolId aws-cli    -DisplayName 'AWS CLI'
    Invoke-ToolCheck -Cat Cloud -ToolId azure-cli  -DisplayName 'Azure CLI'
    Invoke-ToolCheck -Cat Cloud -ToolId gcloud     -DisplayName 'Google Cloud CLI'
}

function Test-Network {
    # Internet / DNS check
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses('github.com')
        if ($resolved.Count -gt 0) {
            Add-Check (New-CheckResult -Category Network -Name 'DNS' -Status Pass `
                -Detail "github.com resolves to $($resolved[0].IPAddressToString)")
        }
    }
    catch {
        Add-Check (New-CheckResult -Category Network -Name 'DNS' -Status Fail `
            -Detail "Cannot resolve github.com: $_")
    }

    # Connectivity
    if (Test-InternetConnectivity -HostName '1.1.1.1' -TimeoutMs 2000) {
        Add-Check (New-CheckResult -Category Network -Name 'Internet Connectivity' -Status Pass `
            -Detail 'Internet is reachable (1.1.1.1:53)')
    }
    else {
        Add-Check (New-CheckResult -Category Network -Name 'Internet Connectivity' -Status Warn `
            -Detail 'Could not reach 1.1.1.1:53' `
            -Suggested 'Check your internet connection and proxy/firewall settings.')
    }

    # SSH client
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        Add-Check (New-CheckResult -Category Network -Name 'SSH Client' -Status Pass -Detail 'ssh executable present')
    }
    else {
        Add-Check (New-CheckResult -Category Network -Name 'SSH Client' -Status Fail `
            -Detail 'ssh not found' `
            -Suggested 'Install OpenSSH: .\scripts\install.ps1 -Tool openssh')
    }
}

# ─── Dispatcher ───────────────────────────────────────────────────────────────

$checksToRun = switch ($Category) {
    'All'            { @('System','Development','Git','Containers','Kubernetes','Infrastructure','Cloud','Network') }
    'System'         { @('System') }
    'Development'    { @('Development') }
    'Git'            { @('Git') }
    'Containers'     { @('Containers') }
    'Kubernetes'     { @('Kubernetes') }
    'Infrastructure' { @('Infrastructure') }
    'Cloud'          { @('Cloud') }
    'Network'        { @('Network') }
}

foreach ($check in $checksToRun) {
    & "Test-$check"
}

# ─── Output ──────────────────────────────────────────────────────────────────

if ($Json) {
    $script:AllResults | ConvertTo-Json -Depth 5
    exit 0
}

# Human-readable output
Write-Host ''
Write-Host '  WinDevOpsHub — Environment Doctor' -ForegroundColor White
Write-Host ('  ' + '─' * 50) -ForegroundColor DarkGray
Write-Host ''

$currentCat = $null
$passCount  = 0
$warnCount  = 0
$failCount  = 0

foreach ($r in $script:AllResults) {
    if ($r.Category -ne $currentCat) {
        if ($currentCat) { Write-Host '' }
        Write-Host "  $($r.Category)" -ForegroundColor White
        $currentCat = $r.Category
    }

    $icon  = switch ($r.Status) {
        'Pass' { '✓'; $passCount++ }
        'Warn' { '⚠'; $warnCount++ }
        'Fail' { '✗'; $failCount++ }
        'Skip' { '·' }
    }
    $colour = switch ($r.Status) {
        'Pass' { 'Green'  }
        'Warn' { 'Yellow' }
        'Fail' { 'Red'    }
        'Skip' { 'Gray'   }
    }

    $line = "    $icon $($r.Name)"
    if ($r.Version)  { $line += " ($($r.Version))" }
    if ($r.Detail -and $r.Status -ne 'Pass') { $line += " — $($r.Detail)" }

    Write-Host $line -ForegroundColor $colour

    if ($r.Suggested -and $r.Status -in @('Fail','Warn')) {
        Write-Host "        → $($r.Suggested)" -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host ('  ' + '─' * 50) -ForegroundColor DarkGray
$summary = "  Summary: $passCount passed  $warnCount warnings  $failCount failed"
$sumColor = if ($failCount -gt 0) { 'Red' } elseif ($warnCount -gt 0) { 'Yellow' } else { 'Green' }
Write-Host $summary -ForegroundColor $sumColor
Write-Host ''

# Exit code: 0 = all pass, 1 = warnings, 2 = failures
if ($failCount -gt 0) { exit 2 }
if ($warnCount -gt 0) { exit 1 }
exit 0
