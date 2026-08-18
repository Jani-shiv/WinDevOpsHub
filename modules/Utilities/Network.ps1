#Requires -Version 7.0

<#
.SYNOPSIS
    Network utilities module for WinDevOpsHub — DNS, port testing, and connectivity checks.

.DESCRIPTION
    Provides lightweight functions to verify internet connectivity, DNS resolution, and TCP port checks.
#>

function Test-InternetConnectivity {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string] $HostName = '1.1.1.1',
        [int] $TimeoutMs = 2000
    )

    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $tcp.BeginConnect($HostName, 53, $null, $null)
        $success = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($success) {
            $tcp.EndConnect($asyncResult)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    }
    catch {
        return $false
    }
}

function Test-TcpPortOpen {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $ComputerName,
        [Parameter(Mandatory)] [int] $Port,
        [int] $TimeoutMs = 1500
    )

    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
        $success = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($success) {
            $tcp.EndConnect($asyncResult)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    }
    catch {
        return $false
    }
}
