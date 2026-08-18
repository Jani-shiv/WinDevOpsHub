#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Integration tests for bootstrap.ps1 and doctor.ps1

.DESCRIPTION
    These tests execute the actual entry scripts in safe modes (DryRun, -Json)
    and validate the outputs. They do NOT install any software.
#>

BeforeAll {
    $repoRoot     = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $scriptDir    = Join-Path $repoRoot 'scripts'
    $bootstrap    = Join-Path $scriptDir 'bootstrap.ps1'
    $doctorScript = Join-Path $scriptDir 'doctor.ps1'
}

Describe 'bootstrap.ps1' {

    Context 'Dry-run mode' {
        BeforeAll {
            $script:bootstrapOutput = pwsh -NoProfile -File $bootstrap -Profile Minimal -DryRun 2>&1 | Out-String
            $script:bootstrapExitCode = $LASTEXITCODE
        }

        It 'should exit 0 in dry-run mode with Minimal profile' {
            $script:bootstrapExitCode | Should -Be 0
        }

        It 'should mention DRY RUN in output' {
            $script:bootstrapOutput | Should -Match 'DRY RUN'
        }

        It 'should report git as already installed' {
            $script:bootstrapOutput | Should -Match 'Already installed.*git'
            $script:bootstrapOutput | Should -Not -Match 'Newly installed.*\bgit\b'
        }
    }
}

Describe 'doctor.ps1' {

    Context 'JSON output mode' {
        BeforeAll {
            $script:doctorJsonRaw = pwsh -NoProfile -File $doctorScript -Json 2>&1 | Out-String
            $script:doctorExitCode = $LASTEXITCODE
            try {
                $script:doctorData = $script:doctorJsonRaw | ConvertFrom-Json
            }
            catch {
                $script:doctorData = $null
            }
        }

        It 'should exit 0 or 1 with -Json flag' {
            $script:doctorExitCode | Should -BeIn @(0, 1)
        }

        It 'should produce valid JSON with -Json flag' {
            $script:doctorData | Should -Not -BeNullOrEmpty
        }

        It 'JSON output should contain Status fields' {
            $script:doctorData | ForEach-Object { $_.Status | Should -Not -BeNullOrEmpty }
        }

        It 'JSON output should contain OS check' {
            $os = $script:doctorData | Where-Object { $_.Name -eq 'Operating System' }
            $os | Should -Not -BeNullOrEmpty
            $os.Status | Should -Be 'Pass'
        }

        It 'JSON output should detect PowerShell version' {
            $ps = $script:doctorData | Where-Object { $_.Name -eq 'PowerShell' }
            $ps | Should -Not -BeNullOrEmpty
            $ps.Status | Should -Be 'Pass'
        }
    }

    Context 'Category filtering' {
        It 'should accept -Category System' {
            $output = pwsh -NoProfile -File $doctorScript -Category System -Json 2>&1 | Out-String
            $data   = $output | ConvertFrom-Json
            $data | ForEach-Object { $_.Category | Should -Be 'System' }
        }

        It 'should accept -Category Network' {
            $output = pwsh -NoProfile -File $doctorScript -Category Network -Json 2>&1 | Out-String
            $data   = $output | ConvertFrom-Json
            $data | ForEach-Object { $_.Category | Should -Be 'Network' }
        }
    }

    Context 'Exit code semantics' {
        It 'should exit 0 or 1 or 2 (not other codes)' {
            pwsh -NoProfile -File $doctorScript -Category System 2>&1 | Out-Null
            $LASTEXITCODE | Should -BeIn @(0, 1, 2)
        }
    }
}
