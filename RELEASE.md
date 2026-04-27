# Release and Deployment Guide for FTEQW

This guide covers the release process, deployment strategies, and packaging for FTEQW, with special attention to macOS Apple Silicon (M1/M2/M3) deployments.

## Table of Contents

1. [Version Numbering](#version-numbering)
2. [Release Checklist](#release-checklist)
3. [Build Automation](#build-automation)
4. [macOS Code Signing & Notarization](#macos-code-signing--notarization)
5. [Distribution Channels](#distribution-channels)
6. [Post-Release Verification](#post-release-verification)
7. [Hotfixes and Patches](#hotfixes-and-patches)

---

## Version Numbering

FTEQW follows a flexible versioning scheme:

### Format
```
<major>.<minor>.<patch>[-<prerelease>]
```

### Examples
- `1.0.0` - Stable release
- `1.2.3` - Patch release with bug fixes
- `2.0.0` - Major release with breaking changes
- `1.5.0-beta1` - Pre-release beta
- `1.5.0-rc2` - Release candidate

### Version Locations

Update version in these files:
- `engine/common/version.h` (or generated via build system)
- `README.md` badges and references
- `CHANGELOG.md` header
- Build scripts (`build_setup.sh`, etc.)

---

## Release Checklist

### Pre-Release (1-2 weeks before)

#### Code Quality
- [ ] All tests passing (automated and manual)
- [ ] No known critical bugs
- [ ] Code review completed for all merged PRs
- [ ] Static analysis clean (clang-tidy, cppcheck)
- [ ] Memory leak checks (AddressSanitizer, Valgrind)
- [ ] Performance benchmarks run and acceptable

#### Documentation
- [ ] CHANGELOG.md updated with all changes
- [ ] README.md reviewed and accurate
- [ ] MACOS_M3_BUILD.md tested with fresh macOS install
- [ ] API documentation updated (if applicable)
- [ ] Migration guide for breaking changes
- [ ] Security advisories published (if applicable)

#### Testing
- [ ] Tested on macOS Apple Silicon (M1/M2/M3)
- [ ] Tested on macOS Intel
- [ ] Tested on Linux (multiple distributions)
- [ ] Tested on Windows (if applicable)
- [ ] Plugin compatibility verified
- [ ] QuakeC compiler tested with sample mods
- [ ] Multiplayer functionality tested
- [ ] Manifest file downloads working

#### Infrastructure
- [ ] Build servers configured
- [ ] Download mirrors ready
- [ ] Website updated (fteqw.org)
- [ ] Forum announcement drafted
- [ ] Social media posts prepared

### Release Day

#### Final Build
```bash
# 1. Tag the release
git tag -a v1.5.0 -m "FTEQW v1.5.0"
git push origin v1.5.0

# 2. Clean build
cd engine
gmake clean
gmake makelibs FTE_TARGET=SDL2
gmake gl-rel FTE_TARGET=SDL2
gmake qcc-rel

# 3. Build plugins
cd ../plugins
gmake clean
gmake all

# 4. Verify checksums
shasum -a 256 release/fteqw-sdl2 > SHA256SUMS
shasum -a 256 release/fteqcc > SHA256SUMS
```

#### macOS Specific
```bash
# Create .app bundle (optional but recommended)
mkdir -p FTEQW.app/Contents/MacOS
mkdir -p FTEQW.app/Contents/Resources
cp release/fteqw-sdl2 FTEQW.app/Contents/MacOS/FTEQW
cp engine/client/fte_eukara.ico FTEQW.app/Contents/Resources/icon.icns

# Create Info.plist
cat > FTEQW.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FTEQW</string>
    <key>CFBundleIdentifier</key>
    <string>org.fteqw.engine</string>
    <key>CFBundleName</key>
    <string>FTEQW</string>
    <key>CFBundleVersion</key>
    <string>1.5.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.5.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF
```

#### Code Signing (macOS)
```bash
# Sign the executable (requires Apple Developer ID)
codesign --force --deep --sign "Developer ID Application: Your Name" FTEQW.app

# Verify signature
codesign --verify --verbose FTEQW.app

# Notarize (required for Catalina+)
xcrun notarytool submit FTEQW.app \
  --apple-id "your@apple.id" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait

# Staple notarization ticket
xcrun stapler staple FTEQW.app
```

#### Packaging
```bash
# Create DMG (macOS)
hdiutil create -volname "FTEQW v1.5.0" \
  -srcfolder FTEQW.app \
  -ov -format UDZO fteqw-1.5.0-macos-arm64.dmg

# Create tarball (cross-platform)
tar -czvf fteqw-1.5.0-linux-x86_64.tar.gz release/
```

#### Publication
- [ ] Upload to fteqw.org
- [ ] Upload to GitHub Releases
- [ ] Update Homebrew formula (if applicable)
- [ ] Send forum announcement
- [ ] Post to Matrix/IRC/Discord
- [ ] Tweet/social media post

### Post-Release (Within 48 hours)

- [ ] Monitor crash reports and issues
- [ ] Respond to user feedback
- [ ] Fix any critical issues discovered
- [ ] Update download statistics
- [ ] Prepare patch release if needed

---

## Build Automation

### CI/CD Pipeline Setup

Example GitHub Actions workflow (`.github/workflows/release.yml`):

```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build-macos:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        brew install cmake sdl2 libpng jpeg-turbo libogg libvorbis freetype gnutls opus speex ffmpeg ode
    
    - name: Build engine
      run: |
        cd engine
        gmake makelibs FTE_TARGET=SDL2
        gmake gl-rel FTE_TARGET=SDL2
        gmake qcc-rel
    
    - name: Build plugins
      run: |
        cd plugins
        gmake all
    
    - name: Test
      run: |
        ./release/fteqw-sdl2 -version
    
    - name: Create DMG
      run: |
        # Package into DMG
        echo "DMG creation commands here"
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: fteqw-macos
        path: *.dmg

  build-linux:
    runs-on: ubuntu-latest
    # Similar configuration for Linux
```

### Automated Testing

```bash
#!/bin/bash
# test_suite.sh

set -e

echo "Running automated tests..."

# Unit tests
./run_unit_tests.sh

# Integration tests
./test_manifest_downloads.sh
./test_quakec_compilation.sh

# Performance tests
./benchmark_fps.sh

# Memory tests
ASAN_OPTIONS=detect_leaks=1 ./release/fteqw-sdl2 -version

echo "All tests passed!"
```

---

## macOS Code Signing & Notarization

### Prerequisites

1. **Apple Developer Account** ($99/year)
2. **Xcode** installed from App Store
3. **Command Line Tools**: `xcode-select --install`

### Getting Certificates

1. Open Xcode → Preferences → Accounts
2. Add your Apple ID
3. Manage Certificates → Create signing certificate
4. Download "Developer ID Application" certificate

### Finding Your Team ID

```bash
security find-identity -v -s "Developer ID Application"
# Output includes your team ID
```

### App-Specific Password

Generate at: https://appleid.apple.com/account/manage

1. Sign in with Apple ID
2. Security → App-Specific Passwords
3. Generate new password for "FTEQW Builds"

### Troubleshooting Notarization

**Common Issues:**

1. **"Invalid signature"**
   ```bash
   # Check certificate expiration
   security find-identity -v
   
   # Re-sign with correct certificate
   codesign --force --deep --sign "Developer ID Application: Your Name" FTEQW.app
   ```

2. **"Notarization failed"**
   ```bash
   # Get detailed error log
   xcrun notarytool log <submission_id> \
     --apple-id "your@apple.id" \
     --password "app-password" \
     --team-id "YOUR_TEAM_ID"
   ```

3. **Gatekeeper warnings for self-built versions**
   - Normal for unsigned builds
   - Users can right-click → Open to bypass once
   - Or disable temporarily: `xattr -dr com.apple.quarantine FTEQW.app`

---

## Distribution Channels

### Official Website (fteqw.org)

- Primary distribution channel
- Include checksums and signatures
- Provide both DMG and tarball formats
- Mirror downloads for redundancy

### GitHub Releases

```bash
# Using gh CLI
gh release create v1.5.0 \
  --title "FTEQW v1.5.0" \
  --notes-file RELEASE_NOTES.md \
  fteqw-1.5.0-macos-arm64.dmg \
  fteqw-1.5.0-linux-x86_64.tar.gz \
  SHA256SUMS
```

### Homebrew Formula

Create/update formula in homebrew-core or custom tap:

```ruby
class Fteqw < Formula
  desc "Advanced Quake engine"
  homepage "https://fteqw.org"
  url "https://fteqw.org/dl/fteqw-1.5.0.tar.gz"
  sha256 "abc123..."
  license "GPL-2.0"

  depends_on "cmake" => :build
  depends_on "sdl2"
  depends_on "libpng"
  # ... more dependencies

  def install
    cd "engine" do
      system "gmake", "gl-rel", "FTE_TARGET=SDL2"
    end
    bin.install "engine/release/fteqw-sdl2" => "fteqw"
  end

  test do
    system "#{bin}/fteqw", "-version"
  end
end
```

### Package Managers

- **Homebrew** (macOS/Linux)
- **Flatpak** (Linux)
- **Snap** (Linux)
- **Chocolatey** (Windows)

---

## Post-Release Verification

### Automated Checks

```bash
#!/bin/bash
# verify_release.sh

VERSION="1.5.0"

echo "Verifying FTEQW v${VERSION}..."

# Check download URLs
curl -I "https://fteqw.org/dl/fteqw-${VERSION}-macos-arm64.dmg"
curl -I "https://fteqw.org/dl/fteqw-${VERSION}-linux-x86_64.tar.gz"

# Verify checksums
sha256sum -c SHA256SUMS

# Test installation
# macOS
hdiutil attach "fteqw-${VERSION}-macos-arm64.dmg"
/Volumes/FTEQW*/FTEQW.app/Contents/MacOS/FTEQW -version
hdiutil detach "/Volumes/FTEQW"*

# Linux
tar -xzf "fteqw-${VERSION}-linux-x86_64.tar.gz"
./release/fteqw-sdl2 -version

echo "Verification complete!"
```

### Manual Testing Checklist

- [ ] Fresh install works without errors
- [ ] Game content downloads via manifest
- [ ] Graphics rendering correct
- [ ] Audio working
- [ ] Input devices recognized
- [ ] Multiplayer connection works
- [ ] QuakeC compiler functional
- [ ] Plugins load correctly
- [ ] Console commands work
- [ ] Configuration saved properly

### Monitoring

Set up monitoring for:
- Download counts
- Crash reports (if telemetry enabled)
- Issue tracker activity
- Forum/social media mentions
- Discord/Matrix community feedback

---

## Hotfixes and Patches

### When to Issue a Hotfix

- Critical security vulnerability
- Game-breaking bug affecting many users
- Data corruption issue
- Severe performance regression

### Hotfix Process

1. **Assess severity** and impact
2. **Develop fix** with minimal changes
3. **Test thoroughly** on all platforms
4. **Increment patch version** (1.5.0 → 1.5.1)
5. **Expedite release** process
6. **Communicate clearly** about the fix

### Emergency Security Patch

For critical security issues:

1. Fix immediately in private branch
2. Test minimally but adequately
3. Release signed update
4. Public advisory within 24-72 hours
5. Coordinate with downstream packagers

---

## Platform-Specific Notes

### macOS Apple Silicon (M1/M2/M3)

- **Architecture:** arm64 (AArch64)
- **Minimum OS:** macOS 11.0 (Big Sur)
- **Recommended:** macOS 12.0+ (Monterey)
- **Universal Binary:** Consider building for both arm64 and x86_64
- **Rosetta 2:** Test under Rosetta for Intel binary compatibility

```bash
# Universal binary build
export CFLAGS="-arch arm64 -arch x86_64"
export LDFLAGS="-arch arm64 -arch x86_64"
gmake gl-rel FTE_TARGET=SDL2

# Verify universal binary
lipo -info release/fteqw-sdl2
# Should show: Architectures in the fat file: arm64 x86_64
```

### Linux

- Provide AppImage for universal compatibility
- Consider Flatpak/Snap for sandboxed distribution
- Test on Ubuntu, Fedora, Arch at minimum

### Windows

- Provide both 32-bit and 64-bit builds
- Include Visual C++ Redistributable installer
- Sign executables with Authenticode certificate

---

## Release Announcement Template

```markdown
# FTEQW v1.5.0 Released! 🎉

We're excited to announce the release of FTEQW v1.5.0!

## What's New

### Features
- Feature 1 description
- Feature 2 description

### Improvements
- Improvement 1
- Improvement 2

### Bug Fixes
- Fixed issue #123
- Fixed issue #456

## Downloads

- **macOS (Apple Silicon):** [Download DMG](link)
- **macOS (Intel):** [Download DMG](link)
- **Linux:** [Download Tarball](link)
- **Windows:** [Download ZIP](link)

## Installation

### macOS
1. Download the DMG file
2. Drag FTEQW.app to Applications folder
3. Right-click → Open (first run only)

### Linux
```bash
tar -xzf fteqw-1.5.0-linux-x86_64.tar.gz
cd release
./fteqw-sdl2
```

## Known Issues

- Issue 1 (workaround: ...)
- Issue 2 (fixed in next release)

## Feedback

Report bugs on our issue tracker: [link]
Join the discussion: Matrix (#fte:matrix.org), Discord, Forums

Thank you to all contributors! 🙏
```

---

## Resources

- **Apple Notarization Docs:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Code Signing Guide:** https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/
- **GitHub Releases:** https://docs.github.com/en/repositories/releasing-projects-on-github
- **Homebrew Formulae:** https://docs.brew.sh/Formula-Cookbook

---

*Last Updated: 2025*
*Version: FTEQW Release Guide v1.0*
