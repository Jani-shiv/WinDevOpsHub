<#
.SYNOPSIS
    Structured error handling for WinDevOpsHub.

.DESCRIPTION
    Provides a consistent error object model so every failure can communicate:
    - What failed (operation name)
    - Why it failed (reason)
    - What was attempted (context)
    - Recommended next action (suggested)
    - Whether it is recoverable

    Functions never use empty catch blocks.
    Errors propagate through structured objects rather than raw exceptions.

.NOTES
    Part of WinDevOpsHub · modules/Core
#>

#Requires -Version 7.0

# ─── Error Object Factory ────────────────────────────────────────────────────

function New-WDOHError {
    <#
    .SYNOPSIS
        Create a structured WinDevOpsHub error object.

    .PARAMETER Operation
        What operation was being performed (e.g. "Install Git").

    .PARAMETER Reason
        Why it failed (e.g. "WinGet returned exit code 1").

    .PARAMETER Context
        Additional context: command run, parameters used, etc.

    .PARAMETER Suggested
        Human-readable recommended next action.

    .PARAMETER IsRecoverable
        Whether the caller can attempt a fallback. Default: $false.

    .PARAMETER InnerException
        The underlying .NET exception object, if any.

    .OUTPUTS
        PSCustomObject with a consistent shape.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [string]    $Operation,
        [Parameter(Mandatory)] [string]    $Reason,
        [string]    $Context       = '',
        [string]    $Suggested     = '',
        [bool]      $IsRecoverable = $false,
        [System.Exception] $InnerException = $null
    )

    return [PSCustomObject]@{
        PSTypeName     = 'WinDevOpsHub.Error'
        Operation      = $Operation
        Reason         = $Reason
        Context        = $Context
        Suggested      = $Suggested
        IsRecoverable  = $IsRecoverable
        InnerException = $InnerException
        Timestamp      = (Get-Date)
    }
}

function Write-WDOHError {
    <#
    .SYNOPSIS
        Write a WinDevOpsHub error object to the console in a human-readable format.

    .PARAMETER Err
        A PSCustomObject produced by New-WDOHError.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Err
    )
    process {
        Write-Host ''
        Write-Host "✗ Error: $($Err.Operation)" -ForegroundColor Red
        Write-Host "  Reason:    $($Err.Reason)"    -ForegroundColor Red

        if ($Err.Context) {
            Write-Host "  Context:   $($Err.Context)"   -ForegroundColor DarkGray
        }
        if ($Err.Suggested) {
            Write-Host "  Suggested: $($Err.Suggested)" -ForegroundColor Yellow
        }
        if ($Err.InnerException) {
            Write-Host "  Exception: $($Err.InnerException.Message)" -ForegroundColor DarkGray
        }
        Write-Host ''
    }
}

function Invoke-WithErrorHandling {
    <#
    .SYNOPSIS
        Execute a script block and convert any exception to a WinDevOpsHub error object.

    .PARAMETER Operation
        Human-readable name of the operation being attempted.

    .PARAMETER ScriptBlock
        The code to execute.

    .PARAMETER Suggested
        Optional: recommended action on failure.

    .PARAMETER IsRecoverable
        If $true, callers can catch and attempt a fallback.

    .RETURNS
        The return value of ScriptBlock on success, or a WDOHError object on failure.
        Callers should check `$result.PSTypeName -eq 'WinDevOpsHub.Error'`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]      $Operation,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [string] $Suggested     = '',
        [bool]   $IsRecoverable = $false
    )

    try {
        return & $ScriptBlock
    }
    catch {
        return New-WDOHError `
            -Operation      $Operation `
            -Reason         $_.Exception.Message `
            -Context        $_.InvocationInfo.PositionMessage `
            -Suggested      $Suggested `
            -IsRecoverable  $IsRecoverable `
            -InnerException $_.Exception
    }
}

function Test-IsWDOHError {
    <#
    .SYNOPSIS
        Return $true if the argument is a WinDevOpsHub error object.
    #>
    [OutputType([bool])]
    param([PSCustomObject] $Value)

    return ($null -ne $Value) -and ($Value.PSTypeName -eq 'WinDevOpsHub.Error')
}

