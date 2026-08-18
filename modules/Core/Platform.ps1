<#
.SYNOPSIS
    Platform detection for WinDevOpsHub.

.DESCRIPTION
    Provides reliable, cached detection of:
    - Operating system identity and version
    - CPU architecture
    - Current user's privilege level (administrator / standard)
    - PowerShell version and edition
    - Execution policy

    All functions return structured objects so callers can use property access
    rather than parsing strings.

.NOTES
    Part of WinDevOpsHub · modules/Core
#>

#Requires -Version 7.0

# ─── Cached state (populated on first call) ────────────────────────────────

$script:_PlatformInfo = $null

# ─── Public API ───────────────────────────────────────────────────────────────

function Get-PlatformInfo {
    <#
    .SYNOPSIS
        Return a PSCustomObject describing this Windows platform.

    .OUTPUTS
        PSCustomObject with properties:
            IsWindows       [bool]
            Caption         [string]  e.g. "Microsoft Windows 11 Enterprise"
            Version         [string]  e.g. "10.0.22621"
            BuildNumber     [string]  e.g. "22621"
            Architecture    [string]  "x64" | "x86" | "ARM64"
            IsAdmin         [bool]
            PSVersion       [version]
            PSEdition       [string]  "Core" | "Desktop"
            ExecutionPolicy [string]
            SystemDrive     [string]  e.g. "C:"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if ($script:_PlatformInfo) { return $script:_PlatformInfo }

    $os   = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cpu  = Get-CimInstance -ClassName Win32_Processor       -ErrorAction Stop | Select-Object -First 1

    # Architecture normalisation
    # Win32_Processor.Architecture: 0=x86, 9=x64/AMD64, 12=ARM64
    $arch = switch ($cpu.Architecture) {
        9  { 'x64'   }
        12 { 'ARM64' }
        0  { 'x86'   }
        default { 'Unknown' }
    }

    # Privilege detection
    $principal = [Security.Principal.WindowsPrincipal] `
                 [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin   = $principal.IsInRole(
                     [Security.Principal.WindowsBuiltInRole]::Administrator)

    # Execution policy at effective scope
    $policy = (Get-ExecutionPolicy).ToString()

    $info = [PSCustomObject]@{
        IsWindows       = $IsWindows
        Caption         = $os.Caption
        Version         = $os.Version
        BuildNumber     = $os.BuildNumber
        Architecture    = $arch
        IsAdmin         = $isAdmin
        PSVersion       = $PSVersionTable.PSVersion
        PSEdition       = $PSVersionTable.PSEdition
        ExecutionPolicy = $policy
        SystemDrive     = $os.SystemDrive
        OSArchitecture  = $os.OSArchitecture
        CPUName         = $cpu.Name
    }

    $script:_PlatformInfo = $info
    return $info
}

function Assert-Windows {
    <#
    .SYNOPSIS
        Throw a terminating error if not running on Windows.
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        throw [System.PlatformNotSupportedException]::new(
            'WinDevOpsHub requires Windows. Current platform is not Windows.')
    }
}

function Assert-PowerShellVersion {
    <#
    .SYNOPSIS
        Throw if the running PowerShell version is below the minimum.

    .PARAMETER Minimum
        The minimum acceptable [version]. Default: 7.0
    #>
    [CmdletBinding()]
    param(
        [version] $Minimum = '7.0'
    )

    if ($PSVersionTable.PSVersion -lt $Minimum) {
        throw "WinDevOpsHub requires PowerShell $Minimum or later. " +
              "Current: $($PSVersionTable.PSVersion). " +
              "Install PowerShell 7+ from: https://aka.ms/powershell"
    }
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Return $true if the current process is running elevated.
    #>
    [OutputType([bool])]
    param()

    $principal = [Security.Principal.WindowsPrincipal] `
                 [Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsBuildFriendlyName {
    <#
    .SYNOPSIS
        Map a Windows build number to a friendly release name.

    .PARAMETER BuildNumber
        The OS build number string. Defaults to current OS build.
    #>
    [OutputType([string])]
    param(
        [string] $BuildNumber = (Get-CimInstance Win32_OperatingSystem).BuildNumber
    )

    # Key Windows 10/11 release milestones
    $map = [ordered]@{
        '26100' = 'Windows 11 24H2'
        '22631' = 'Windows 11 23H2'
        '22621' = 'Windows 11 22H2'
        '22000' = 'Windows 11 21H2'
        '19045' = 'Windows 10 22H2'
        '19044' = 'Windows 10 21H2'
        '19043' = 'Windows 10 21H1'
        '19042' = 'Windows 10 20H2'
        '19041' = 'Windows 10 2004'
        '18363' = 'Windows 10 1909'
        '18362' = 'Windows 10 1903'
    }

    if ($map.Contains($BuildNumber)) { return $map[$BuildNumber] }
    return "Windows (Build $BuildNumber)"
}

function Reset-PlatformCache {
    <#
    .SYNOPSIS
        Clear the cached platform info — primarily for testing.
    #>
    $script:_PlatformInfo = $null
}

