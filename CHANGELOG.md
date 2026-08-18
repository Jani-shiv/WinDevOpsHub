# CHANGELOG

All notable changes to WinDevOpsHub are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- Phase 1 foundation: full repository architecture
- Core PowerShell framework (Logger, Platform, Errors, Config modules)
- Tool registry (`config/tools.json`) with 19 tools defined
- PackageManager layer: WinGet (primary), Chocolatey (fallback), unified Installer
- Six installation profiles: Minimal, DevOps, AWS, Azure, Kubernetes, Full
  - Profile inheritance (e.g. DevOps extends Minimal)
  - Tool deduplication across inherited profiles
- `scripts/bootstrap.ps1` — idempotent bootstrapper with `-Profile`, `-DryRun`, `-Scope`, `-LogFile`
- `scripts/doctor.ps1` — environment health checker with 8 check categories, actionable suggestions, `-Json` output
- `scripts/install.ps1` — install specific tools by registry ID
- `scripts/uninstall.ps1` — safely remove managed tools via WinGet
- System module: safe additive PATH management (no replacement, no duplicates)
- Pester test suite: unit tests for Logger, Platform, Config, PackageManager, System
- Integration tests for bootstrap.ps1 and doctor.ps1 (dry-run safe)
- GitHub Actions CI: syntax check, PSScriptAnalyzer, config validation, Pester unit/integration tests, TruffleHog secret scan, doc check
- PR check workflow
- Full documentation: README, architecture, installation, development, troubleshooting, roadmap
- Community files: CONTRIBUTING, SECURITY, CODE_OF_CONDUCT

---

## [0.0.1] — 2026-08-18

### Added

- Initial repository with README and LICENSE
