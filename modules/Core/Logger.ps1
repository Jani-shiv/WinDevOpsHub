<#
.SYNOPSIS
    Structured logging for WinDevOpsHub.

.DESCRIPTION
    Provides colour-coded, timestamped log output across five severity levels:
    DEBUG, INFO, WARN, ERROR, SUCCESS.

    Log entries are written to the host console. When a log file path is
    configured, entries are also appended to that file (without colour codes).

    Design principles:
    - Never expose secrets in log output.
    - Structured format: [LEVEL] HH:mm:ss message
    - Callers do not need to handle formatting.

.NOTES
    Part of WinDevOpsHub · modules/Core
#>

#Requires -Version 7.0

# ─── Module-level state ──────────────────────────────────────────────────────

# Log file path — populated by Initialize-Logger or left empty for console-only.
$script:LogFilePath = $null

# Minimum level to emit. Default: INFO (DEBUG is suppressed unless -Verbose).
$script:MinLevel = 'INFO'

# Mapping level names to sort order for filtering.
$script:LevelOrder = @{
    DEBUG   = 0
    INFO    = 1
    WARN    = 2
    ERROR   = 3
    SUCCESS = 1   # SUCCESS is informational; always shown alongside INFO
}

# ─── Public API ──────────────────────────────────────────────────────────────

function Initialize-Logger {
    <#
    .SYNOPSIS
        Configure the logger for this session.

    .PARAMETER LogFile
        Optional. Absolute path to a log file. Directory will be created if needed.

    .PARAMETER Level
        Minimum log level to emit: DEBUG | INFO | WARN | ERROR. Default: INFO.

    .EXAMPLE
        Initialize-Logger -LogFile 'C:\Logs\windevopshub.log' -Level DEBUG
    #>
    [CmdletBinding()]
    param(
        [string]  $LogFile = $null,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]  $Level   = 'INFO'
    )

    $script:MinLevel = $Level

    if ($LogFile) {
        $dir = Split-Path $LogFile -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $script:LogFilePath = $LogFile
        Write-LogEntry -Level INFO -Message "Logger initialised. Log file: $LogFile"
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Emit an INFO-level log entry.

    .PARAMETER Message
        The message string to log.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][string] $Message)
    process { Write-LogEntry -Level INFO -Message $Message }
}

function Write-LogInfo    { param([string]$Message) Write-LogEntry -Level INFO    -Message $Message }
function Write-LogDebug   { param([string]$Message) Write-LogEntry -Level DEBUG   -Message $Message }
function Write-LogWarn    { param([string]$Message) Write-LogEntry -Level WARN    -Message $Message }
function Write-LogError   { param([string]$Message) Write-LogEntry -Level ERROR   -Message $Message }
function Write-LogSuccess { param([string]$Message) Write-LogEntry -Level SUCCESS -Message $Message }

# ─── Internal ─────────────────────────────────────────────────────────────────

function Write-LogEntry {
    [CmdletBinding()]
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR','SUCCESS')]
        [string] $Level,
        [string] $Message
    )

    # Level filtering (DEBUG suppressed unless MinLevel=DEBUG)
    $currentOrder = $script:LevelOrder[$Level]
    $minOrder     = $script:LevelOrder[$script:MinLevel]
    if ($Level -ne 'SUCCESS' -and $currentOrder -lt $minOrder) { return }

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $padded    = $Level.PadRight(7)   # align columns
    $plain     = "[$padded] $timestamp  $Message"

    # Console colour per level
    $colour = switch ($Level) {
        'DEBUG'   { 'DarkGray'  }
        'INFO'    { 'Cyan'      }
        'WARN'    { 'Yellow'    }
        'ERROR'   { 'Red'       }
        'SUCCESS' { 'Green'     }
    }

    # Prefix symbol for readability
    $symbol = switch ($Level) {
        'DEBUG'   { '·' }
        'INFO'    { '·' }
        'WARN'    { '⚠' }
        'ERROR'   { '✗' }
        'SUCCESS' { '✓' }
    }

    Write-Host "$symbol [$padded] $timestamp  $Message" -ForegroundColor $colour

    # Append to log file if configured (no ANSI codes)
    if ($script:LogFilePath) {
        try {
            Add-Content -LiteralPath $script:LogFilePath -Value $plain -Encoding UTF8
        }
        catch {
            # Non-fatal: we don't want a logging failure to crash callers
            Write-Warning "Logger: Could not write to log file '$($script:LogFilePath)': $_"
        }
    }
}

# ─── Section header helper ────────────────────────────────────────────────────

function Write-LogSection {
    <#
    .SYNOPSIS
        Emit a visual section separator to improve readability.
    #>
    [CmdletBinding()]
    param([string] $Title)

    $line = '─' * 60
    Write-Host ''
    Write-Host $line        -ForegroundColor DarkGray
    Write-Host "  $Title"  -ForegroundColor White
    Write-Host $line        -ForegroundColor DarkGray

    if ($script:LogFilePath) {
        $plain = "`n$('─' * 60)`n  $Title`n$('─' * 60)"
        Add-Content -LiteralPath $script:LogFilePath -Value $plain -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

# Export only the public surface
