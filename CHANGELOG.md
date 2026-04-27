# Changelog

All notable changes to FTEQW Game Engine will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive macOS M3 build documentation with step-by-step instructions
- Automated asset download system using manifest files
- Production-ready security policies and guidelines
- Complete asset pipeline documentation for modern formats (glTF, PNG, OGG, etc.)
- QuakeC test projects and mod templates
- Plugin architecture with hot-reloading support
- Cross-platform build system (CMake and GNU Make)

### Changed
- Enhanced build system for Apple Silicon optimization
- Improved documentation structure and accessibility

### Fixed
- Resolved architecture mismatch issues on ARM64 systems
- Fixed macOS security warning handling for unsigned binaries

## [1.0.0] - 2024-01-15

### Added
- Initial production release
- Full QuakeWorld compatibility
- Advanced rendering engine with GLSL shader support
- Network multiplayer with anti-cheat measures
- Modular plugin system
- QuakeC compiler (FTEQCC) with extended opcodes
- Server browser and master server integration
- Demo recording and playback system
- Console command system with scripting
- Virtual file system with PK3/PAK archive support
- Audio subsystem with Ogg Vorbis and Opus support
- Input system supporting keyboard, mouse, and gamepads
- Map loading with BSP, MDL, MD2, MD3, IQM model formats
- Texture compression support (DXT, ETC, ASTC)
- Dynamic lighting and shadow mapping
- Particle system effects
- Physics integration with ODE support
- Lua scripting interface
- SQLite database integration
- HTTPS/SSL network support via GnuTLS
- Voice chat support via Opus codec
- Video playback support via FFmpeg

### Security
- Implemented secure random number generation
- Added input validation and sanitization
- Network packet verification and checksums
- File path traversal protection
- Buffer overflow protections
- ASLR and stack canary support
- Secure memory handling practices

### Documentation
- Comprehensive README with quick start guide
- macOS M3 build instructions
- Asset pipeline documentation
- Security guidelines
- Release process documentation
- Production readiness checklist

## [0.9.0] - 2023-12-01

### Added
- Beta release candidate
- Feature complete core engine
- Plugin API stabilization
- Extended QuakeC opcode set

### Changed
- Performance optimizations for rendering pipeline
- Network code refactoring for better latency handling

## [0.8.0] - 2023-10-15

### Added
- Early beta with core gameplay features
- Basic rendering and audio systems
- Initial plugin framework
- QuakeC compiler with basic extensions

## [0.7.0] - 2023-08-01

### Added
- Alpha release for testing
- Core engine architecture
- Basic QuakeWorld protocol implementation
- Initial build system setup

---

## Version Numbering

- **Major**: Breaking changes or significant new features
- **Minor**: New features, improvements, backwards compatible
- **Patch**: Bug fixes and minor improvements

## Release Types

- **Stable**: Production-ready releases
- **Beta**: Feature complete, testing phase
- **Alpha**: Early testing, incomplete features
- **Dev**: Development builds, may be unstable

## Contributing

When submitting pull requests, please update this changelog with your changes
following the format above. See CONTRIBUTING.md for more details.
