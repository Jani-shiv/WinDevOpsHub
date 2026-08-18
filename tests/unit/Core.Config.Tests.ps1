#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for modules/Core/Config.ps1
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ConfigScript = Join-Path $repoRoot 'modules' 'Core' 'Config.ps1'
    . $script:ConfigScript
}

Describe 'Config' {

    BeforeEach {
        Reset-ConfigCache
    }

    Context 'Get-ToolRegistry' {
        It 'should load the tool registry without error' {
            { Get-ToolRegistry } | Should -Not -Throw
        }

        It 'should return an array of objects' {
            $registry = Get-ToolRegistry
            $registry | Should -Not -BeNullOrEmpty
            $registry.Count | Should -BeGreaterThan 5
        }

        It 'every tool should have an id, name, and command' {
            $registry = Get-ToolRegistry
            foreach ($tool in $registry) {
                $tool.id      | Should -Not -BeNullOrEmpty -Because "tool '$($tool.name)' must have an id"
                $tool.name    | Should -Not -BeNullOrEmpty -Because "tool '$($tool.id)' must have a name"
                $tool.command | Should -Not -BeNullOrEmpty -Because "tool '$($tool.id)' must have a command"
            }
        }

        It 'should return consistent data on second call (cache working)' {
            $r1 = Get-ToolRegistry
            $r2 = Get-ToolRegistry
            # Cache is working if count and IDs are identical
            $r1.Count | Should -Be $r2.Count
            ($r1 | Select-Object -ExpandProperty id) -join ',' | Should -Be (($r2 | Select-Object -ExpandProperty id) -join ',')
        }
    }

    Context 'Get-ToolDefinition' {
        It 'should return the git tool definition' {
            $tool = Get-ToolDefinition -ToolId 'git'
            $tool.id      | Should -Be 'git'
            $tool.name    | Should -Be 'Git'
            $tool.command | Should -Be 'git'
        }

        It 'should return the terraform tool definition' {
            $tool = Get-ToolDefinition -ToolId 'terraform'
            $tool.id      | Should -Be 'terraform'
            $tool.command | Should -Be 'terraform'
        }

        It 'should throw for an unknown tool ID' {
            { Get-ToolDefinition -ToolId 'non-existent-tool-xyz' } | Should -Throw
        }
    }

    Context 'Get-DefaultConfig' {
        It 'should load the default config without error' {
            { Get-DefaultConfig } | Should -Not -Throw
        }

        It 'should have a settings object' {
            $cfg = Get-DefaultConfig
            $cfg.settings | Should -Not -BeNullOrEmpty
        }

        It 'should have a logLevel setting' {
            $cfg = Get-DefaultConfig
            $cfg.settings.logLevel | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-Profile' {
        It 'should load the Minimal profile without error' {
            { Get-Profile -ProfileName 'Minimal' } | Should -Not -Throw
        }

        It 'should load the DevOps profile and resolve Minimal tools' {
            $profile = Get-Profile -ProfileName 'DevOps'
            # DevOps extends Minimal — should contain git (from Minimal)
            $profile.Tools | Should -Contain 'git'
            # And DevOps-specific tools
            $profile.Tools | Should -Contain 'docker'
            $profile.Tools | Should -Contain 'terraform'
        }

        It 'should load AWS profile and contain both DevOps and AWS tools' {
            $profile = Get-Profile -ProfileName 'AWS'
            $profile.Tools | Should -Contain 'git'        # from Minimal
            $profile.Tools | Should -Contain 'docker'     # from DevOps
            $profile.Tools | Should -Contain 'aws-cli'    # AWS-specific
        }

        It 'should deduplicate tools in cascaded profiles' {
            $profile = Get-Profile -ProfileName 'DevOps'
            $unique  = $profile.Tools | Select-Object -Unique
            $profile.Tools.Count | Should -Be $unique.Count
        }

        It 'should throw for an invalid profile name' {
            # ValidateSet enforcement at param level — the function will throw
            { Get-Profile -ProfileName 'NonExistent' } | Should -Throw
        }
    }

    Context 'Get-AllProfileNames' {
        It 'should return all six profile names' {
            $names = Get-AllProfileNames
            $names | Should -Contain 'Minimal'
            $names | Should -Contain 'DevOps'
            $names | Should -Contain 'AWS'
            $names | Should -Contain 'Azure'
            $names | Should -Contain 'Kubernetes'
            $names | Should -Contain 'Full'
            $names.Count | Should -Be 6
        }
    }

    Context 'Reset-ConfigCache' {
        It 'should force a fresh load on next call' {
            $r1 = Get-ToolRegistry
            Reset-ConfigCache
            $r2 = Get-ToolRegistry
            [Object]::ReferenceEquals($r1, $r2) | Should -Be $false
        }
    }
}
