# Asset Pipeline Guide for FTEQW

Complete guide to importing, creating, and using game assets in FTEQW. This guide covers models, textures, sounds, maps, and code for testing and modding on macOS Apple Silicon (M1/M2/M3).

## Table of Contents

1. [Supported Formats](#supported-formats)
2. [Directory Structure](#directory-structure)
3. [Models](#models)
4. [Textures and Images](#textures-and-images)
5. [Sounds and Music](#sounds-and-music)
6. [Maps](#maps)
7. [QuakeC Programming](#quakec-programming)
8. [Testing Your Assets](#testing-your-assets)
9. [Common Issues](#common-issues)

---

## Supported Formats

FTEQW supports an extensive range of formats:

### Models
| Format | Extension | Use Case | Tools |
|--------|-----------|----------|-------|
| **IQM** | `.iqm` | Modern skeletal animation | Blender + IQM exporter |
| **MD3** | `.md3` | Quake III Arena models | Blender + MD3 tools |
| **MD2** | `.md2` | Quake II models | Blender + MD2 tools |
| **MDL/MD5** | `.mdl`, `.md5mesh` | Quake/Hexen II models | Blender + various exporters |
| **OBJ** | `.obj` | Static meshes | Any 3D software |
| **SMD** | `.smd` | Source Engine models | Blender + Source tools |
| **PSK/PSA** | `.psk`, `.psa` | Unreal Engine models | UModel + converters |

### Textures
| Format | Extension | Notes |
|--------|-----------|-------|
| **PNG** | `.png` | Recommended, supports transparency |
| **JPEG** | `.jpg`, `.jpeg` | Good for photos, no transparency |
| **TGA** | `.tga` | Classic Quake format |
| **WAL** | `.wal` | Quake palette textures |
| **LMP** | `.lmp` | Quake lump textures |
| **DDS** | `.dds` | Compressed textures |
| **KTX** | `.ktx` | OpenGL compressed textures |
| **BMP** | `.bmp` | Uncompressed, large files |

### Sounds
| Format | Extension | Codec |
|--------|-----------|-------|
| **WAV** | `.wav` | Uncompressed PCM |
| **OGG Vorbis** | `.ogg` | Compressed, recommended |
| **FLAC** | `.flac` | Lossless compression |
| **MP3** | `.mp3` | Via FFmpeg plugin |
| **OPUS** | `.opus` | Voice chat |

### Maps
| Format | Extension | Compiler |
|--------|-----------|----------|
| **BSP** | `.bsp` | qbsp, TyrUtils, TrenchBroom |
| **FBSP** | `.bsp` | FTE-specific extensions |
| **MAP** | `.map` | Editor source files |

---

## Directory Structure

### Standard Mod Layout

```
mytestmod/
├── maps/           # .bsp map files
├── models/         # Model files
│   ├── player/     # Player models
│   ├── weapons/    # Weapon models
│   ├── items/      # Item models
│   └── monsters/   # Enemy models
├── textures/       # Texture files
│   ├── base/       # Base textures
│   └── custom/     # Custom textures
├── sounds/         # Sound files
│   ├── weapons/    # Weapon sounds
│   ├── ambient/    # Ambient sounds
│   └── voice/      # Voice lines
├── progs.dat       # Compiled QuakeC program
├── progs.src       # QuakeC source file list
├── config.cfg      # Mod configuration
└── readme.txt      # Mod documentation
```

### Quick Setup Script

```bash
#!/bin/bash
# setup_mod.sh - Create a new mod directory structure

MOD_NAME=$1

if [ -z "$MOD_NAME" ]; then
    echo "Usage: $0 <mod_name>"
    exit 1
fi

mkdir -p ~/Games/FTEQW/$MOD_NAME/{maps,models/{player,weapons,items,monsters},textures/{base,custom},sounds/{weapons,ambient,voice}}

echo "Created mod structure at ~/Games/FTEQW/$MOD_NAME"
echo ""
echo "Next steps:"
echo "1. Add your assets to the appropriate folders"
echo "2. Compile your QuakeC code (if any)"
echo "3. Run: ./fteqw-sdl2 -game $MOD_NAME"
```

---

## Models

### Using Blender with IQM Export (Recommended)

#### Step 1: Install Blender IQM Exporter

```bash
# Clone the IQM export script
cd ~/Applications
git clone https://github.com/leezer3/IQM-Blender.git
```

#### Step 2: Export from Blender

1. Model your character/object in Blender
2. Rig and animate (if needed)
3. File → Export → Inter-Quake Model (.iqm)
4. Export settings:
   - Scale: 1.0 (Quake units = Blender units)
   - Forward: -Y
   - Up: Z
   - Include animations: ✓ (if animated)

#### Step 3: Convert to MD3 (Alternative)

If you need MD3 format:

```bash
# Using md3tools (install via Homebrew or build from source)
brew install md3tools

# Or use online converters
# https://www.models-resource.com/tools/
```

### Model Testing

Create a simple test map to view your model:

```qc
// test_model.qc - Place model in world
void() test_model =
{
    self = spawn();
    self.classname = "info_testmodel";
    self.model = "models/player/mytest.iqm";
    self.modelindex = precache_model(self.model);
    self.solid = SOLID_NOT;
    setorigin(self, '0 0 0');
};
```

### Animation Tips

- IQM supports multiple animations in one file
- Name animations clearly: `idle`, `walk`, `run`, `shoot`, etc.
- Keep polygon count reasonable (< 2000 tris for characters)
- Use power-of-2 texture sizes (256x256, 512x512)

---

## Textures and Images

### Creating Textures

#### Using GIMP (Free)

1. Create new image (power-of-2 dimensions: 256x256, 512x512, etc.)
2. Design your texture
3. Export as PNG (File → Export As → texture.png)
4. For transparency, add alpha channel (Layer → Transparency → Add Alpha Channel)

#### Using Photoshop

1. Create new document (power-of-2 dimensions)
2. Design texture
3. File → Export → Save for Web (Legacy)
4. Choose PNG-24 with transparency if needed

### Texture Naming Conventions

```
base_floor_01.png      # Descriptive name
weapon_rocket_skin.png # Specific use
enemy_grunt_face.png   # Character-specific
ui_button_hover.png    # UI element
```

### Installing Textures

Place textures in your mod folder:

```bash
# Simple texture replacement
cp my_texture.png ~/Games/FTEQW/mytestmod/textures/base/

# Or in pak file for distribution
zip -r mytestmod.pak maps/ models/ textures/ sounds/
mv mytestmod.pak ~/Games/FTEQW/mytestmod/
```

### Texture Shaders

FTEQW supports advanced shader definitions:

```glsl
// shaders/test.shader
models/player/mytest {
    map models/player/mytest_skin.png
    rgbgen vertex
    tcgen environment
}
```

---

## Sounds and Music

### Recording and Editing

#### Using Audacity (Free)

1. Record or import audio
2. Edit and clean up (Effects → Noise Reduction, etc.)
3. Normalize (Effects → Normalize)
4. Export:
   - WAV for uncompressed
   - OGG for compressed (Quality 5-7 recommended)

### Sound Format Conversion

```bash
# Using ffmpeg (install via Homebrew)
brew install ffmpeg

# Convert WAV to OGG
ffmpeg -i sound.wav -q:a 6 sound.ogg

# Convert MP3 to OGG
ffmpeg -i music.mp3 -q:a 6 music.ogg

# Change sample rate (Quake uses 22050 Hz or 44100 Hz)
ffmpeg -i input.wav -ar 22050 output.wav
```

### Sound Testing

Create a test entity that plays sound:

```qc
void() test_sound =
{
    self = spawn();
    self.classname = "info_testsound";
    self.noise = "sounds/test.ogg";
    precache_sound(self.noise);
    self.think = SUB_FireTargets;
    self.nextthink = time + 1.0;
};
```

### Volume Levels

- **Weapons:** -3dB to 0dB
- **Ambient:** -12dB to -6dB
- **Voice:** -6dB to -3dB
- **Music:** -6dB to 0dB

Use normalization to ensure consistent levels.

---

## Maps

### Setting Up TrenchBroom (Recommended Map Editor)

#### Installation on macOS

```bash
# Download from https://trenchbroom.github.io/
# Or use Homebrew Cask
brew install --cask trenchbroom
```

#### Configuration for FTEQW

1. Open TrenchBroom
2. Preferences → Game Types → Add Custom Game Type
3. Configure:
   - Name: FTEQW
   - Icon: quake.ico
   - Base Path: ~/Games/FTEQW
   - Texture directories: id1/textures, mytestmod/textures

### Basic Map Creation

1. **New Map:** File → New Map → Choose FTEQW game type
2. **Build Brushes:** Use cube, wedge, cylinder tools
3. **Apply Textures:** Drag textures from browser onto brushes
4. **Add Entities:** Right-click → Create Entity
   - `info_player_start` - Player spawn
   - `light` - Lighting
   - `func_door` - Moving door
5. **Compile:** File → Run Map Compiler

### Map Compilation Settings

For FTEQW, use these compiler settings:

```
qbsp: 
  -skipdetail
  -onlyents
  
light:
  -extra
  -sunlight 150 100 50
  -sunlight_angle 45
  
vis:
  -level 4
```

### Testing Maps

```bash
# Run map directly
./release/fteqw-sdl2 -game mytestmod +map test_map

# Or from console in-game
map test_map
```

### Common Map Entities

```
info_player_start     - Player spawn point
info_player_deathmatch - DM spawn point
light                 - Static light
light_spot            - Spot light
func_door             - Sliding door
func_button           - Push button
trigger_once          - One-time trigger
monster_*             - Various enemies
item_*                - Pickups
weapon_*              - Weapons
ammo_*                - Ammo pickups
```

---

## QuakeC Programming

### Setting Up FTEQCC

The FTEQW QuakeC compiler is included. Build it:

```bash
cd engine
gmake qcc-rel
```

### Basic Mod Structure

```
mytestmod/
├── qc/
│   ├── main.qc        # Main entry point
│   ├── defs.qh        # Definitions and prototypes
│   ├── player.qc      # Player code
│   └── weapons.qc     # Weapon code
├── progs.src          # Source file list
└── progs.dat          # Compiled output (generated)
```

### Example: Hello World Mod

**defs.qh:**
```qc
// defs.qh - Definitions
void(void) empty_think;
void() player_setup;
```

**main.qc:**
```qc
// main.qc - Main entry point

#include "defs.qh"

void() empty_think =
{
    // Do nothing
};

void() player_setup =
{
    self.health = 100;
    self.max_health = 100;
    self.armortype = 0.3;
    self.armorvalue = 0;
    self.weapon = IT_SHOTGUN;
    self.ammo_shells = 10;
};

void() StartFrame =
{
    // Called every frame
};

void() ClientConnect =
{
    // Called when player joins
    bprint("Welcome to My Test Mod!\n");
};

void() ClientDisconnect =
{
    // Called when player leaves
};
```

**progs.src:**
```
defs.qh
main.qc
```

### Compiling QuakeC

```bash
# Compile your mod
cd ~/Games/FTEQW/mytestmod
/path/to/fteqcc -o progs.dat progs.src

# Or use the build script
../../../build_qc.sh mytestmod
```

### Testing QuakeC Code

Use FTEQW's built-in debugging:

```bash
# Run with QuakeC debugger
./release/fteqw-sdl2 -game mytestmod -qcdebug

# Console commands for debugging:
# pr_dump <entity> - Print entity state
# pr_edict <num> - Show entity info
# pr_profile - Profile QuakeC performance
```

---

## Testing Your Assets

### Automated Test Script

```bash
#!/bin/bash
# test_assets.sh - Validate mod assets

MOD_PATH=$1

if [ -z "$MOD_PATH" ]; then
    MOD_PATH=~/Games/FTEQW/mytestmod
fi

echo "Testing assets in: $MOD_PATH"
echo ""

# Check required files
check_file() {
    if [ -f "$1" ]; then
        echo "✓ $1 exists"
    else
        echo "✗ $1 missing"
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo "✓ $1/ directory exists"
    else
        echo "✗ $1/ directory missing"
    fi
}

# Check directories
check_dir "$MOD_PATH/maps"
check_dir "$MOD_PATH/models"
check_dir "$MOD_PATH/textures"
check_dir "$MOD_PATH/sounds"

# Check for common issues
echo ""
echo "Checking for potential issues..."

# Large files (> 50MB)
find "$MOD_PATH" -type f -size +50M 2>/dev/null | while read file; do
    echo "⚠ Large file: $file"
done

# Non-power-of-2 textures
find "$MOD_PATH/textures" -name "*.png" -o -name "*.jpg" 2>/dev/null | while read file; do
    dims=$(sips -g pixelWidth -g pixelHeight "$file" 2>/dev/null | awk '/pixelWidth|pixelHeight/ {print $2}')
    # Check if power of 2 (simplified check)
    echo "Texture: $file ($dims)"
done

echo ""
echo "Test complete!"
```

### Visual Testing Checklist

- [ ] Models display correctly
- [ ] Animations play smoothly
- [ ] Textures appear without stretching
- [ ] Sounds play at correct volume
- [ ] Map lighting looks good
- [ ] No console errors
- [ ] Performance is acceptable (60+ FPS)

### Performance Testing

```bash
# Run with performance stats
./release/fteqw-sdl2 -game mytestmod +set demo 1

# Console commands:
# r_speeds 1          - Show rendering stats
# cl_fps 1            - Show FPS
# sys_ticrate 0.01667 - Lock to 60 FPS
```

---

## Common Issues

### Models Not Showing

**Problem:** Model appears as missing/error model

**Solutions:**
1. Check file path is correct (case-sensitive!)
2. Verify model format is supported
3. Check `modelindex` is set after `precache_model()`
4. Ensure model isn't scaled to 0

### Textures Not Loading

**Problem:** Purple/black checkerboard or missing texture

**Solutions:**
1. Verify texture file exists in correct location
2. Check filename matches exactly (case-sensitive)
3. Ensure texture dimensions are power-of-2
4. Try converting to PNG format

### Sounds Not Playing

**Problem:** No sound or error message

**Solutions:**
1. Check sound file format (use OGG or WAV)
2. Verify `precache_sound()` is called
3. Check volume settings (`volume`, `snd_volume`)
4. Ensure audio backend is working (SDL2 audio)

### Map Won't Load

**Problem:** Error loading BSP file

**Solutions:**
1. Recompile map with latest tools
2. Check for map compilation errors
3. Verify BSP is in `maps/` folder
4. Try running `vid_restart` in console

### QuakeC Compilation Errors

**Problem:** fteqcc reports errors

**Solutions:**
1. Check syntax in reported line
2. Verify all functions are defined
3. Ensure includes are correct
4. Use `-verbose` flag for more info

### Performance Issues

**Problem:** Low FPS or stuttering

**Solutions:**
1. Reduce texture sizes
2. Lower polygon count on models
3. Simplify map geometry
4. Reduce number of dynamic lights
5. Check `r_speeds 1` for bottlenecks

---

## Quick Reference

### Essential Console Commands

```
map <name>              - Load map
game <modname>          - Switch to mod
reload                  - Reload current level
bind <key> <cmd>        - Bind key to command
cl_maxfps 60            - Limit FPS
r_fullbright 1          - Fullbright mode (debug)
noclip                  - Fly through walls
god                     - God mode
notarget                - Enemies ignore you
impulse 9               - Give all weapons
```

### Useful CVars for Development

```
developer 1             - Verbose output
log_file 1              - Enable logging
sv_cheats 1             - Enable cheat commands
cl_showfps 1            - Show FPS
r_showtris 1            - Show wireframe
pmove_fixed 0           - Variable timestep physics
```

### File Size Guidelines

| Asset Type | Recommended Max | Absolute Max |
|------------|----------------|--------------|
| Character Model | 500 KB | 2 MB |
| Weapon Model | 200 KB | 1 MB |
| Texture (512x512) | 256 KB | 1 MB |
| Sound Effect | 500 KB | 2 MB |
| Music Track | 5 MB | 20 MB |
| Map BSP | 10 MB | 50 MB |

---

## Resources

### Tools

- **Blender:** https://www.blender.org/ - 3D modeling
- **TrenchBroom:** https://trenchbroom.github.io/ - Map editor
- **Audacity:** https://www.audacityteam.org/ - Audio editing
- **GIMP:** https://www.gimp.org/ - Image editing
- **FFmpeg:** https://ffmpeg.org/ - Media conversion

### Documentation

- **FTEQW Specs:** `/workspace/specs/` folder
- **QuakeC Reference:** https://quakewiki.net/archives/docs/qc/
- **BSP Format:** https://www.gamers.org/dEngine/quake/QBSP/

### Communities

- **InsideQC Forums:** https://forums.insideqc.com/
- **Func_msgboard:** https://www.quakeone.com/
- **Nexus Mods:** https://www.nexusmods.com/quakemods/

---

*Last Updated: 2025*
*Version: FTEQW Asset Pipeline Guide v1.0*
