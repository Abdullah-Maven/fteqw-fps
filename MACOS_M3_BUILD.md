# Building FTEQW on macOS (Apple Silicon M1/M2/M3)

This guide provides step-by-step instructions to build the FTEQW game engine on your MacBook Air/Pro with Apple Silicon (M1, M2, or M3 chips).

## Prerequisites

Before you begin, ensure you have the following installed:

### 1. Install Xcode Command Line Tools

Open Terminal and run:

```bash
xcode-select --install
```

Follow the prompts to complete the installation. This provides essential development tools including `clang`, `make`, and `git`.

### 2. Install Homebrew (if not already installed)

Homebrew is the package manager for macOS. Install it by running:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, add Homebrew to your PATH:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 3. Install Required Dependencies

Install all necessary dependencies using Homebrew:

```bash
brew install cmake sdl2 libpng jpeg-turbo libogg libvorbis freetype gnutls opus speex
```

For optional features (recommended):

```bash
# For video playback and streaming
brew install ffmpeg

# For physics simulation
brew install ode

# For OpenSSL support
brew install openssl
```

## Build Instructions

### Method 1: Using CMake (Recommended for macOS)

This method is ideal for development and testing on macOS.

#### Step 1: Navigate to the Repository

```bash
cd /path/to/fteqw
```

#### Step 2: Create Build Directory

```bash
mkdir build
cd build
```

#### Step 3: Configure with CMake

Run CMake to configure the build:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
```

**Important Notes for Apple Silicon:**
- CMake will automatically detect your ARM64 architecture
- All dependencies installed via Homebrew are native to Apple Silicon

#### Step 4: Build the Engine

```bash
cmake --build . -j$(sysctl -n hw.ncpu)
```

The `-j` flag uses all available CPU cores for faster compilation.

#### Step 5: Build Optional Plugins (if desired)

To build plugins, you need to use the Makefile system instead (see Method 2 below), as CMake doesn't currently support all plugin builds on macOS.

### Method 2: Using GNU Make (Traditional Method)

This method provides more control and supports building plugins.

#### Step 1: Install GNU Make

macOS comes with BSD make, but FTEQW works best with GNU make:

```bash
brew install make
```

#### Step 2: Navigate to Engine Directory

```bash
cd /path/to/fteqw/engine
```

#### Step 3: Build Dependencies (Optional but Recommended)

Build static libraries for better portability:

```bash
gmake makelibs FTE_TARGET=SDL2
```

#### Step 4: Build the Engine

For a release build with SDL2 (recommended for macOS):

```bash
gmake gl-rel FTE_TARGET=SDL2
```

Or for a debug build (useful for development):

```bash
gmake gl-debug FTE_TARGET=SDL2
```

#### Step 5: Build Dedicated Server (Optional)

If you want to run a dedicated server:

```bash
gmake sv-rel FTE_TARGET=SDL2
```

#### Step 6: Build QuakeC Compiler (Recommended)

```bash
gmake qcc-rel
```

#### Step 7: Build Plugins (Optional)

Build common plugins:

```bash
gmake plugins-rel FTE_TARGET=SDL2 NATIVE_PLUGINS="ffmpeg bullet ode irc"
```

**Note:** Some plugins may require additional configuration. See the troubleshooting section below.

## Output Location

After successful compilation, your binaries will be located in:

- **Release builds:** `/path/to/fteqw/engine/release/`
- **Debug builds:** `/path/to/fteqw/engine/debug/`

Main executable: `fteqw-sdl2` (or similar name based on target)

## Running the Engine

### First Time Setup

FTEQW requires game data to run. You need original Quake game files (pak0.pak, pak1.pak).

#### Option 1: Place Game Data in User Directory

Create the game directory structure:

```bash
mkdir -p ~/Library/Application\ Support/fteqw/id1
```

Copy your Quake game files:

```bash
cp /path/to/quake/id1/pak0.pak ~/Library/Application\ Support/fteqw/id1/
cp /path/to/quake/id1/pak1.pak ~/Library/Application\ Support/fteqw/id1/
```

#### Option 2: Run with Custom Base Directory

You can specify the game directory when launching:

```bash
./engine/release/fteqw-sdl2 -basedir /path/to/quake
```

### Launching the Engine

Navigate to the release directory and run:

```bash
cd /path/to/fteqw/engine/release
./fteqw-sdl2
```

Or from anywhere:

```bash
/path/to/fteqw/engine/release/fteqw-sdl2
```

### Useful Command-Line Options

```bash
# Run in windowed mode
./fteqw-sdl2 -window

# Specify a mod
./fteqw-sdl2 -game fortress

# Run dedicated server
./fteqw-sdl2 -dedicated

# Set resolution
./fteqw-sdl2 +set vid_width 1920 +set vid_height 1080

