# Hello World Mod for FTEQW

A complete "Hello World" mod template demonstrating the basics of creating a QuakeC modification for FTEQW.

## Overview

This mod demonstrates:
- Basic QuakeC programming
- Custom entities and functions
- Map integration
- Asset organization
- Building and testing your mod

## Quick Start

### Prerequisites

1. FTEQW engine built (see [MACOS_M3_BUILD.md](../../MACOS_M3_BUILD.md))
2. FTEQCC (QuakeC compiler) - included in build
3. Base Quake content or compatible game data

### Installation

```bash
# Copy the mod to your game directory
cp -r hello_world_mod ~/Library/Application\ Support/fteqw/id1/

# Or on Linux:
cp -r hello_world_mod ~/.fteqw/id1/

# Or on Windows:
copy /r hello_world_mod %APPDATA%\fteqw\id1\
```

### Running the Mod

```bash
# Launch FTEQW with the mod
./fteqw -game hello_world_mod

# Or from console after launching:
game hello_world_mod
map start
```

## File Structure

```
hello_world_mod/
├── README.md              # This file
├── progs.dat             # Compiled QuakeC bytecode (generated)
├── src/                  # QuakeC source files
│   ├── defs.qc           # Type definitions and constants
│   ├── main.qc           # Main entry point
│   ├── player.qc         # Player controls
│   ├── hello.qc          # Hello World example
│   └── util.qc           # Utility functions
├── maps/                 # Map files
│   ├── start.bsp         # Starting map
│   └── readme.txt        # Map credits
├── models/               # 3D models (.mdl, .md2, .md3, .iqm)
│   └── placeholder.txt
├── textures/             # Texture files (.png, .jpg, .wal)
│   └── placeholder.txt
├── sounds/               # Audio files (.wav, .ogg)
│   └── placeholder.txt
└── config.cfg            # Mod configuration
```

## Code Examples

### Basic Entity (hello.qc)

```quakec
/*
=============================================================================
Hello World Entity Example
Demonstrates basic entity creation and thinking functions
=============================================================================
*/

// Define custom fields for our entity
.entity hello_target;
.float hello_count;
.string hello_message;

/*
============
Hello_Think

Called every frame to update the entity
============
*/
void() Hello_Think =
{
    self.nextthink = time + 0.5; // Call again in 0.5 seconds
    
    // Rotate the entity
    self.angles_y = self.angles_y + 10;
    
    // Count up and display message
    self.hello_count = self.hello_count + 1;
    
    if (self.hello_count > 10)
    {
        bprint("Hello World! Count: ", ftos(self.hello_count), "\n");
        self.hello_count = 0;
    }
};

/*
============
Hello_Touch

Called when something touches this entity
============
*/
void(entity other) Hello_Touch =
{
    if (other.classname == "player")
    {
        bprint(other.netname, " touched the hello entity!\n");
        
        // Play a sound
        sound(self, CHAN_VOICE, "misc/talk.wav", 1, ATTN_NORM);
    }
};

/*
============
Spawn_Hello

Spawn function called from map or code
============
*/
void() Spawn_Hello =
{
    makevectors(self.origin);
    
    // Set up the entity
    setmodel(self, "progs/hello.mdl");
    setsize(self, '-8 -8 -8', '8 8 8');
    
    // Initialize custom fields
    self.hello_count = 0;
    self.hello_message = "Hello World!";
    
    // Set up thinking function
    self.think = Hello_Think;
    self.nextthink = time + 1.0;
    
    // Set up touch function
    self.touch = Hello_Touch;
    
    // Make it solid
    self.solid = SOLID_BBOX;
    self.movetype = MOVETYPE_BOUNCE;
    
    bprint("Hello World entity spawned!\n");
};
```

### Player Modification (player.qc)

```quakec
/*
=============================================================================
Player Modifications
Extend or modify player behavior
=============================================================================
*/

/*
============
Player_JumpModified

Override default jump to add special effects
============
*/
void() Player_JumpModified =
{
    // Check if player is on ground
    if (self.flags & FL_ONGROUND)
    {
        // Super jump!
        self.velocity_z = 400; // Higher than normal 270
        
        // Add visual effect
        tearoff(10); // Particle effect
        
        // Play sound
        sound(self, CHAN_VOICE, "player/jump.wav", 1, ATTN_NORM);
        
        bprint(self.netname, " performs a super jump!\n");
    }
};
```

