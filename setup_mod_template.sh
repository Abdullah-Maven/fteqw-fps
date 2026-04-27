#!/bin/bash
# setup_mod.sh - Create a new FTEQW mod directory structure
# Usage: ./setup_mod.sh <mod_name>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <mod_name>"
    echo ""
    echo "Example:"
    echo "  $0 mytestmod"
    echo ""
    echo "This will create a complete mod structure in ~/Games/FTEQW/<mod_name>"
    exit 1
fi

MOD_NAME="$1"
MOD_PATH="$HOME/Games/FTEQW/$MOD_NAME"

echo "Creating FTEQW mod: $MOD_NAME"
echo "Location: $MOD_PATH"
echo ""

# Create directory structure
mkdir -p "$MOD_PATH"/{maps,models/{player,weapons,items,monsters},textures/{base,custom},sounds/{weapons,ambient,voice},qc}

# Create placeholder files
cat > "$MOD_PATH/readme.txt" << EOF
$MOD_NAME
==========

A test mod for FTEQW.

Installation:
1. Copy this folder to your FTEQW directory
2. Run: fteqw-sdl2 -game $MOD_NAME

Contents:
- maps/     - BSP map files
- models/   - 3D models (IQM, MD3, etc.)
- textures/ - Image files (PNG, JPG, etc.)
- sounds/   - Audio files (OGG, WAV)
- qc/       - QuakeC source code

Tools needed:
- TrenchBroom for map editing
- Blender for 3D modeling
- Audacity for audio editing
- FTEQCC for QuakeC compilation

See ASSET_PIPELINE.md for detailed instructions.
EOF

cat > "$MOD_PATH/qc/defs.qh" << 'EOF'
// defs.qh - Definitions and prototypes for MYTESTMOD

// Function prototypes
void(void) empty_think;
void() player_setup;
void() ClientConnect;
void() ClientDisconnect;
void() StartFrame;

// Constants
#define MAX_PLAYERS 16
#define GAME_NAME "My Test Mod"
EOF

cat > "$MOD_PATH/qc/main.qc" << 'EOF'
// main.qc - Main entry point for MYTESTMOD

#include "defs.qh"

// Empty think function
void() empty_think =
{
    // Do nothing
};

// Setup player stats
void() player_setup =
{
    self.health = 100;
    self.max_health = 100;
    self.armortype = 0.3;
    self.armorvalue = 0;
    self.weapon = IT_SHOTGUN;
    self.ammo_shells = 10;
};

// Called every frame
void() StartFrame =
{
    // Game logic here
};

// Called when player joins
void() ClientConnect =
{
    bprint("^2Welcome to My Test Mod!\n");
    bprint("^7Type 'help' for commands.\n");
};

// Called when player leaves
void() ClientDisconnect =
{
    bprint("^3Player disconnected.\n");
};
EOF

cat > "$MOD_PATH/progs.src" << EOF
// progs.src - Source file list for FTEQCC
// Compile with: fteqcc -o progs.dat progs.src

defs.qh
qc/main.qc
EOF

cat > "$MOD_PATH/config.cfg" << 'EOF'
// config.cfg - Configuration for MYTESTMOD

// Server settings
set sv_maxclients 16
set sv_hostname "My Test Mod Server"

// Game settings
set fraglimit 30
set timelimit 20

// Player settings
set name "Player"
set color 0

// Video settings
set vid_width 1920
set vid_height 1080
set vid_fullscreen 0

// Audio settings
set volume 0.7
set bgmvolume 0.5
EOF

# Create a simple test script
cat > "$MOD_PATH/test.sh" << EOF
#!/bin/bash
# Quick test script for $MOD_NAME

echo "Starting FTEQW with $MOD_NAME..."
cd ~/Applications/FTEQW || cd /path/to/fteqw
./release/fteqw-sdl2 -game $MOD_NAME
EOF

chmod +x "$MOD_PATH/test.sh"

echo ""
echo "✓ Mod structure created successfully!"
echo ""
echo "Next steps:"
echo "  1. Add your assets to the appropriate folders"
echo "  2. Edit QC files in qc/ directory"
echo "  3. Compile QuakeC: fteqcc -o progs.dat progs.src"
echo "  4. Test: ./test.sh"
echo "  5. Or manually: fteqw-sdl2 -game $MOD_NAME"
echo ""
echo "For detailed instructions, see:"
echo "  - ASSET_PIPELINE.md - Complete asset guide"
echo "  - MACOS_M3_BUILD.md - Build instructions"
echo "  - documentation/Tools.md - Tool recommendations"
echo ""
echo "Happy modding! 🎮"
