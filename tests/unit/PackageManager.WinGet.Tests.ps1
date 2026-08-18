#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for modules/PackageManager/WinGet.ps1 and Installer.ps1
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # Load Core first (Installer.ps1 calls Get-ToolDefinition)
    . (Join-Path $repoRoot 'modules' 'Core' 'Logger.ps1')
    . (Join-Path $repoRoot 'modules' 'Core' 'Platform.ps1')
    . (Join-Path $repoRoot 'modules' 'Core' 'Errors.ps1')
    . (Join-Path $repoRoot 'modules' 'Core' 'Config.ps1')

    . (Join-Path $repoRoot 'modules' 'PackageManager' 'WinGet.ps1')
    . (Join-Path $repoRoot 'modules' 'PackageManager' 'Choco.ps1')
    . (Join-Path $repoRoot 'modules' 'PackageManager' 'Installer.ps1')
}

Describe 'WinGet' {

    Context 'Test-WinGetAvailable' {
        It 'should return a boolean' {
            $result = Test-WinGetAvailable
            $result | Should -BeOfType bool
        }

        It 'should return $true on this machine (winget is installed)' {
            # We verified winget exists during environment discovery
            Test-WinGetAvailable | Should -Be $true
        }
    }

    Context 'Get-WinGetVersion' {
        It 'should return a non-empty string when WinGet is available' {
            $result = Get-WinGetVersion
            $result | Should -Not -BeNullOrEmpty
        }

        It 'should return a version-like string' {
            $result = Get-WinGetVersion
            $result | Should -Match '^\d+\.\d+\.\d+'
        }
    }

    Context 'Assert-WinGetAvailable' {
        It 'should not throw when WinGet is available' {
            { Assert-WinGetAvailable } | Should -Not -Throw
        }
    }

    Context 'Test-WinGetPackageInstalled' {
        It 'should return a boolean' {
            $result = Test-WinGetPackageInstalled -PackageId 'Git.Git'
            $result | Should -BeOfType bool
        }

        It 'should detect Git.Git as installed (git is already on this machine)' {
            $result = Test-WinGetPackageInstalled -PackageId 'Git.Git'
            $result | Should -Be $true
        }

        It 'should return false for a clearly non-existent package' {
            $result = Test-WinGetPackageInstalled -PackageId 'NonExistent.Package.XYZ.123'
            $result | Should -Be $false
        }
    }

    Context 'Install-WinGetPackage -DryRun' {
        It 'should return Success=$true in dry-run mode without installing' {
            $result = Install-WinGetPackage -PackageId 'Git.Git' -DryRun $true
            $result.Success   | Should -Be $true
            $result.ExitCode  | Should -Be 0
            $result.Output    | Should -Be '[DryRun]'
        }
    }
}

Describe 'Installer' {

    Context 'Test-ToolInstalled' {
        It 'should return $true for pwsh (which is running this test)' {
            $tool = [PSCustomObject]@{ command = 'pwsh'; versionArg = '--version' }
            Test-ToolInstalled -ToolDefinition $tool | Should -Be $true
        }

        It 'should return $false for a non-existent command' {
            $tool = [PSCustomObject]@{ command = 'this-cmd-does-not-exist-wdoh'; versionArg = '--version' }
            Test-ToolInstalled -ToolDefinition $tool | Should -Be $false
        }
    }

    Context 'Get-ToolVersion' {
        It 'should return a non-empty string for pwsh' {
            $tool = [PSCustomObject]@{ command = 'pwsh'; versionArg = '--version'; id = 'pwsh' }
            $ver = Get-ToolVersion -ToolDefinition $tool
            $ver | Should -Not -BeNullOrEmpty
        }

        It 'should return $null for a non-existent command' {
            $tool = [PSCustomObject]@{ command = 'this-cmd-does-not-exist-wdoh'; versionArg = '--version'; id = 'none' }
            $ver = Get-ToolVersion -ToolDefinition $tool
            $ver | Should -BeNullOrEmpty
        }
    }

    Context 'Install-Tool -DryRun' {
        It 'should report already-installed for git (which is on PATH)' {
            $result = Install-Tool -ToolId 'git' -DryRun $true
            $result.AlreadyInstalled | Should -Be $true
        }

        It 'should return a structured result object' {
            $result = Install-Tool -ToolId 'git' -DryRun $true
            $result.PSObject.Properties.Name | Should -Contain 'ToolId'
            $result.PSObject.Properties.Name | Should -Contain 'AlreadyInstalled'
            $result.PSObject.Properties.Name | Should -Contain 'DryRun'
        }

        It 'should return error for an unknown tool ID' {
            $result = Install-Tool -ToolId 'totally-fake-tool-xyz' -DryRun $true
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Install-ToolSet -DryRun' {
        It 'should return one result per tool ID provided' {
            $results = Install-ToolSet -ToolIds @('git','pwsh') -DryRun $true
            $results.Count | Should -Be 2
        }
    }
}
