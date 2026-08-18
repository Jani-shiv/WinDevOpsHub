<#
.SYNOPSIS
    Configuration loading and validation for WinDevOpsHub.

.DESCRIPTION
    Loads JSON configuration files (tools registry, profiles, default settings)
    and provides a strongly-typed interface for callers.

    Principles:
    - Configuration drives behaviour; code does not hardcode tool lists.
    - Invalid config is rejected with a clear error, not silently ignored.
    - Profile resolution merges parent profiles before returning a tool list.

.NOTES
    Part of WinDevOpsHub · modules/Core
#>

#Requires -Version 7.0

# ─── Cached state ──────────────────────────────────────────────────────────

$script:_ToolRegistry = $null
$script:_DefaultConfig = $null
$script:_ProfileCache  = @{}

# ─── Paths ─────────────────────────────────────────────────────────────────

function Get-ConfigRoot {
    <#
    .SYNOPSIS
        Return the absolute path to the config/ directory.
    #>
    # Walk up from this file's location to the repo root, then into config/
    $here   = $PSScriptRoot                          # modules/Core
    $root   = Split-Path (Split-Path $here -Parent) -Parent  # repo root
    return Join-Path $root 'config'
}

# ─── Tool Registry ─────────────────────────────────────────────────────────

function Get-ToolRegistry {
    <#
    .SYNOPSIS
        Load and return the tool registry from config/tools.json.

    .OUTPUTS
        Array of tool definition objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    if ($script:_ToolRegistry) { return $script:_ToolRegistry }

    $path = Join-Path (Get-ConfigRoot) 'tools.json'
    if (-not (Test-Path $path)) {
        throw "Tool registry not found: $path"
    }

    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json

    # Validate required fields on each tool entry
    foreach ($tool in $raw.tools) {
        if (-not $tool.id)      { throw "Tool entry missing 'id' field in tools.json"    }
        if (-not $tool.name)    { throw "Tool entry '$($tool.id)' missing 'name'"        }
        if (-not $tool.command) { throw "Tool entry '$($tool.id)' missing 'command'"     }
    }

    $script:_ToolRegistry = $raw.tools
    return $script:_ToolRegistry
}

function Get-ToolDefinition {
    <#
    .SYNOPSIS
        Retrieve a single tool definition by its ID.

    .PARAMETER ToolId
        The tool identifier string (e.g. "git", "terraform").
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string] $ToolId
    )

    $registry = Get-ToolRegistry
    $tool = $registry | Where-Object { $_.id -eq $ToolId } | Select-Object -First 1

    if (-not $tool) {
        throw "Tool '$ToolId' not found in registry. Check config/tools.json."
    }
    return $tool
}

# ─── Default Configuration ─────────────────────────────────────────────────

function Get-DefaultConfig {
    <#
    .SYNOPSIS
        Load the default configuration from config/default.json.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if ($script:_DefaultConfig) { return $script:_DefaultConfig }

    $path = Join-Path (Get-ConfigRoot) 'default.json'
    if (-not (Test-Path $path)) {
        throw "Default config not found: $path"
    }

    $script:_DefaultConfig = Get-Content -LiteralPath $path -Raw -Encoding UTF8 |
        ConvertFrom-Json

    return $script:_DefaultConfig
}

# ─── Profiles ──────────────────────────────────────────────────────────────

function Get-Profile {
    <#
    .SYNOPSIS
        Load an installation profile and resolve its tool list.

    .PARAMETER ProfileName
        The profile name: Minimal | DevOps | AWS | Azure | Kubernetes | Full

    .OUTPUTS
        PSCustomObject with:
            Name    [string]
            Tools   [string[]]  — resolved, deduplicated list of tool IDs
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Minimal','DevOps','AWS','Azure','Kubernetes','Full')]
        [string] $ProfileName
    )

    $key = $ProfileName.ToLower()
    if ($script:_ProfileCache.ContainsKey($key)) {
        return $script:_ProfileCache[$key]
    }

    $path = Join-Path (Get-ConfigRoot) "profiles\$key.json"
    if (-not (Test-Path $path)) {
        throw "Profile '$ProfileName' not found at: $path"
    }

    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json

    # Resolve parent profile first (additive composition)
    $toolList = [System.Collections.Generic.List[string]]::new()

    if ($raw.extends) {
        $parent = Get-Profile -ProfileName $raw.extends
        $toolList.AddRange([string[]]$parent.Tools)
    }

    foreach ($toolId in $raw.tools) {
        if (-not $toolList.Contains($toolId)) {
            $toolList.Add($toolId)
        }
    }

    $resolved = [PSCustomObject]@{
        Name        = $raw.name
        Description = $raw.description
        Extends     = $raw.extends
        Tools       = $toolList.ToArray()
    }

    $script:_ProfileCache[$key] = $resolved
    return $resolved
}

function Get-AllProfileNames {
    <#
    .SYNOPSIS
        Return the list of all available profile names.
    #>
    [OutputType([string[]])]
    param()
    return @('Minimal','DevOps','AWS','Azure','Kubernetes','Full')
}

# ─── Cache management ──────────────────────────────────────────────────────

function Reset-ConfigCache {
    <#
    .SYNOPSIS
        Clear all cached configuration — primarily for testing.
    #>
    $script:_ToolRegistry = $null
    $script:_DefaultConfig = $null
    $script:_ProfileCache  = @{}
}

