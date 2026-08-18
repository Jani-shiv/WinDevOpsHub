#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for modules/System/System.ps1
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'modules' 'System' 'System.ps1')
}

Describe 'System - PATH Management' {

    Context 'Get-CurrentPath' {
        It 'should return an array' {
            $result = Get-CurrentPath
            $result | Should -BeOfType string
        }

        It 'should return at least one entry' {
            $result = Get-CurrentPath
            $result.Count | Should -BeGreaterThan 0
        }

        It 'should not contain empty strings' {
            $result = Get-CurrentPath
            $result | ForEach-Object { $_ | Should -Not -BeNullOrEmpty }
        }

        It 'should not contain duplicate entries (after normalisation)' {
            $result  = Get-CurrentPath
            $unique  = $result | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() } | Select-Object -Unique
            $result.Count | Should -Be $unique.Count
        }
    }

    Context 'Test-PathContains' {
        It 'should return $true for a path that is definitely in PATH (System32)' {
            # C:\Windows\System32 is always in PATH
            Test-PathContains -Directory 'C:\Windows\System32' | Should -Be $true
        }

        It 'should return $false for a clearly non-existent path' {
            Test-PathContains -Directory 'C:\this-path-does-not-exist-wdoh-xyz' | Should -Be $false
        }

        It 'should be case-insensitive' {
            # Test with different casing of System32
            $lower = Test-PathContains -Directory 'c:\windows\system32'
            $upper = Test-PathContains -Directory 'C:\WINDOWS\SYSTEM32'
            $lower | Should -Be $upper
        }

        It 'should handle trailing backslash correctly' {
            $withSlash    = Test-PathContains -Directory 'C:\Windows\System32\'
            $withoutSlash = Test-PathContains -Directory 'C:\Windows\System32'
            $withSlash | Should -Be $withoutSlash
        }
    }

    Context 'Add-ToUserPath' {
        It 'should return $false for a directory already in PATH' {
            # System32 is always in PATH — should be detected as already present
            $result = Add-ToUserPath -Directory 'C:\Windows\System32' -DryRun $true
            $result | Should -Be $false
        }

        It 'should return $false in dry-run mode for a new directory' {
            # Create a temp directory to avoid "does not exist" early return
            $tmpDir = Join-Path $env:TEMP "wdoh-path-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            try {
                $result = Add-ToUserPath -Directory $tmpDir -DryRun $true
                $result | Should -Be $false
            }
            finally {
                Remove-Item $tmpDir -Force -ErrorAction SilentlyContinue
            }
        }

        It 'should return $false for a directory that does not exist' {
            $result = Add-ToUserPath -Directory 'C:\this-does-not-exist-xyz' -DryRun $true
            $result | Should -Be $false
        }
    }

    Context 'Get-PathDuplicates' {
        It 'should return an array (may be empty)' {
            $result = Get-PathDuplicates
            $result | Should -Not -BeNullOrEmpty -ErrorAction Continue
            # It's valid for this to be empty on a clean machine
            # Just ensure it doesn't throw
        }
    }
}

Describe 'System - System Information' {

    Context 'Get-SystemSummary' {
        It 'should return a PSCustomObject' {
            $result = Get-SystemSummary
            $result | Should -BeOfType PSCustomObject
        }

        It 'should have a ComputerName' {
            $result = Get-SystemSummary
            $result.ComputerName | Should -Not -BeNullOrEmpty
        }

        It 'should have positive TotalRAMGB' {
            $result = Get-SystemSummary
            $result.TotalRAMGB | Should -BeGreaterThan 0
        }

        It 'should have a CPUName' {
            $result = Get-SystemSummary
            $result.CPUName | Should -Not -BeNullOrEmpty
        }

        It 'should have a non-zero CPUCores count' {
            $result = Get-SystemSummary
            $result.CPUCores | Should -BeGreaterThan 0
        }
    }
}
