# Security Policy

## Reporting a Vulnerability

We take the security of Legal MCP seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please DO NOT open a public GitHub issue for security vulnerabilities.**

Instead, report security issues privately:

1. **GitHub Security Advisories** (preferred):
   - Go to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the security advisory form

2. **Alternative contact**:
   - Open a draft security advisory on GitHub
   - Or create a private issue if you need to discuss first

### What to Include

Please include as much of the following information as possible:

- **Description** of the vulnerability
- **Steps to reproduce** the issue
- **Potential impact** of the vulnerability
- **Affected versions** (if known)
- **Suggested fix** (if you have one)
- **Your contact information** for follow-up

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 1-7 days
  - High: 1-4 weeks
  - Medium: 1-2 months
  - Low: Best effort

### What to Expect

1. We will acknowledge your report
2. We will investigate and validate the vulnerability
3. We will work on a fix
4. We will notify you when the fix is ready
5. We will publicly disclose after the fix is deployed
6. We will credit you in the security advisory (if you wish)

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

We support the latest release with security updates. Older versions may not receive security patches.

## Security Best Practices

### For Deployments

1. **Environment Variables**
   - Never commit `.env` files with real credentials
   - Use strong, unique passwords for production databases
   - Rotate credentials regularly
   - Store secrets securely (use secret management tools for production)

2. **Database Security**
   - Change default PostgreSQL credentials immediately
   - Use strong passwords (16+ characters, mixed case, numbers, symbols)
   - Restrict database access to necessary services only
   - Enable SSL/TLS for database connections in production

3. **API Security**
   - Use HTTPS for all production deployments
   - Set ENVIRONMENT=production in production
   - Configure CORS appropriately (don't use `*` in production)
   - Monitor for unusual activity or abuse

4. **Network Security**
   - Don't expose PostgreSQL port (5432) publicly
   - Use firewall rules to restrict access
   - Consider using a VPN or private network for services
   - Use Docker networks to isolate services

5. **Ollama Security**
   - Secure your Ollama endpoint
   - Use authentication tokens
   - Don't expose Ollama publicly if possible
   - Monitor usage and costs

### For Development

1. **Credentials**
   - Never commit secrets to git
   - Use `.env.example` for documenting required variables
   - Use different credentials for development and production
   - Don't share production credentials

2. **Dependencies**
   - Keep dependencies up to date
   - Review security advisories regularly
   - Run `pip-audit` or `safety check` periodically
   - Use dependabot or similar tools

3. **Code Review**
   - Review security implications of changes
   - Check for SQL injection, XSS, SSRF vulnerabilities
   - Validate all user inputs
   - Use parameterized queries

## Known Security Considerations

### Input Validation

- Legal code parameters are validated to prevent SSRF attacks
- Maximum code length is enforced (50 characters)
- Only alphanumeric characters, hyphens, and underscores allowed

### Error Handling

- Production mode hides detailed error messages
- Error IDs provided for tracking without information disclosure
- All errors logged with full details server-side

### Request Limits

- Request body size limited to 10 MB
- Prevents memory exhaustion attacks
- Returns 413 status for oversized requests

### Database

- SQL injection prevented through SQLAlchemy ORM
- Parameterized queries used throughout
- No raw SQL with user input

### Current Limitations

- **No rate limiting**: High-priority item for Phase 2
  - Recommendation: Add rate limiting before public announcement
  - Vulnerable to DoS on import and search endpoints

- **No authentication**: Public API design
  - Consider adding API keys for production use
  - Monitor usage patterns

- **Ollama dependency**: External service
  - Secure your Ollama endpoint
  - Monitor costs and usage
  - Consider rate limiting Ollama calls

## Security Updates

Security updates will be announced through:
- GitHub Security Advisories
- Release notes
- README updates

Subscribe to repository releases to get notified of security updates.

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security Best Practices](https://fastapi.tiangolo.com/tutorial/security/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)

## Questions?

If you have questions about security but don't want to report a vulnerability:
- Open a public issue with the `security` label
- Discuss in pull requests or issues
- Check existing security documentation

Thank you for helping keep Legal MCP secure! 🔒
