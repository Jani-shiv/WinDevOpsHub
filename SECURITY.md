# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (main branch) | ✅ |
| All others | ❌ |

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub Issues.**

To report a security issue privately:

1. Open a [GitHub Security Advisory](https://github.com/Jani-shiv/WinDevOpsHub/security/advisories/new) in this repository.
2. Provide a detailed description of the vulnerability.
3. Include steps to reproduce.
4. Describe the potential impact.

You will receive a response within 7 business days acknowledging receipt.

---

## Security Design Principles

WinDevOpsHub is designed as privileged software (it installs tools and modifies system state).
These principles govern its security posture:

### What we never do

- Download binaries from untrusted or unverified sources
- Execute remote scripts without explicit user review
- Disable Windows security features (Defender, Firewall, UAC, Credential Protection)
- Store secrets, API keys, tokens, or credentials in the repository or log files
- Modify registry keys unrelated to managed tools
- Create hidden user accounts or services
- Silently modify PATH or environment variables
- Embed hardcoded credentials of any kind

### What we always do

- Use WinGet (signed, Microsoft-maintained) as the primary package manager
- Prefer official vendor packages
- Require explicit user confirmation before installing tools
- Support dry-run to let users review planned changes
- Log every significant system modification with full transparency
- Operate at user scope by default (no admin unless explicitly required and explained)

### Credential handling

WinDevOpsHub does not manage cloud credentials. Cloud CLIs (AWS CLI, Azure CLI, etc.)
handle authentication themselves. WinDevOpsHub only installs the CLI tools.

---

## Dependency Security

All tools installed by WinDevOpsHub are sourced from WinGet, which verifies package
signatures from official publishers. The package IDs in `config/tools.json` are
maintained by the project and verified against official sources.
