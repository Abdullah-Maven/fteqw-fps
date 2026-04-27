# FTEQW Sample Data & Test Assets Guide

This guide explains how to download, install, and use sample data and test assets with the FTEQW engine.

## Quick Start

### Option 1: Automated Download (Recommended)

```bash
# Check what's available
./download_sample_data.sh status

# Download Quake Shareware (required base game)
./download_sample_data.sh quake

# Download all available games
./download_sample_data.sh all
```

### Option 2: Manual Download Using Engine

After building the engine:

```bash
cd engine/release

# Download Quake Shareware
./fteqw-sdl2 -manifest ../../games/quake-demo.fmf -quit

# Download Xonotic 0.8.5
./fteqw-sdl2 -manifest ../../games/xonotic_85.fmf -quit

# Download Fortress One
./fteqw-sdl2 -manifest ../../games/fortressone.fmf -quit

# Download Hexen II Demo
./fteqw-sdl2 -manifest ../../games/hexen2-demo.fmf -quit
```

## Available Game Content

### 1. Quake Shareware (`quake-demo.fmf`)
- **Size**: ~6 MB
- **Content**: Episode 1 (7 maps), basic weapons, monsters
- **Maps**: start, e1m1-e1m7
- **Perfect for**: Testing core engine functionality

### 2. Xonotic 0.8.5 (`xonotic_85.fmf`)
- **Size**: ~400 MB
- **Content**: Full modern arena FPS game
- **Features**: Advanced weapons, vehicles, multiple game modes
- **Perfect for**: Testing modern features, multiplayer, performance

### 3. Fortress One (`fortressone.fmf`)
- **Size**: ~50 MB
- **Content**: Team-based class combat game
- **Features**: Classes, bases, team gameplay
- **Perfect for**: Testing team mechanics, class systems

### 4. Hexen II Demo (`hexen2-demo.fmf`)
- **Size**: ~20 MB
- **Content**: Fantasy RPG action demo
- **Features**: Magic system, different character classes
- **Perfect for**: Testing RPG elements, fantasy setting

## Included Test Assets

The repository includes a `test_assets/` directory with:

### Maps (`test_assets/maps/`)
- **test_simple.map**: Basic room with lighting and one monster
- Use as template for creating custom maps

### Configurations (`test_assets/configs/`)
- **test_config.cfg**: Optimized settings for testing
  - Developer mode enabled
  - Debug overlays active
  - Performance-friendly settings
  - Useful key bindings

### Directory Structure for Custom Assets
```
test_assets/
├── maps/          # .map files (source) and .bsp files (compiled)
├── models/        # .mdl, .md2, .md3, .iqm model files
├── textures/      # .lmp, .png, .jpg texture files
├── sounds/        # .wav sound files
└── configs/       # .cfg configuration files
```

## Running Games

### With Downloaded Content

```bash
# Run Quake
./engine/release/fteqw-sdl2 -game quake

# Run Xonotic
./engine/release/fteqw-sdl2 -game xonotic

# Run Fortress One
./engine/release/fteqw-sdl2 -game fortressone

# Run Hexen II
./engine/release/fteqw-sdl2 -game hexen2
```

### With Test Assets

```bash
# Load test configuration
./engine/release/fteqw-sdl2 -game quake +exec test_config.cfg

# Load specific map
./engine/release/fteqw-sdl2 -game quake +map start

# Run in dedicated server mode
./engine/release/fteqw-sdl2 -dedicated -game quake +maxplayers 16 +map start
```

## Creating Custom Test Content

### Step 1: Set Up Mod Directory

```bash
mkdir -p mymod/id1/maps
mkdir -p mymod/id1/models
mkdir -p mymod/id1/sounds
mkdir -p mymod/id1/textures
```

### Step 2: Add Your Assets

Copy your custom files into the appropriate directories:
- Maps → `mymod/id1/maps/`
- Models → `mymod/id1/models/`
- Sounds → `mymod/id1/sounds/`
- Textures → `mymod/id1/textures/`

### Step 3: Create progs.dat (Optional)

If you have custom QuakeC code:

```bash
cd quakec/basemod
../engine/release/fteqcc -o ../../mymod/id1/progs.dat progs.src
```

### Step 4: Run Your Mod

```bash
./engine/release/fteqw-sdl2 -game mymod
```

## Using Manifest Files

Manifest files (`.fmf`) define what content to download and how to set it up.

### Example Manifest Structure

```
FTEManifestVer 1
game quake
name Quake

// Download from URL with checksum verification
archivedpackage id1/pak0.pak 0x4f069cac id1/pak0.pak https://example.com/quake.zip
```

### Creating Your Own Manifest

1. Create a file `mygame.fmf` in `games/` directory
2. Define game name and base directory
3. List packages to download with checksums
4. Run with: `./fteqw-sdl2 -manifest mygame.fmf`

## Troubleshooting

### Issue: "Game not found"
**Solution**: Ensure you've downloaded the content first:
```bash
./download_sample_data.sh quake
```

### Issue: "Missing pak0.pak"
**Solution**: The manifest download may have failed. Try again:
```bash
./engine/release/fteqw-sdl2 -manifest games/quake-demo.fmf -quit
```

### Issue: Map won't load
**Solutions**:
- Check map file is in correct directory: `quake/id1/maps/`
- Ensure map is compiled (.bsp format, not .map)
- Use full path: `map maps/mymap.bsp`

### Issue: Low performance
**Solutions**:
- Lower resolution: `vid_width 1280` `vid_height 720`
- Disable shadows: `r_shadow_realtime_world 0`
- Reduce texture quality: `gl_texturemode GL_LINEAR`

## Console Commands for Testing

```
// Map commands
map <mapname>           // Load a map
changelevel <mapname>   // Change to next level
restart                 // Restart current map

// Entity spawning
spawn <classname>       // Spawn an entity
impulse 10              // Give all weapons (Quake)

// Debug commands
noclip                  // Fly through walls
god                     // God mode
notarget                // Enemies ignore you
showfps 1               // Show FPS counter
r_showtris 1            // Show wireframe

// Recording
record <demoname>       // Start recording demo
stoprecord              // Stop recording
playdemo <demoname>     // Play recorded demo

// Network
connect localhost       // Connect to local server
status                  // Show server status
```

## Recommended Testing Workflow

1. **Build Engine**
   ```bash
   cd engine
   gmake makelibs FTE_TARGET=SDL2
   gmake gl-rel FTE_TARGET=SDL2
   ```

2. **Download Base Content**
   ```bash
   ./download_sample_data.sh quake
   ```

3. **Test Basic Functionality**
   ```bash
   ./engine/release/fteqw-sdl2 -game quake +map start
   ```

4. **Add Custom Content**
   - Copy assets to `test_assets/` or create new mod directory
   - Test with: `-game mymod`

5. **Run Automated Tests**
   ```bash
   cd tests
   ./run_tests.sh
   ```

## Additional Resources

- **Quake Mapping Tutorials**: https://www.quakewiki.net/archives/tutorial/
- **QuakeC Programming**: See `quakec/` directory examples
- **FTE Extensions**: https://fte.triptohell.info/
- **Community Mods**: https://www.quaddicted.com/

## Support

For issues with downloading or using sample data:
1. Check `MACOS_M3_BUILD.md` for build troubleshooting
2. Review engine logs in `stderr.txt` or console output
3. Verify checksums match in manifest files
4. Ensure stable internet connection for downloads
