# Troubleshooting Guide

## doctor.ps1 first

Before troubleshooting manually, always run:

```powershell
.\scripts\doctor.ps1
```

The doctor output will identify exactly what is wrong and suggest a fix.

---

## Common Issues

### WinGet not found

**Symptom:** `winget: command not found` or `winget is not available`

**Cause:** WinGet (App Installer) is not installed or too old.

**Fix:**
1. Open the Microsoft Store
2. Search for "App Installer"
3. Install or update it

Or via PowerShell (if your Windows version supports it):
```powershell
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
```

---

### Scripts won't run (execution policy)

**Symptom:** `cannot be loaded because running scripts is disabled on this system`

**Cause:** Execution policy is set to `Restricted` or `AllSigned`.

**Fix:**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Tool installed but not found after bootstrap

**Symptom:** WinGet reports success, but `git --version` fails.

**Cause:** The new tool's directory is not yet in the current shell's PATH.

**Fix:** Open a new PowerShell window. WinGet user-scope installs update the user PATH,
which is picked up by new shell sessions.

---

### Bootstrap fails on a tool requiring admin

**Symptom:** `Requires administrator privileges` warning, tool skipped.

**Cause:** Some tools (OpenSSH, machine-scope installs) need admin.

**Fix:** Either:
- Accept the skip and install manually later as admin
- Re-run as Administrator:
  ```powershell
  Start-Process pwsh -Verb RunAs -ArgumentList "-File .\scripts\bootstrap.ps1 -Profile Minimal -Scope machine"
  ```

---

### Docker not starting

**Symptom:** `docker info` fails with `docker daemon is not running`

**Cause:** Docker Desktop is installed but not started.

**Fix:** Start Docker Desktop from the Start Menu or system tray.
Wait for the whale icon to appear in the system tray before retrying.

---

### kubectl shows wrong version

**Symptom:** kubectl exists but is the Docker Desktop version, not the standalone.

**Cause:** Docker Desktop ships its own kubectl at a version that may differ from the standalone.

**Fix:** WinGet installs the standalone kubectl. After install, open a new shell and verify:
```powershell
(Get-Command kubectl).Source
kubectl version --client
```

---

### PATH duplicates detected

**Symptom:** doctor.ps1 warns about duplicate PATH entries.

**Fix:**
```powershell
# View current PATH entries
[System.Environment]::GetEnvironmentVariable('PATH','User') -split ';'

# Clean duplicates manually in:
# Settings → System → About → Advanced system settings → Environment Variables
```

---

### WinGet install fails with "Another version already installed"

**Symptom:** WinGet exits with an error about an existing installation.

**Fix:**
```powershell
# Upgrade instead of install
winget upgrade --id <PackageId> --accept-package-agreements --accept-source-agreements
```

Or force reinstall:
```powershell
winget uninstall --id <PackageId>
.\scripts\install.ps1 -Tool <tool-id>
```

---

## Getting Help

1. Run `.\scripts\doctor.ps1 -Json` and include the output in your bug report.
2. Open an issue: [GitHub Issues](https://github.com/Jani-shiv/WinDevOpsHub/issues)
3. Use the Bug Report template.
