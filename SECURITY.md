# Security Policy

## Supported Versions

The following versions of FTEQW are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| Latest development branch | ✅ Supported     |
| Previous stable release   | ✅ Supported (6 months) |
| Older versions            | ❌ Not supported      |

**Note:** Due to the nature of open-source game engines, we recommend always using the latest version from the main repository or official releases at [fteqw.org](https://fteqw.org).

## Reporting a Vulnerability

We take the security of FTEQW seriously. If you believe you've found a security vulnerability, please follow these steps:

### **DO NOT** report security vulnerabilities through public GitHub issues, forums, or chat channels.

### How to Report

1. **Email:** Send an email to the development team at:
   - Primary: `security@fteqw.org` (if available)
   - Alternative: Contact team members via Matrix (#fte:matrix.org) or IRC (irc.quakenet.org #fte)

2. **Include the following information:**
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact
   - Any suggested fixes (if known)
   - Your contact information for follow-up questions

3. **Expected Response Time:**
   - Initial acknowledgment: Within 48 hours
   - Status update: Within 5 business days
   - Resolution timeline: Depends on severity (see below)

### Severity Levels and Response Times

| Severity | Description | Target Resolution |
|----------|-------------|-------------------|
| **Critical** | Remote code execution, severe memory corruption | 24-72 hours |
| **High** | Buffer overflows, use-after-free, significant DoS | 1 week |
| **Medium** | Local file disclosure, moderate DoS | 2 weeks |
| **Low** | Minor information leakage, cosmetic issues | 1 month |

## Security Best Practices for Users

### Network Security

- **Multiplayer Servers:** Only connect to trusted servers
- **Port Forwarding:** Be cautious when exposing your server to the internet
- **Firewall:** Configure your firewall to only allow necessary ports
- **Master Servers:** Use official master servers when possible

### File Safety

- **Custom Maps/Mods:** Only download from trusted sources
- **Plugin Loading:** Be cautious with third-party plugins
- **Config Files:** Review config files from untrusted sources
- **Pak Files:** Malicious pak files can potentially exploit vulnerabilities

### System Security

- **Updates:** Keep your FTEQW installation up to date
- **Permissions:** Run the engine with minimal required permissions
- **Antivirus:** Keep antivirus software updated (especially on Windows)
- **macOS Security:** Be aware of Gatekeeper warnings for unsigned builds

## Known Security Considerations

### QuakeC Security

- QuakeC bytecode is sandboxed but review custom QC code before running
- Avoid running QC from untrusted sources without inspection
- FTEQCC includes debugging features that should be disabled in production

### Network Protocol

- The Quake network protocol was not designed with modern security in mind
- Encryption is limited; assume network traffic can be intercepted
- Server authentication is basic; verify server identity manually

### Plugin System

- Plugins run with the same privileges as the engine
- Only load plugins from trusted developers
- Review plugin source code when possible
- Some plugins (e.g., FFmpeg, SSL) have their own security considerations

## Security Features

### Implemented Security Measures

- **Sandboxing:** QuakeC runs in a virtual machine with limited access
- **Input Validation:** Extensive validation of network and file inputs
- **Memory Safety:** Modern C practices to reduce buffer overflows
- **SSL/TLS:** Support for secure connections (via OpenSSL/GnuTLS plugins)
- **Path Traversal Protection:** Prevention of directory traversal attacks

### Configuration Options

```c
// Disable network entirely (single-player only)
net_disable 1

// Restrict downloaded files
cl_downloadmaps 0
cl_downloadsounds 0

// Disable plugin loading
plugin_load_disabled 1

// Secure server settings (for server operators)
sv_password "your_secure_password"
rcon_password "your_very_secure_rcon_password"
```

## For Developers and Contributors

### Secure Coding Guidelines

1. **Buffer Management:**
   - Always check buffer bounds
   - Use `sizeof()` and length parameters
   - Prefer safe string functions (`strlcpy`, `snprintf`)

2. **Memory Safety:**
   - Initialize all variables
   - Check return values from memory allocations
   - Free resources properly to prevent leaks

3. **Input Validation:**
   - Validate all user input
   - Sanitize strings from network/file sources
   - Never trust client-side data on the server

4. **Network Security:**
   - Validate packet sizes
   - Rate-limit connections
   - Implement proper authentication

5. **File I/O:**
   - Validate file paths
   - Check file permissions
   - Handle errors gracefully

### Code Review Process

- All security-sensitive changes require review
- Use static analysis tools when possible
- Test with AddressSanitizer and UndefinedBehaviorSanitizer
- Review for common vulnerabilities (CWE Top 25)

## Incident Response Process

When a security vulnerability is discovered:

1. **Report Received:** Acknowledge within 48 hours
2. **Assessment:** Evaluate severity and impact
3. **Fix Development:** Create and test patch
4. **Disclosure Coordination:** Work with reporter on disclosure timing
5. **Release:** Publish security update
6. **Public Disclosure:** Announce after users have had time to update (typically 2-4 weeks)

## Disclosure Policy

We follow a coordinated disclosure approach:

- **Pre-announcement:** Notify major distributors and downstream projects
- **Embargo Period:** Allow 2-4 weeks for users to update before public details
- **Credit:** Acknowledge security researchers who report responsibly
- **Transparency:** Publish security advisories with CVE IDs when applicable

## External Dependencies

FTEQW uses several external libraries. Security updates for these dependencies are incorporated as they become available:

- **SDL2** - Cross-platform multimedia
- **libpng** - PNG image support
- **libjpeg** - JPEG image support
- **libogg/libvorbis** - Audio codecs
- **Opus/Speex** - Voice chat codecs
- **GnuTLS/OpenSSL** - SSL/TLS support
- **FFmpeg** - Media decoding (plugin)
- **ODE/Bullet** - Physics engines (plugins)

Keep these dependencies updated through your package manager or build from source with the latest versions.

## Platform-Specific Security

### macOS

- **Code Signing:** Official releases are signed
- **Notarization:** Releases are notarized for macOS Catalina and later
- **Gatekeeper:** May warn about unsigned builds; this is normal for self-compiled versions
- **System Integrity Protection:** FTEQW operates within SIP constraints

### Linux

- **AppArmor/SELinux:** Can be configured for additional sandboxing
- **Namespaces:** Consider running in container for isolation
- **Capabilities:** Minimal capabilities required

### Windows

- **DEP/ASLR:** Enabled in official builds
- **Windows Defender:** May flag custom builds; add exclusion if needed
- **UAC:** Standard user privileges sufficient for most operations

## Contact and Resources

- **Security Mailing List:** security@fteqw.org (if available)
- **Matrix:** #fte:matrix.org
- **IRC:** irc.quakenet.org #fte
- **Discord:** https://discord.gg/p2ag7x6Ca6
- **Forums:** https://forums.insideqc.com/

## Acknowledgments

We would like to thank all security researchers who have responsibly disclosed vulnerabilities to help make FTEQW more secure.

---

*This security policy is subject to change. Last updated: 2025*

*For general inquiries, please use the regular communication channels listed in README.md*
