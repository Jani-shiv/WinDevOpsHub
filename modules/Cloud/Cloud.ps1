#Requires -Version 7.0

<#
.SYNOPSIS
    Cloud CLI module for WinDevOpsHub — AWS CLI, Azure CLI, and Google Cloud SDK detection.

.DESCRIPTION
    Provides functions to detect presence and versions of major Cloud provider CLIs.
#>

function Test-AwsCliInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command aws -ErrorAction SilentlyContinue)
}

function Test-AzureCliInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command az -ErrorAction SilentlyContinue)
}

function Test-GCloudInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command gcloud -ErrorAction SilentlyContinue)
}

function Get-CloudCliSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $awsVer = $null
    if (Test-AwsCliInstalled) {
        try {
            $out = aws --version 2>&1
            if ($out -match 'aws-cli/([0-9\.]+)') { $awsVer = $Matches[1] }
            else { $awsVer = $out.Trim() }
        } catch { }
    }

    $azVer = $null
    if (Test-AzureCliInstalled) {
        try {
            $out = az version 2>$null | ConvertFrom-Json
            $azVer = $out.'azure-cli'
        } catch { }
    }

    $gcloudVer = $null
    if (Test-GCloudInstalled) {
        try {
            $out = gcloud version 2>$null | Select-Object -First 1
            if ($out -match 'Google Cloud SDK\s+([0-9\.]+)') { $gcloudVer = $Matches[1] }
        } catch { }
    }

    return [PSCustomObject]@{
        AwsCliInstalled   = Test-AwsCliInstalled
        AwsCliVersion     = $awsVer
        AzureCliInstalled = Test-AzureCliInstalled
        AzureCliVersion   = $azVer
        GCloudInstalled   = Test-GCloudInstalled
        GCloudVersion     = $gcloudVer
    }
}
