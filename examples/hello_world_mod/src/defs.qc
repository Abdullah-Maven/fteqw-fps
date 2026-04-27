/*
=============================================================================
Hello World Mod - Type Definitions and Constants
=============================================================================
*/

// Entity flags
#define FL_ONGROUND             1
#define FL_CLIENT               256
#define FL_MONSTER              512

// Movement types
#define MOVETYPE_NONE           0
#define MOVETYPE_BOUNCE         4
#define MOVETYPE_WALK           5

// Solid types
#define SOLID_NOT               0
#define SOLID_BBOX              2
#define SOLID_TRIGGER           3

// Channels
#define CHAN_VOICE              0
#define CHAN_WEAPON             1
#define CHAN_BODY               2

// Attenuation
#define ATTN_NORM               1
#define ATTN_IDLE               2
#define ATTN_STATIC             3

// Spawn flags
#define SF_NOTSINGLE            1
#define SF_NOTDEATHMATCH        2
#define SF_NOTCOOP              4

// Player flags  
#define PLAYER_FLAG_TEAM        1

// Custom entity fields
.entity hello_target;
.float hello_count;
.string hello_message;
.vector hello_origin;
