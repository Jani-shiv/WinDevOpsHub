# Development Guide

## Setup

```powershell
git clone https://github.com/Jani-shiv/WinDevOpsHub.git
cd WinDevOpsHub

# Install test dependencies
Install-Module Pester          -MinimumVersion 5.5.0 -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
```

---

## Running Tests

```powershell
# All unit tests
Invoke-Pester tests/unit -Output Detailed

# Specific test file
Invoke-Pester tests/unit/Core.Platform.Tests.ps1 -Output Detailed

# Integration tests (no actual installs — dry-run only)
Invoke-Pester tests/integration -Output Detailed

# All tests with JUnit output for CI
$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = 'TestResults.xml'
Invoke-Pester -Configuration $config
```

---

## Linting

```powershell
# Run PSScriptAnalyzer on all PowerShell files
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error

# Auto-fix some issues
Invoke-ScriptAnalyzer -Path . -Recurse -Fix
```

---

## Adding a New Tool

1. Add an entry to `config/tools.json`:

```json
{
  "id": "my-tool",
  "name": "My Tool",
  "category": "utilities",
  "packageManager": "winget",
  "packageId": "Vendor.MyTool",
  "command": "mytool",
  "versionArg": "--version",
  "required": false,
  "homepage": "https://mytool.example.com"
}
```

2. Add the tool ID to the appropriate profile(s) in `config/profiles/`.

3. Run the config tests:

```powershell
Invoke-Pester tests/unit/Core.Config.Tests.ps1 -Output Detailed
```

4. Test detection:

```powershell
.\scripts\doctor.ps1 -Category Development
```

5. Test dry-run install:

```powershell
.\scripts\install.ps1 -Tool my-tool -DryRun
```

---

## Module Development

Each module follows this pattern:

```powershell
#Requires -Version 7.0

function My-PublicFunction {
    <#
    .SYNOPSIS   One line description.
    .PARAMETER  X  What X is.
    .OUTPUTS    [string] What it returns.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $X
    )
    # implementation
}

Export-ModuleMember -Function @('My-PublicFunction')
```

Rules:
- `#Requires -Version 7.0` on every module file
- Comment-based help on every exported function
- `[OutputType]` attribute on all functions
- `Export-ModuleMember` with an explicit list (not wildcard)
- No global variables outside `$script:` scope

---

## Git Workflow

```
main         ← stable releases
develop      ← integration branch
feat/xyz     ← feature branches
fix/xyz      ← bug fix branches
```

```powershell
# Create a feature branch
git checkout -b feat/add-my-tool

# Commit with conventional format
git commit -m "feat(tools): add my-tool to registry and devops profile"

# Push and open PR targeting main
git push origin feat/add-my-tool
```

---

## Project Conventions

- Functions are small and have a single responsibility
- No function longer than 60 lines (aim for 20–40)
- `$ErrorActionPreference = 'Stop'` in all entry scripts
- Every catch block surfaces the error — no silent swallowing
- All mutating operations accept `$DryRun` parameter
- All installs check existence first (idempotency gate)
- PATH changes are always additive — never replace
- No hardcoded machine-specific paths
- No credentials anywhere in the codebase
