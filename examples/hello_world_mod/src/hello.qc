/*
=============================================================================
Hello World Mod - Hello Entity Example
Demonstrates basic entity creation and thinking functions
=============================================================================
*/

// Define custom fields for our entity (already in defs.qc)
// .entity hello_target;
// .float hello_count;
// .string hello_message;

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
        
        // Play a sound (if available)
        // sound(self, CHAN_VOICE, "misc/talk.wav", 1, ATTN_NORM);
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
    // setmodel(self, "progs/hello.mdl");  // Uncomment when you have a model
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

/*
============
info_hello

Map entity spawn point
============
*/
void() info_hello =
{
    remove(self);
    self = spawn();
    self.classname = "hello_entity";
    self.spawn = Spawn_Hello;
    self.spawn();
};
