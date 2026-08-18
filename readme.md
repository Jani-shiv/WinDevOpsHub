# WinDevOpsHub

### Make Windows DevOps-Ready.

[![CI](https://github.com/Jani-shiv/WinDevOpsHub/actions/workflows/ci.yml/badge.svg)](https://github.com/Jani-shiv/WinDevOpsHub/actions/workflows/ci.yml)
![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

WinDevOpsHub is an open-source PowerShell toolkit that turns a stock Windows machine into a properly configured **DevOps engineering workstation** — automatically, safely, and repeatably.

> **Bring the productivity and tooling DevOps engineers love on Linux into Windows — without manually configuring dozens of tools one by one.**

---

## Why

Setting up a Windows DevOps workstation is repetitive, error-prone, and undocumented.
Engineers waste hours installing tools, fixing PATH issues, and recreating configurations on every new machine.

WinDevOpsHub solves this:

```powershell
.\scripts\bootstrap.ps1 -Profile DevOps
```

That's it.

---

## What It Does

| Feature | Details |
|---------|---------|
| **Tool installation** | 19+ tools via WinGet (signed packages) |
| **Profiles** | Minimal, DevOps, AWS, Azure, Kubernetes, Full |
| **Idempotency** | Run it twice — already-installed tools are skipped |
| **Dry-run** | Preview every change before it happens |
| **Doctor** | Health check with actionable diagnostics |
| **Safe PATH** | Additive only — never replaces, never duplicates |
| **No admin required** | User-scope installs by default |
| **Zero secrets** | No credentials stored anywhere |

---

## Quick Start

### Requirements

- Windows 10/11
- PowerShell 7.0+ (`winget install Microsoft.PowerShell`)
- WinGet (built into Windows 11, available via Microsoft Store on Win10)

### Install

```powershell
# Clone
git clone https://github.com/Jani-shiv/WinDevOpsHub.git
cd WinDevOpsHub

# Preview — no changes made
.\scripts\bootstrap.ps1 -Profile Minimal -DryRun

# Run
.\scripts\bootstrap.ps1 -Profile Minimal

# Verify
.\scripts\doctor.ps1
```

---

## Profiles

| Profile | What you get |
|---------|-------------|
| `Minimal` | Git, GitHub CLI, OpenSSH, curl, jq, 7-Zip, Clink, Windows Terminal |
| `DevOps` | Minimal + Docker, kubectl, Helm, Terraform, k9s, yq, VS Code |
| `AWS` | DevOps + AWS CLI |
| `Azure` | DevOps + Azure CLI |
| `Kubernetes` | DevOps + full Kubernetes toolchain |
| `Full` | Everything across all cloud platforms |

```powershell
.\scripts\bootstrap.ps1 -Profile DevOps
.\scripts\bootstrap.ps1 -Profile AWS -DryRun   # preview first
```

---

## Doctor

Run a full environment health check at any time:

```powershell
.\scripts\doctor.ps1
```

Example output:

```
  WinDevOpsHub — Environment Doctor
  ──────────────────────────────────────────────────────────

  System
    ✓ Operating System (Microsoft Windows 11 Enterprise, Build 22621)
    ✓ Architecture (x64)
    ✓ PowerShell (v7.4.18, Core)
    ⚠ Admin Privileges — Running as standard user
    ✓ WinGet (v1.29.280)
    ✓ PATH (No duplicates detected)
    ✓ Execution Policy (LocalMachine: RemoteSigned)

  Development
    ✓ Git (git version 2.42.0.windows.2)
    ✓ GitHub CLI (gh) — (not installed)
    ✗ GitHub CLI (gh) — gh not found in PATH
        → winops install github-cli

  Containers
    ✓ Docker (Docker version 29.7.2)
    ✓ Docker Engine (Daemon is running)

  Infrastructure
    ✗ Terraform — terraform not found in PATH
        → winops install terraform

  ──────────────────────────────────────────────────────────
  Summary: 9 passed  1 warnings  2 failed
```

Failures always include a suggested remediation. No cryptic `ERROR` messages.

---

## Install Specific Tools

```powershell
# See all 19 available tools
.\scripts\install.ps1 -ListTools

# Install specific tools
.\scripts\install.ps1 -Tool terraform
.\scripts\install.ps1 -Tool terraform,kubectl,helm
.\scripts\install.ps1 -Tool jq -DryRun   # preview
```

---

## Tool Registry

Every tool is defined as a JSON object. Adding a new tool is a config change, not a code change:

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

See the full registry: [`config/tools.json`](config/tools.json)

---

## Architecture

```
scripts/          ← Entry points (bootstrap, doctor, install, uninstall)
modules/
  Core/           ← Logger, Platform detection, Error model, Config loader
  PackageManager/ ← WinGet (primary), Chocolatey (fallback), unified Installer
  System/         ← Safe PATH management, system info
  Git/            ← Git diagnostics
  Docker/         ← Docker detection and status
  Kubernetes/     ← kubectl, Helm, k9s
  Cloud/          ← AWS, Azure, GCP CLI detection
config/
  tools.json      ← Tool registry (source of truth)
  profiles/       ← Installation profiles with inheritance
tests/
  unit/           ← Pester tests per module
  integration/    ← End-to-end dry-run tests
.github/
  workflows/      ← CI: syntax, lint, config validation, Pester, secret scan
```

Full details: [docs/architecture.md](docs/architecture.md)

---

## Security

WinDevOpsHub treats installation scripts as privileged software.

**We never:**
- Download from untrusted sources
- Disable Windows Defender, Firewall, or UAC
- Store credentials, tokens, or API keys
- Modify the system silently

**We always:**
- Use WinGet (signed packages from Microsoft's catalogue)
- Require explicit confirmation before installing
- Support dry-run to preview all changes
- Log every system modification

Full policy: [SECURITY.md](SECURITY.md)

---

## Testing

```powershell
# Install test dependencies
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

# Run all tests
Invoke-Pester tests/ -Output Detailed

# Lint
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error
```

CI runs on every push: syntax check, PSScriptAnalyzer, config validation,
Pester unit tests, Pester integration tests (dry-run), secret scan.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/installation.md) | Detailed install guide, profiles, admin notes |
| [Architecture](docs/architecture.md) | Design, module layout, patterns |
| [Development](docs/development.md) | Contributing, adding tools, running tests |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and fixes |
| [Roadmap](docs/roadmap.md) | What's coming in Phase 2–4 |

---

## Project Status

**Phase 1 — Foundation** ✅

The full Phase 1 scope is implemented and tested:
core framework, tool registry (19 tools), 6 profiles with inheritance,
bootstrap/doctor/install/uninstall scripts, system/PATH module,
Pester test suite, GitHub Actions CI (7 jobs), and full documentation.

See [CHANGELOG.md](CHANGELOG.md) for details.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code standards,
how to add tools, and the PR process.

---

## License

[MIT](LICENSE) — © 2026 WinDevOpsHub Contributors
