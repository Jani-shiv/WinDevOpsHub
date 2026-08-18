#Requires -Version 7.0

<#
.SYNOPSIS
    Terminal module for WinDevOpsHub — Windows Terminal and shell enhancement diagnostics.

.DESCRIPTION
    Provides functions to detect Windows Terminal (wt.exe) and Clink/Starship.
#>

function Test-WindowsTerminalInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)
}

function Test-ClinkInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command clink -ErrorAction SilentlyContinue)
}

function Get-TerminalSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    return [PSCustomObject]@{
        WindowsTerminal = Test-WindowsTerminalInstalled
        Clink           = Test-ClinkInstalled
    }
}