# Enable Vulkan renderer (if supported)
./fteqw-sdl2 +set vid_renderer vulkan

# Enable OpenGL renderer
./fteqw-sdl2 +set vid_renderer gl
```

## Testing Your Build

### Verify the Build

Launch the engine and type `version` in the console (Shift+ESC) to see build information:

```
FTEQW Version: git-XXX-XXXXXXX
Compiled: YYYY-MM-DD
Renderer: [your renderer]
```

### Load a Map

In the console, try loading a test map:

```
map start
```

Or if you have Quake data:

```
map e1m1
```

## Troubleshooting

### Issue: "SDL2 not found"

**Solution:** Ensure SDL2 is properly installed:

```bash
brew list sdl2
```

If not found, reinstall:

```bash
brew reinstall sdl2
```

Then rebuild with explicit paths:

```bash
gmake gl-rel FTE_TARGET=SDL2 SDL_CFLAGS="-I/opt/homebrew/include/SDL2" SDL_LIBS="-L/opt/homebrew/lib -lSDL2"
```

### Issue: "libpng not found" or PNG errors

**Solution:** 

```bash
gmake gl-rel FTE_TARGET=SDL2 PNG_CFLAGS="-I/opt/homebrew/include" PNG_LIBS="-L/opt/homebrew/lib -lpng"
```

### Issue: Plugin build failures

Some plugins may fail due to missing dependencies or incompatible versions.

**For FFMPEG plugin:**

```bash
gmake plugins-rel FTE_TARGET=SDL2 NATIVE_PLUGINS="ffmpeg" \
    AV_CFLAGS="-I/opt/homebrew/include" \
    AV_LIBS="-L/opt/homebrew/lib -lavformat -lavcodec -lavutil -lswscale"
```

**For Bullet Physics:**

Bullet may need to be built from source for the plugin. Consider using ODE instead:

```bash
gmake plugins-rel FTE_TARGET=SDL2 NATIVE_PLUGINS="ode"
```

### Issue: Architecture mismatch

If you encounter architecture errors, ensure all dependencies are ARM64:

```bash
brew list --versions
file /opt/homebrew/lib/libSDL2.dylib
```

Should show `arm64` not `x86_64`.

### Issue: Permission denied when running

Make the binary executable:

```bash
chmod +x /path/to/fteqw/engine/release/fteqw-sdl2
```

### Issue: macOS security warning

macOS may block unsigned applications. To resolve:

1. Go to System Preferences → Security & Privacy
2. Click "Allow Anyway" for FTEQW
3. Or run: `xattr -cr /path/to/fteqw/engine/release/fteqw-sdl2`

## Performance Optimization for M3 Mac

### Enable Metal Rendering (if available)

FTEQW supports various renderers. For best performance on Apple Silicon:

```bash
./fteqw-sdl2 +set vid_renderer gl
```

OpenGL is well-optimized on macOS and works excellently with Apple Silicon.

### Adjust Quality Settings

In-game, open console (Shift+ESC) and adjust:

```
seta r_shadow_quality 2        // Shadow quality (0-3)
seta r_texture_quality 1       // Texture filtering
seta vid_maxfps 144            // Cap framerate to your display
```

## Creating a Production Build

For a production-ready build optimized for distribution:

```bash
cd /path/to/fteqw/engine

# Clean previous builds
gmake clean

# Build optimized release
gmake gl-rel FTE_TARGET=SDL2 CPUOPTIMIZATIONS="-O3 -mcpu=apple-m3"

# Strip debug symbols to reduce size
strip release/fteqw-sdl2
```

## Next Steps: Adding Assets for Testing

Once your engine is built and running, you can start adding assets for testing and development.

### Quick Start with Included Test Content

FTEQW includes several manifest files in the `games/` directory that can automatically download test content:

```bash
# Run with Xonotic (free game) - will auto-download
./release/fteqw-sdl2 -manifest ../games/xonotic_85.fmf

# Run with Quake shareware - will auto-download
./release/fteqw-sdl2 -manifest ../games/quake-demo.fmf
```

### Using Included QuakeC Test Projects

The repository includes QuakeC source code for testing:

```bash
# Navigate to test mod source
cd ../../quakec/csqctest/src

