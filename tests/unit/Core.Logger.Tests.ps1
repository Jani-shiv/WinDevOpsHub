#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for modules/Core/Logger.ps1
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'modules' 'Core' 'Logger.ps1')
}

Describe 'Logger' {

    Context 'Initialize-Logger' {
        It 'should initialise without error when no log file is specified' {
            { Initialize-Logger } | Should -Not -Throw
        }

        It 'should create the log directory if it does not exist' {
            $tmpLog = Join-Path $env:TEMP "wdoh-test-$(Get-Random)\test.log"
            Initialize-Logger -LogFile $tmpLog -Level DEBUG
            $tmpLog | Should -FileContentMatch ''  -Because 'file should be created'
            Remove-Item (Split-Path $tmpLog -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'should accept all valid level values' {
            foreach ($level in @('DEBUG','INFO','WARN','ERROR')) {
                { Initialize-Logger -Level $level } | Should -Not -Throw
            }
        }
    }

    Context 'Write-LogEntry (via public wrappers)' {
        BeforeEach {
            # Reset to console-only mode
            Initialize-Logger
        }

        It 'Write-LogInfo should not throw' {
            { Write-LogInfo 'Test info message' } | Should -Not -Throw
        }

        It 'Write-LogWarn should not throw' {
            { Write-LogWarn 'Test warning' } | Should -Not -Throw
        }

        It 'Write-LogError should not throw' {
            { Write-LogError 'Test error' } | Should -Not -Throw
        }

        It 'Write-LogSuccess should not throw' {
            { Write-LogSuccess 'Test success' } | Should -Not -Throw
        }

        It 'Write-LogDebug should not throw' {
            { Write-LogDebug 'Test debug' } | Should -Not -Throw
        }

        It 'Write-LogSection should not throw' {
            { Write-LogSection 'Test Section' } | Should -Not -Throw
        }
    }

    Context 'File logging' {
        It 'should write log entries to the specified file' {
            $tmpLog = Join-Path $env:TEMP "wdoh-logger-test-$(Get-Random).log"
            try {
                Initialize-Logger -LogFile $tmpLog -Level DEBUG
                Write-LogInfo 'File logging test'
                Write-LogSuccess 'File success'
                Test-Path $tmpLog | Should -Be $true
                $content = Get-Content $tmpLog -Raw
                $content | Should -Match '\[INFO'
                $content | Should -Match 'File logging test'
            }
            finally {
                Remove-Item $tmpLog -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Write-Log pipeline' {
        It 'should accept pipeline input' {
            { 'pipeline message' | Write-Log } | Should -Not -Throw
        }
    }
}
