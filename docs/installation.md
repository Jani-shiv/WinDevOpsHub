# Installation Guide

## Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Windows | Windows 10 21H2 | Windows 11 22H2+ |
| PowerShell | 7.0 | 7.4+ |
| WinGet | 1.20+ | Latest |
| Git | Any | 2.40+ |

### Check your PowerShell version

```powershell
pwsh --version
```

If you have Windows PowerShell 5.1 (the built-in version), install PowerShell 7 first:

```powershell
# One-liner — installs via WinGet
winget install Microsoft.PowerShell
```

---

## Quick Start

```powershell
# 1. Clone the repository
git clone https://github.com/Jani-shiv/WinDevOpsHub.git
cd WinDevOpsHub

# 2. Review what would be installed (no changes made)
.\scripts\bootstrap.ps1 -Profile Minimal -DryRun

# 3. Run the bootstrap
.\scripts\bootstrap.ps1 -Profile Minimal

# 4. Verify your environment
.\scripts\doctor.ps1
```

---

## Profiles

| Profile | Description | Includes |
|---------|-------------|----------|
| `Minimal` | Essential developer tools | Git, GitHub CLI, OpenSSH, curl, jq, 7-Zip, Clink, Windows Terminal |
| `DevOps` | Full DevOps workstation | Minimal + Docker, kubectl, Helm, Terraform, k9s, yq |
| `AWS` | AWS cloud engineering | DevOps + AWS CLI |
| `Azure` | Azure cloud engineering | DevOps + Azure CLI |
| `Kubernetes` | Kubernetes-focused | DevOps + full k8s toolchain |
| `Full` | Everything | DevOps + all cloud CLIs |

```powershell
# Choose a profile
.\scripts\bootstrap.ps1 -Profile DevOps
.\scripts\bootstrap.ps1 -Profile AWS
.\scripts\bootstrap.ps1 -Profile Full
```

---

## Install Specific Tools

```powershell
# See all available tools
.\scripts\install.ps1 -ListTools

# Install one or more specific tools
.\scripts\install.ps1 -Tool terraform
.\scripts\install.ps1 -Tool terraform,kubectl,helm
```

---

## Dry Run Mode

Preview what would be installed without making any system changes:

```powershell
.\scripts\bootstrap.ps1 -Profile DevOps -DryRun
.\scripts\install.ps1 -Tool terraform -DryRun
```

---

## Administrator Note

WinDevOpsHub operates at **user scope** by default.
Most tools install without requiring administrator privileges via WinGet.

Exceptions that require admin:
- OpenSSH (Windows Optional Feature)
- Machine-scope PATH changes

If admin is needed, the script will explain why and skip or prompt rather than failing silently.

To run with machine-scope installs:

```powershell
# Run PowerShell as Administrator first, then:
.\scripts\bootstrap.ps1 -Profile Minimal -Scope machine
```

---

## Log File

```powershell
.\scripts\bootstrap.ps1 -Profile DevOps -LogFile C:\Logs\wdoh-install.log
```

---

## Uninstall

```powershell
# Remove specific tools
.\scripts\uninstall.ps1 -Tool terraform
.\scripts\uninstall.ps1 -Tool terraform,kubectl -DryRun  # preview first
```
