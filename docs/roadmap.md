# Roadmap

WinDevOpsHub is built in four phases. This document describes the planned scope of each.

---

## Phase 1 — Foundation ✅ (Current)

**Goal:** A working, tested, maintainable project skeleton.

### Completed

- [x] Repository architecture
- [x] Core PowerShell framework (Logger, Platform, Errors, Config)
- [x] Tool registry (`config/tools.json`) — 19 tools
- [x] PackageManager layer (WinGet primary, Chocolatey fallback)
- [x] Six installation profiles with inheritance
- [x] `bootstrap.ps1` — idempotent bootstrapper
- [x] `doctor.ps1` — environment health checker (8 categories, JSON output)
- [x] `install.ps1` / `uninstall.ps1`
- [x] System module with safe PATH management
- [x] Pester unit + integration tests
- [x] GitHub Actions CI (7 jobs)
- [x] Full documentation

---

## Phase 2 — DevOps Environment

**Goal:** A complete, production-quality DevOps workstation bootstrapper.

### Planned

- [ ] Expand tool registry to 40+ tools
- [ ] Version pinning support (install specific versions, not just latest)
- [ ] Tool update command (`bootstrap.ps1 -Update`)
- [ ] PowerShell profile configuration (aliases, functions, prompt)
- [ ] Windows Terminal profile installation and configuration
- [ ] SSH key generation and management helpers
- [ ] Git global configuration wizard
- [ ] WSL detection and integration
- [ ] Chocolatey auto-install when WinGet is unavailable

---

## Phase 3 — Automation & Utilities

**Goal:** Daily-use productivity tooling and a unified CLI.

### Planned

- [ ] `winops` CLI command (PowerShell module in user's PATH)
- [ ] `winops doctor` — shortcut to doctor.ps1
- [ ] `winops install <tool>` — shortcut to install.ps1
- [ ] `winops update` — update all managed tools
- [ ] `winops status` — show current tool versions
- [ ] `winops network` — network diagnostics (DNS, ports, HTTP health)
- [ ] `winops docker` — Docker cleanup and diagnostics
- [ ] `winops kubernetes` — Kubernetes context switcher, pod inspector
- [ ] `winops environment` — environment variable viewer and editor
- [ ] Port scanner utility
- [ ] HTTP health check utility
- [ ] Certificate expiry checker

---

## Phase 4 — Advanced Ecosystem

**Goal:** A mature open-source platform for Windows DevOps workstation management.

### Considered (not committed)

- [ ] Plugin system for community extensions
- [ ] Environment snapshots (export/import entire tool configuration)
- [ ] Team profiles (share a profile via URL or file)
- [ ] Tool version matrix (pin specific versions per project)
- [ ] Cross-machine profile sync
- [ ] Optional GUI (PowerShell + WinForms or Avalonia)
- [ ] AI-assisted local diagnostics (no telemetry, runs locally)
- [ ] Workstation diff (compare two machines' tool inventories)

> Phase 4 begins only after Phase 2 and 3 are stable and well-tested.

---

## Not in Scope

- Custom package manager (WinGet exists and works)
- Replacing kubectl, Helm, or Terraform with custom wrappers
- Cloud infrastructure management (beyond CLI installation)
- Secret management (use vault, AWS Secrets Manager, etc.)
- GUI before CLI is stable
