/*
=============================================================================
Hello World Mod - Main QuakeC Program
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
    
    bprint("=====================================\n");
    bprint("Welcome to Hello World Mod!\n");
    bprint("Created with FTEQW Game Engine\n");
    bprint("=====================================\n");
    bprint("\n");
    bprint("This mod demonstrates:\n");
    bprint("- Custom entities\n");
    bprint("- Player modifications\n");
    bprint("- Basic QuakeC programming\n");
    bprint("\n");
    
    // Precache models and sounds
    // precache_model("progs/hello.mdl");  // Add your model here
    // precache_sound("misc/talk.wav");
    // precache_sound("player/jump.wav");
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
    
    // Example: Check for players and update score
    local entity client;
    client = find(world, classname, "player");
    while (client != world)
    {
        // Custom per-frame logic for each player
        client = find(client, classname, "player");
    }
};

/*
============
EndFrame

Called at end of server frame
============
*/
void() EndFrame =
{
    // End of frame cleanup
};

/*
============
ClientKill

Called when player suicides
============
*/
void() ClientKill =
{
    self.health = 0;
    bprint(self.netname, " committed suicide.\n");
};

/*
============
SetChangeParms

Save parms when changing levels
============
*/
void() SetChangeParms =
{
    // Save player state
    self.parm1 = self.health;
    self.parm2 = self.armorvalue;
};

/*
============
SetNewParms

Load parms after changing levels
============
*/
void() SetNewParms =
{
    // Restore player state
    self.health = self.parm1;
    self.armorvalue = self.parm2;
};

/*
============
PlayerPreThink

Called before player movement
============
*/
void() PlayerPreThink =
{
    // Pre-movement processing
};

/*
============
PlayerPostThink

Called after player movement
============
*/
void() PlayerPostThink =
{
    // Post-movement processing
    
    // Check for jump button
    if (self.button2 && (self.flags & FL_ONGROUND))
    {
        // Could implement double jump or other special moves here
    }
};
