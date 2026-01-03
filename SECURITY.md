# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported |
|---------|-----------|
| 1.x | ✅ |
| < 1.0 | ❌ |

**Recommendation:** Always use the latest version for best security and features.

---

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow these steps:

### 1. Do NOT Open a Public Issue

Security vulnerabilities should **not** be reported via public GitHub issues. Public disclosure could put users at risk before a fix is available.

### 2. Report Privately

**Use GitHub's private vulnerability reporting:**
1. Go to the [Security tab](https://github.com/joshsmithxrm/ppds-tools/security)
2. Click "Report a vulnerability"
3. Fill out the form with details

### 3. Include in Your Report

- **Description**: Clear description of the vulnerability
- **Impact**: What an attacker could do (credential exposure, privilege escalation, etc.)
- **Steps to Reproduce**: Detailed steps or proof-of-concept code
- **Affected Cmdlets**: Which PPDS.Tools cmdlets are vulnerable
- **Suggested Fix**: If you have ideas (optional)

### 4. Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 5 business days
- **Fix Development**: Depends on severity (critical: 7-14 days, high: 14-30 days)
- **Security Release**: Coordinated disclosure after fix is ready

---

## Security Practices

### What We Do

1. **Dependency Scanning**: Automated checks for vulnerable dependencies (GitHub Dependabot)
2. **Code Reviews**: All PRs reviewed for security issues
3. **CLI Wrapper Pattern**: All operations delegated to `ppds` CLI (reduced attack surface)
4. **No Credential Storage**: Module never stores credentials; delegates to CLI profiles

### Architecture Security

PPDS.Tools is a **pure CLI wrapper**. All cmdlets invoke the `ppds` CLI tool:

```
PowerShell Cmdlet → ppds CLI → Dataverse
```

**Security benefits:**
- No direct credential handling in PowerShell
- Authentication managed by PPDS.Auth (in CLI)
- Reduced code surface for security vulnerabilities
- Single security audit point (the CLI)

### Authentication (Profile-Based)

All authentication is delegated to the `ppds` CLI's profile system:

```powershell
# Creates profile via CLI (credentials handled by CLI, not PowerShell)
Connect-DataverseEnvironment -DeviceCode -Name "dev"

# All cmdlets use stored profile
Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile "dev"
```

**Best practices for users:**
- Use device code or OIDC for interactive scenarios
- Use service principal with environment variables for CI/CD
- Never pass `-ClientSecret` directly; use `$env:CLIENT_SECRET`

---

## Known Security Considerations

### 1. PowerShell History

Commands appear in PowerShell history. Avoid passing secrets directly:

```powershell
# ❌ Bad - Secret in history
Connect-DataverseEnvironment -ClientSecret "my-secret" ...

# ✅ Good - Secret from environment
Connect-DataverseEnvironment -ClientSecret $env:CLIENT_SECRET ...
```

### 2. Script Execution Policy

PowerShell's execution policy affects module loading:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Module Source Verification

Verify you're installing from PowerShell Gallery:

```powershell
# Check module source
Find-Module PPDS.Tools | Select-Object Name, Version, Repository

# Install from official source only
Install-Module PPDS.Tools -Repository PSGallery
```

---

## Security Updates

### How to Stay Informed

1. **Watch this repository** (Releases only or All Activity)
2. **Check CHANGELOG.md** for security fixes (marked with "Security")
3. **Subscribe to GitHub Security Advisories** for this repo

### Applying Security Updates

```powershell
# Update module
Update-Module PPDS.Tools -Force

# Also update the CLI tool
dotnet tool update -g PPDS.Cli

# Verify versions
Get-Module PPDS.Tools -ListAvailable
ppds --version
```

---

## Security Checklist for Contributors

If you're contributing code, please review:

- [ ] No hardcoded credentials or secrets
- [ ] Use `[SecureString]` for password parameters where applicable
- [ ] No logging of tokens, secrets, or credentials
- [ ] Input validation on all public parameters
- [ ] Error messages don't leak sensitive information
- [ ] CLI arguments properly escaped to prevent injection

---

## Disclosure Policy

### Coordinated Disclosure

We follow **coordinated disclosure**:
1. Reporter notifies us privately
2. We develop and test a fix
3. We release a patched version
4. We publish a security advisory
5. Reporter can publish details (after patch release)

**Typical timeline:** 30-90 days from report to public disclosure

---

## Contact

- **Security Issues**: [GitHub Private Vulnerability Reporting](https://github.com/joshsmithxrm/ppds-tools/security/advisories/new)
- **General Security Questions**: Open a [GitHub Discussion](https://github.com/joshsmithxrm/ppds-tools/discussions)
- **Non-Security Bugs**: Open a [GitHub Issue](https://github.com/joshsmithxrm/ppds-tools/issues)

---

**Thank you for helping keep PPDS.Tools secure!**
