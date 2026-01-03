# Security Policy

## Supported Versions

Only the latest version of Unify is supported with security updates.

## Reporting a Vulnerability

If you discover a security vulnerability in Unify, please disclose it responsibly.

**Do NOT:**
- Create a public issue
- Discuss the vulnerability publicly
- Post about it on social media before disclosure

**DO:**
- Send me an email with details about the vulnerability

### Contact Information

**Email:** [denys.madureira@pm.me](mailto:denys.madureira@pm.me)

Please include as much detail as possible:
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any suggested fixes (if applicable)

### Response Timeline

I aim to respond to security reports within **7 days**. I will work with you to:
1. Understand and verify the vulnerability
2. Develop a fix
3. Coordinate a disclosure timeline

### Acknowledgments

Responsible disclosures will be acknowledged in the release notes (with your permission, if desired).

## Security Considerations

Unify is a web application aggregator that loads user-configured web services in Qt WebEngine views. Users should be aware of:

### Permission Handling

Unify automatically grants certain browser permissions to ensure web services work properly:
- Geolocation
- Media capture (audio/video)
- Screen/window sharing
- Notifications
- Clipboard access

These permissions are granted automatically for convenience, as users have explicitly configured the services they want to use.

### Data Storage

- **Cookies and localStorage** are persisted via Qt's WebEngineProfile
- Storage location: `~/.local/share/io.github.denysmb/Unify/` (or Flatpak equivalent, like `~/.var/app/io.github.denysmb.unify/data/io.github.denysmb/Unify/`)
- User data is not collected or transmitted to any third-party servers

### Network Activity

Unify does not proxy or intercept network traffic. All web services communicate directly with their respective servers, as if opened in a standalone browser.

### Isolated Profiles

Services can be configured with `isolatedProfile: true` to use separate cookie/storage, preventing cross-service tracking.

## Scope

This security policy applies to the Unify application code

## Out of Scope

The following are NOT considered security vulnerabilities for this project:
- Issues in third-party web services that Unify loads
- Vulnerabilities in Qt/Chromium used by the application
- Misconfigured user services (users control what URLs they add)
- Feature requests or design decisions
