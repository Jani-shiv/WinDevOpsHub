# Contributing to WinDevOpsHub

Thank you for your interest in contributing.

WinDevOpsHub is an open-source project and community contributions are welcome.

---

## Before You Start

- Read the [README](README.md) to understand the project goals.
- Read the [Architecture](docs/architecture.md) to understand the design.
- Run `.\scripts\doctor.ps1` to verify your local environment.

---

## Development Requirements

- Windows 10 / 11
- PowerShell 7.0+
- Git
- Pester 5.x (`Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser`)
- PSScriptAnalyzer (`Install-Module PSScriptAnalyzer -Scope CurrentUser`)

---

## Adding a New Tool

1. Add a tool entry to `config/tools.json`.
2. Include all required fields: `id`, `name`, `category`, `packageManager`, `packageId`, `command`.
3. Add the tool ID to the appropriate profile(s) in `config/profiles/`.
4. Run `Invoke-Pester tests/unit/Core.Config.Tests.ps1` to verify the registry.
5. Run `.\scripts\doctor.ps1` to verify detection works.
6. Document the tool in `docs/installation.md` if it needs special notes.

---

## Code Standards

- Functions must be small and have a single responsibility.
- Every error must carry: what failed, why, what was attempted, suggested action.
- Never use empty catch blocks.
- All mutating operations must honour a `$DryRun` parameter.
- Installations must be idempotent — check before installing.
- PATH changes must be additive — never replace.
- No hardcoded machine-specific paths.
- No credentials, secrets, or API keys anywhere in the repository.

---

## Testing

Run all tests before submitting a PR:

```powershell
# Unit tests
Invoke-Pester tests/unit -Output Detailed

# Integration tests (dry-run safe — no installs)
Invoke-Pester tests/integration -Output Detailed

# PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error
```

---

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     New feature or tool
fix:      Bug fix
docs:     Documentation only
chore:    Maintenance, CI, config
refactor: Code change that is not a feature or fix
test:     Test additions or changes
ci:       CI workflow changes
perf:     Performance improvement
```

---

## Pull Request Process

1. Fork the repository.
2. Create a branch: `git checkout -b feat/your-feature`.
3. Make your changes.
4. Run the full test suite.
5. Update CHANGELOG.md.
6. Open a PR using the provided template.
7. Ensure all CI checks pass.

---

## Code of Conduct

Please read and follow the [Code of Conduct](CODE_OF_CONDUCT.md).
