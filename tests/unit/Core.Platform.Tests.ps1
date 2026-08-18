#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for modules/Core/Platform.ps1
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'modules' 'Core' 'Platform.ps1')
}

Describe 'Platform' {

    BeforeEach {
        Reset-PlatformCache
    }

    Context 'Get-PlatformInfo' {
        It 'should return a PSCustomObject' {
            $result = Get-PlatformInfo
            $result | Should -BeOfType PSCustomObject
        }

        It 'should detect Windows correctly' {
            $result = Get-PlatformInfo
            $result.IsWindows | Should -Be $true
        }

        It 'should detect x64 architecture' {
            $result = Get-PlatformInfo
            $result.Architecture | Should -Be 'x64'
        }

        It 'should detect PowerShell version' {
            $result = Get-PlatformInfo
            $result.PSVersion | Should -BeGreaterOrEqual ([version]'7.0')
        }

        It 'should detect PowerShell edition as Core' {
            $result = Get-PlatformInfo
            $result.PSEdition | Should -Be 'Core'
        }

        It 'should report a valid execution policy' {
            $result = Get-PlatformInfo
            $result.ExecutionPolicy | Should -Not -BeNullOrEmpty
        }

        It 'should cache the result on second call' {
            $r1 = Get-PlatformInfo
            $r2 = Get-PlatformInfo
            # Same object reference (cached)
            [Object]::ReferenceEquals($r1, $r2) | Should -Be $true
        }

        It 'should return a BuildNumber' {
            $result = Get-PlatformInfo
            $result.BuildNumber | Should -Match '^\d{5}$'
        }
    }

    Context 'Assert-Windows' {
        It 'should not throw on Windows' {
            { Assert-Windows } | Should -Not -Throw
        }
    }

    Context 'Assert-PowerShellVersion' {
        It 'should not throw for version 7.0 when running PS7+' {
            { Assert-PowerShellVersion -Minimum '7.0' } | Should -Not -Throw
        }

        It 'should not throw for a very low minimum version' {
            { Assert-PowerShellVersion -Minimum '1.0' } | Should -Not -Throw
        }

        It 'should throw for an impossibly high minimum version' {
            { Assert-PowerShellVersion -Minimum '99.0' } | Should -Throw
        }
    }

    Context 'Test-IsAdministrator' {
        It 'should return a boolean' {
            $result = Test-IsAdministrator
            $result | Should -BeOfType bool
        }
    }

    Context 'Get-WindowsBuildFriendlyName' {
        It 'should return a known name for build 22621' {
            $result = Get-WindowsBuildFriendlyName -BuildNumber '22621'
            $result | Should -Be 'Windows 11 22H2'
        }

        It 'should return a generic string for unknown builds' {
            $result = Get-WindowsBuildFriendlyName -BuildNumber '99999'
            $result | Should -Match 'Windows.*Build 99999'
        }
    }

    Context 'Reset-PlatformCache' {
        It 'should force a fresh fetch on next call' {
            $r1 = Get-PlatformInfo
            Reset-PlatformCache
            $r2 = Get-PlatformInfo
            # Different object instances after cache reset
            [Object]::ReferenceEquals($r1, $r2) | Should -Be $false
        }
    }
}
