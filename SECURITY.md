# Security Policy

## Supported Versions

We actively support security updates for the following versions of Sure:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| Previous| :white_check_mark: |
| Older   | :x:                |

**Note:** As an open-source project, we recommend always using the latest version for the best security posture.

## Reporting a Vulnerability

### How to Report

We take security vulnerabilities seriously. If you discover a security issue in Sure, please report it responsibly:

**🔒 For Security Issues:**
- **Email:** [hendri@permana.icu](mailto:hendri@permana.icu)
- **GitHub Security Advisory:** Use GitHub's [private vulnerability reporting](https://github.com/hendripermana/Sure/security/advisories/new)
- **Alternative:** Create a private issue by emailing the maintainers directly

### What to Include

When reporting a vulnerability, please include:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** and severity assessment
4. **Affected versions** (if known)
5. **Suggested fix** (if you have one)
6. **Your contact information** for follow-up questions

### Response Timeline

We are committed to responding to security reports promptly:

- **Initial Response:** Within 48 hours of report
- **Status Update:** Within 7 days with preliminary assessment
- **Resolution Timeline:** Varies based on complexity, but we aim for:
  - Critical: 1-7 days
  - High: 7-30 days
  - Medium/Low: 30-90 days

### Disclosure Policy

1. **Coordinated Disclosure:** We follow responsible disclosure practices
2. **Public Disclosure:** After a fix is available and deployed
3. **Credit:** We will acknowledge security researchers (unless they prefer anonymity)
4. **CVE Assignment:** For significant vulnerabilities, we will work to assign CVEs

### Security Best Practices for Users

#### Self-Hosting Security

- **Keep Updated:** Always use the latest version
- **Secure Configuration:** Follow our security configuration guide
- **Environment Variables:** Never commit secrets to version control
- **Database Security:** Use strong passwords and restrict access
- **HTTPS:** Always use HTTPS in production
- **Backup Security:** Encrypt backups and store securely

#### Data Protection

- **Financial Data:** All financial data should be encrypted at rest
- **User Authentication:** Enable 2FA when available
- **Access Control:** Implement proper user access controls
- **Regular Audits:** Periodically review access logs and permissions

### Security Features

Sure includes several security features:

- **Data Encryption:** Sensitive data encryption at rest
- **Secure Authentication:** Multi-factor authentication support
- **Session Management:** Secure session handling
- **Input Validation:** Protection against common web vulnerabilities
- **Audit Logging:** Security event logging

### Out of Scope

The following are generally considered out of scope for security reports:

- Issues in third-party dependencies (report to upstream)
- Social engineering attacks
- Physical security issues
- Denial of service attacks
- Issues requiring physical access to the server

### Legal

By reporting security vulnerabilities, you agree to:

- Not access or modify user data without explicit permission
- Not perform testing on production systems you don't own
- Comply with all applicable laws and regulations
- Act in good faith and avoid privacy violations

### Contact

For non-security related issues, please use:
- **General Issues:** [GitHub Issues](https://github.com/hendripermana/Sure/issues)
- **Discussions:** [GitHub Discussions](https://github.com/hendripermana/Sure/discussions)

---

**Thank you for helping keep Sure and our community safe!**
