# Contributing to FTEQW Game Engine

Thank you for your interest in contributing to FTEQW! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to maintain a welcoming and inclusive community.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/fteqw.git
   cd fteqw
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/fteqw/fteqw.git
   ```
4. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- **macOS**: Xcode Command Line Tools, Homebrew
- **Linux**: GCC/Clang, Make, CMake
- **Windows**: Visual Studio 2019+, MinGW

See [MACOS_M3_BUILD.md](MACOS_M3_BUILD.md) for detailed macOS setup instructions.

### Build the Project

```bash
# Using CMake (recommended)
mkdir build && cd build
cmake ..
cmake --build . --config Release

# Or using GNU Make
cd engine
gmake makelibs
gmake gl-rel
```

### Run Tests

```bash
# Build test suite
gmake tests

# Run unit tests
./run_tests.sh

# Run integration tests
./integration_tests.sh
```

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected vs actual behavior**
- **Screenshots or logs** if applicable
- **Environment details** (OS, compiler, hardware)

**Example:**
```markdown
**Bug Description**
Engine crashes when loading large maps on macOS M3.

**Steps to Reproduce**
1. Launch fteqw with map "large_test.bsp"
2. Wait for map to load
3. Engine crashes with segmentation fault

**Expected Behavior**
Map should load successfully

**Environment**
- OS: macOS Sonoma 14.2
- Hardware: MacBook Air M3
- Compiler: clang 15.0
```

### Suggesting Features

Feature suggestions are welcome! Please provide:

- **Use case**: Why is this feature needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches
- **Additional context**: Screenshots, examples

### Your First Contribution

Unsure where to start? Look for issues labeled:
- `good first issue` - Perfect for beginners
- `help wanted` - Needs community help
- `documentation` - Improve docs

## Coding Standards

### C/C++ Code Style

- **Indentation**: Tabs (8 spaces), consistent throughout file
- **Line length**: Max 120 characters
- **Naming conventions**:
  - Functions: `lowercase_with_underscores()`
  - Variables: `lowercase_with_underscores`
  - Types: `PascalCase`
  - Constants: `UPPERCASE_WITH_UNDERSCORES`
  - Macros: `UPPERCASE_WITH_UNDERSCORES`

- **Comments**: 
  - Use `//` for single-line comments
  - Use `/* */` for multi-line comments
  - Document public APIs with Doxygen-style comments

```c
/**
 * Initialize the rendering subsystem.
 * 
 * @param width Window width in pixels
 * @param height Window height in pixels
 * @param fullscreen Enable fullscreen mode
 * @return qtrue on success, qfalse on failure
 */
qboolean R_Init(int width, int height, qboolean fullscreen);
```

### QuakeC Code Style

- Follow existing QuakeC conventions in `quakec/` directory
- Use meaningful variable and function names
- Comment complex logic
- Include file headers with purpose and author

```quakec
/*
=============================================================================
Function: Player_Jump
Purpose: Handle player jump mechanics with physics
Author: Your Name
=============================================================================
*/
void() Player_Jump =
{
    // Check if player is on ground
    if (self.flags & FL_ONGROUND)
    {
        // Apply jump velocity
        self.velocity_z = 270;
    }
};
```

### File Organization

- **Source files**: `.c`, `.cpp` in appropriate subdirectories
- **Headers**: `.h` alongside source or in `include/`
- **QuakeC**: `.qc` files in `quakec/`
- **Shaders**: `.glsl`, `.cg` in `shaders/`
- **Documentation**: `.md` in root or `documentation/`

## Commit Guidelines

### Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring without feature changes
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, build changes
- `security`: Security fixes

### Examples

```bash
# Good commit messages
git commit -m "feat(renderer): add support for ASTC texture compression"
git commit -m "fix(network): resolve packet loss on high-latency connections"
git commit -m "docs(macOS): update M3 build instructions with new dependencies"
git commit -m "perf(audio): reduce latency in Opus decoder by 30%"
git commit -m "security(crypto): upgrade GnuTLS to latest stable version"
```

### Atomic Commits

- Each commit should represent a single logical change
- Split large changes into multiple commits
- Avoid mixing unrelated changes in one commit

## Pull Request Process

### Before Submitting

1. **Update documentation** if changing functionality
2. **Add tests** for new features
3. **Ensure all tests pass**
4. **Update CHANGELOG.md** with your changes
5. **Rebase on main** to get latest changes

### PR Template

When creating a pull request, use this template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature requiring migration)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Security fix

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passed
- [ ] Manual testing completed
- [ ] Tested on macOS M3
- [ ] Tested on Linux
- [ ] Tested on Windows (if applicable)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No new warnings introduced
- [ ] Test coverage maintained or improved

## Related Issues
Fixes #123
Related to #456
```

### Review Process

1. **Automated checks** must pass (CI/CD)
2. **Maintainer review** - At least one approval required
3. **Address feedback** - Respond to all review comments
4. **Final approval** - Maintainer merges PR

## Testing Requirements

### Unit Tests

- Write unit tests for new functions
- Maintain >80% code coverage for new code
- Place tests in `tests/unit/` directory

### Integration Tests

- Test component interactions
- Verify end-to-end functionality
- Place tests in `tests/integration/` directory

### Manual Testing

Test your changes on:
- **macOS Apple Silicon** (M1/M2/M3)
- **Linux** (Ubuntu, Fedora, or similar)
- **Windows** (if applicable)

### Performance Testing

- Benchmark performance-critical code
- Ensure no regressions in frame rate
- Test memory usage under load

## Documentation

### Code Documentation

- Document all public APIs
- Explain complex algorithms
- Include usage examples

### User Documentation

- Update README.md for user-facing changes
- Add examples to ASSET_PIPELINE.md
- Update MACOS_M3_BUILD.md for build changes

### API Documentation

Generate API docs:
```bash
doxygen Doxyfile
```

## Community

### Communication

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: Questions, ideas
- **Discord/IRC**: Real-time chat (link in README)

### Recognition

Contributors are recognized in:
- CHANGELOG.md
- CONTRIBUTORS file
- Release announcements

## License

By contributing, you agree that your contributions will be licensed under the project's license (see LICENSE file).

---

Thank you for contributing to FTEQW! 🎮
