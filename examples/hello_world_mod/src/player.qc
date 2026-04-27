/*
=============================================================================
Hello World Mod - Player Modifications
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
        
        // Play sound (if available)
        // sound(self, CHAN_VOICE, "player/jump.wav", 1, ATTN_NORM);
        
        bprint(self.netname, " performs a super jump!\n");
    }
};

/*
============
Player_Touch

Called when player touches something
============
*/
void(entity other) Player_Touch =
{
    // Check for hello entity
    if (other.classname == "hello_entity")
    {
        bprint(self.netname, " touched the hello entity!\n");
    }
};

/*
============
ClientConnect

Initialize player on connect
============
*/
void() ClientConnect =
{
    bprint(self.netname, " joined the Hello World mod!\n");
    
    // Set player properties
    self.health = 100;
    self.armorvalue = 0;
};

/*
============
ClientDisconnect

Clean up when player disconnects
============
*/
void() ClientDisconnect =
{
    bprint(self.netname, " left the game.\n");
};

/*
============
PutClientInServer

Spawn player into the world
============
*/
void() PutClientInServer =
{
    // Find spawn point
    local entity spot;
    spot = find(world, classname, "info_player_start");
    
    if (spot != world)
    {
        setorigin(self, spot.origin + '0 0 16');
        self.angles = spot.angles;
    }
    
    // Initialize player state
    self.health = 100;
    self.velocity = '0 0 0';
    self.flags = FL_CLIENT | FL_ONGROUND;
    
    bprint(self.netname, " spawned into the world!\n");
};
