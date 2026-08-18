#Requires -Version 7.0

<#
.SYNOPSIS
    Kubernetes module for WinDevOpsHub — kubectl, helm, and k8s tooling diagnostics.

.DESCRIPTION
    Provides functions to detect kubectl, helm, k9s and inspect current cluster context.
#>

function Test-KubectlInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command kubectl -ErrorAction SilentlyContinue)
}

function Test-HelmInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command helm -ErrorAction SilentlyContinue)
}

function Get-KubernetesSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $kubectlInstalled = Test-KubectlInstalled
    $helmInstalled    = Test-HelmInstalled
    $currentContext   = $null

    if ($kubectlInstalled) {
        try {
            $ctx = kubectl config current-context 2>$null
            if ($LASTEXITCODE -eq 0 -and $ctx) {
                $currentContext = $ctx.Trim()
            }
        }
        catch { }
    }

    return [PSCustomObject]@{
        KubectlInstalled = $kubectlInstalled
        HelmInstalled    = $helmInstalled
        CurrentContext   = $currentContext
    }
}