### Main Entry Point (main.qc)

```quakec
/*
=============================================================================
Main QuakeC Program
Entry point and world initialization
=============================================================================
*/

#include "defs.qc"
#include "util.qc"
#include "hello.qc"
#include "player.qc"

/*
============
worldspawn

Called when the map starts
============
*/
void() worldspawn =
{
    // Initialize world
    cvar_set("sv_gravity", "800");
    cvar_set("sv_maxvelocity", "1000");
    
    bprint("Welcome to Hello World Mod!\n");
    bprint("Created with FTEQW Game Engine\n");
    
    // Precache models and sounds
    precache_model("progs/hello.mdl");
    precache_sound("misc/talk.wav");
    precache_sound("player/jump.wav");
};

/*
============
ClientConnect

Called when a player connects
============
*/
void() ClientConnect =
{
    bprint(self.netname, " joined the game!\n");
};

/*
============
ClientDisconnect

Called when a player disconnects
============
*/
void() ClientDisconnect =
{
    bprint(self.netname, " left the game.\n");
};

/*
============
StartFrame

Called every server frame
============
*/
void() StartFrame =
{
    // Global updates every frame
    // Add custom game logic here
};
```

## Building the Mod

### Compile QuakeC

```bash
# Navigate to mod directory
cd hello_world_mod

# Compile with FTEQCC
../../engine/release/fteqcc -o progs.dat src/main.qc

# Or use the build script
../../build_qc.sh src/main.qc
```

### Expected Output

```
FTEQCC Compiler v1.0
Compiling src/main.qc...
Compiling src/defs.qc...
Compiling src/hello.qc...
Compiling src/player.qc...
Compiling src/util.qc...

Output: progs.dat
Entities: 15
Functions: 8
Globals: 24

Compilation successful!
```

## Testing Your Mod

### Console Commands

Once in-game, use these commands:

```
// List all entities
entlist

// Spawn a hello entity at crosshair
entcreate hello

// Teleport to entity
entteleport <entity_number>

// Remove entity
entremove <entity_number>

// View entity info
entinfo <entity_number>
```

### Debugging

Enable debug mode:

```bash
./fteqw -game hello_world_mod -condebug
```

Check console output for errors and messages.

## Extending the Mod

### Adding New Entities

1. Create new `.qc` file in `src/`
2. Define spawn function
3. Include in `main.qc`
4. Recompile

### Adding Custom Weapons

```quakec
void() W_FireHelloGun =
{
    // Create projectile
    local entity bolt;
    bolt = spawn();
    bolt.owner = self;
    bolt.origin = self.origin + '0 0 16';
    
    // Set velocity based on player view
    makevectors(self.v_angle);
    bolt.velocity = v_forward * 1000;
    
    // Set up thinking
    bolt.think = Hello_Bolt_Think;
    bolt.nextthink = time + 0.1;
};
```

### Creating Maps

Use a map editor like:
- **TrenchBroom** (Recommended)
- **QuArK**
- **J.A.C.K.**

Export as `.bsp` and place in `maps/` directory.

## Common Issues

### Issue: "Progs.dat not found"
**Solution**: Ensure you compiled QuakeC and progs.dat is in mod root

### Issue: "Unknown function" errors
**Solution**: Check that all files are included in main.qc

### Issue: Entities don't appear
**Solution**: Verify model paths and precache calls

### Issue: Crash on spawn
**Solution**: Check entity bounds with `setsize()`

## Next Steps

Now that you've created a Hello World mod:

1. **Study existing mods** in `quakec/` directory
2. **Experiment** with different entity types
3. **Create custom maps** with your entities
4. **Add custom models** and textures
5. **Implement game modes** (CTF, deathmatch, etc.)
6. **Share your mod** with the community!

## Resources

- [FTEQW Documentation](../../README.md)
- [QuakeC Reference](../../documentation/)
- [Asset Pipeline Guide](../../ASSET_PIPELINE.md)
- [Community Forums](https://fteqw.com)

## License

This template is provided as-is for educational purposes.
Your mods can be licensed however you choose.

---

Happy modding! 🎮
