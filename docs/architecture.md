# Architecture

## Overview

WinDevOpsHub is structured as a PowerShell module ecosystem with a configuration-driven tool registry.
The design follows these principles: small functions, single responsibility, configuration over code,
explicit error handling, and zero silent failures.

---

## Directory Layout

```
WinDevOpsHub/
│
├── scripts/              ← Entry points (what users run)
│   ├── bootstrap.ps1     ← Main installer
│   ├── install.ps1       ← Install specific tools
│   ├── uninstall.ps1     ← Remove managed tools
│   ├── doctor.ps1        ← Environment health checker
│   └── helpers/          ← Shared script utilities
│
├── modules/              ← PowerShell module library
│   ├── Core/             ← Logger, Platform, Errors, Config
│   ├── PackageManager/   ← WinGet, Choco, Installer abstraction
│   ├── System/           ← PATH management, system info
│   ├── Git/              ← Git detection and diagnostics
│   ├── Docker/           ← Docker detection and status
│   ├── Kubernetes/       ← kubectl, Helm, k9s
│   ├── Terraform/        ← Terraform detection
│   ├── Cloud/            ← AWS, Azure, GCP CLI detection
│   ├── Terminal/         ← Windows Terminal, Clink
│   └── Utilities/        ← Network checks, port scanner
│
├── config/               ← Machine-readable configuration
│   ├── tools.json        ← Tool registry (source of truth)
│   ├── default.json      ← Default settings
│   └── profiles/         ← Installation profiles
│       ├── minimal.json
│       ├── devops.json
│       ├── aws.json
│       ├── azure.json
│       ├── kubernetes.json
│       └── full.json
│
├── tests/
│   ├── unit/             ← Pester unit tests per module
│   ├── integration/      ← End-to-end tests (dry-run safe)
│   └── fixtures/         ← Mock data for tests
│
└── .github/
    ├── workflows/        ← GitHub Actions CI/CD
    └── ISSUE_TEMPLATE/
```

---

## Core Module Architecture

### `modules/Core/`

The foundation. Loaded first by all entry scripts.

| File | Responsibility |
|------|---------------|
| `Logger.ps1` | Structured logging: 5 levels, console + optional file sink |
| `Platform.ps1` | OS/arch/privilege detection with caching |
| `Errors.ps1` | Structured error objects with Operation/Reason/Context/Suggested |
| `Config.ps1` | JSON config loader: tool registry, default settings, profile resolution |

### `modules/PackageManager/`

The installation layer. Abstracts package managers behind a single `Install-Tool` function.

| File | Responsibility |
|------|---------------|
| `WinGet.ps1` | WinGet detection, package-installed check, install, upgrade |
| `Choco.ps1` | Chocolatey detection and install (fallback) |
| `Installer.ps1` | Unified `Install-Tool`: idempotency gate → route → verify |

---

## Tool Registry Pattern

Tools are defined as JSON objects in `config/tools.json`.
No tool-specific installation logic lives in PowerShell code.
Adding a new tool = adding a JSON entry.

```json
{
  "id": "terraform",
  "name": "Terraform",
  "category": "infrastructure",
  "packageManager": "winget",
  "packageId": "Hashicorp.Terraform",
  "command": "terraform",
  "versionArg": "version",
  "required": false
}
```

The `Installer.Install-Tool` function reads this entry and handles everything else.

---

## Profile Inheritance

Profiles use additive composition. A profile can `extend` another:

```
Full
 └── extends DevOps
      └── extends Minimal
```

Tools are merged and deduplicated. A tool appearing in both Minimal and DevOps is installed once.

---

## Idempotency Design

Every `Install-Tool` call checks `Get-Command <executable>` before calling the package manager.

```
Install-Tool 'terraform'
    └── Test-ToolInstalled? → YES → log "already installed" → return
    └── Test-ToolInstalled? → NO  → Install-WinGetPackage → verify → return
```

Running `bootstrap.ps1` twice produces identical results with no unnecessary operations on the second run.

---

## Dry-Run Design

A `$DryRun` boolean threads through every mutating operation.
When true, all WinGet/Choco calls log `[DRYRUN] Would install X` and return synthetic success.
The filesystem, registry, and PATH are never touched in dry-run mode.

---

## Error Handling

All errors use the `New-WDOHError` structured model:

```powershell
New-WDOHError `
    -Operation 'Install Terraform' `
    -Reason    'WinGet returned exit code 1' `
    -Context   'winget install --id Hashicorp.Terraform' `
    -Suggested 'Check your internet connection or run with admin privileges.'
```

Empty catch blocks are prohibited. Every caught exception is surfaced.

---

## PATH Safety Rules

1. Read current user PATH
2. Check if directory already present (case-insensitive, trailing-slash normalised)
3. If present → skip (never add duplicates)
4. If absent → append to User PATH (never replace)
5. Update current process PATH immediately so tools are accessible without restart