# Compile with FTEQCC (after building it)
../../engine/release/fteqcc -basedir . -o ../csprogs.dat progs.src
```

Then run with the compiled mod:
```bash
./release/fteqw-sdl2 -game csqctest
```

### 1. Test Maps

Place custom `.bsp` files in your game directory:

**macOS:**
```
~/Library/Application Support/fteqw/maps/
```

**Linux:**
```
~/.fteqw/maps/
```

**Windows:**
```
%APPDATA%/fteqw/maps/
```

Or place them directly in your game folder:
```
id1/maps/      # For Quake
baseq3/maps/   # For Quake 3
```

### 2. Custom Models

FTEQW supports multiple model formats: `.mdl`, `.md2`, `.md3`, `.iqm`, `.bsp` models.

Place models in:
```
[GameDir]/progs/
[GameDir]/models/
```

### 3. Textures and Skins

Supported image formats: `.png`, `.jpg`, `.tga`, `.wal`, `.dds`, `.webp`

Place textures in:
```
[GameDir]/textures/
[GameDir]/skins/
[GameDir]/maps/[mapname]/  # For map-specific textures
```

### 4. Sound Files

Supported audio formats: `.wav`, `.ogg`, `.mp3`, `.flac`, `.opus`

Place sounds in:
```
[GameDir]/sound/
[GameDir]/music/           # For music tracks (track02.ogg, etc.)
```

### 5. Create a Test Mod

Create a new mod directory structure:

```bash
# Create mod folder
mkdir -p ~/Library/Application\ Support/fteqw/mytestmod/maps
mkdir -p ~/Library/Application\ Support/fteqw/mytestmod/progs
mkdir -p ~/Library/Application\ Support/fteqw/mytestmod/sound

# Create a simple config file
cat > ~/Library/Application\ Support/fteqw/mytestmod/config.cfg << EOF
// My Test Mod Configuration
set hostname "My Test Server"
set maxplayers 16
set fraglimit 30
set timelimit 20
EOF
```

Run your test mod:
```bash
./fteqw-sdl2 -game mytestmod
```

### 6. Using Manifest Files for Asset Management

Create a manifest file to manage asset downloads:

```bash
cat > mymod.fmf << EOF
FTEManifestVer 1
game mymod
name "My Test Mod"
basegame id1

// Auto-download test assets
package maps/testmap.bsp crc 0x12345678 mirror "https://example.com/testmap.bsp"
package progs/custom.dat crc 0x87654321 mirror "https://example.com/custom.dat"
EOF
```

Run with manifest:
```bash
./fteqw-sdl2 -manifest mymod.fmf
```

### 7. Testing with Built-in Tools

FTEQW includes powerful built-in tools accessible via console (Shift+ESC):

```
// Map editing and testing
r_editmaterials 1          // Material editor
r_editshaders 1            // Shader editor
edictview                  // Entity viewer/editor

// Particle system testing
r_particlesdesc effectinfo // View particle effects
particleeditor             // Particle editor (if available)

// Physics debugging
phys_debug 1               // Show physics colliders
r_showbboxes 1             // Show bounding boxes

// Performance monitoring
r_speeds 1                 // Rendering statistics
net_graph 1                // Network statistics
```

### 8. Recommended Test Assets

For comprehensive testing, consider adding:

- **Maps:** Various BSP maps from different eras and games
- **Models:** Test models in different formats (MDL, MD2, MD3, IQM)
- **Textures:** High-resolution textures to test scaling and filtering
- **Sounds:** Various audio formats to test codec support
- **Shaders:** Custom shader files to test material system

### Example: Setting Up a Complete Test Environment

```bash
# Create comprehensive test structure
TEST_DIR=~/Library/Application\ Support/fteqw/testlab

mkdir -p $TEST_DIR/{maps,models,sprites,sound,materials,scripts}

# Create test configuration
cat > $TEST_DIR/config.cfg << 'EOF'
// Test Lab Configuration
set hostname "FTEQW Test Lab"
set sv_maxspeed 320
set sv_gravity 800
set r_fullbright 0
set r_dynamic 1
set r_shadows 1
set s_volume 0.7
cfg_save
EOF

# Launch with test lab
./release/fteqw-sdl2 -game testlab
```

## Quick Reference Commands

```bash
# Full build from scratch
cd /path/to/fteqw/engine
gmake clean
gmake makelibs FTE_TARGET=SDL2
gmake gl-rel FTE_TARGET=SDL2
gmake qcc-rel
gmake plugins-rel FTE_TARGET=SDL2 NATIVE_PLUGINS="ffmpeg ode"

# Run the engine
./release/fteqw-sdl2

# Run with specific settings
./release/fteqw-sdl2 -window +set vid_width 1920 +set vid_height 1080
```

## Additional Resources

- **Building Documentation:** See `documentation/Building.md` for advanced build options
- **Dependencies:** See `documentation/Dependencies.md` for detailed dependency information
- **Quick Start:** See `documentation/QuickStart.md` for usage guide
- **Tools:** See `documentation/Tools.md` for information about included tools

## Getting Help

If you encounter issues:

- **Documentation:** Check the `documentation/` folder
- **Discord:** https://discord.gg/p2ag7x6Ca6
- **Matrix:** https://matrix.to/#/#fte:matrix.org
- **IRC:** irc.quakenet.org #fte
- **Bug Tracker:** https://github.com/fte-team/fteqw/issues

---

**License:** FTEQW is released under GPL v2. See LICENSE file for details.
