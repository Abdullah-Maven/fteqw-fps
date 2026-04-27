/*
=============================================================================
Hello World Mod - Utility Functions
=============================================================================
*/

/*
============
ftos

Convert float to string
============
*/
string(float v) ftos;

/*
============
vtos

Convert vector to string  
============
*/
string(vector v) vtos;

/*
============
itoa

Convert integer to string
============
*/
string(int v) itoa;

/*
============
random

Return random float 0.0 to 1.0
============
*/
float() random;

/*
============
cvar

Get cvar value as float
============
*/
float(string var) cvar;

/*
============
cvar_string

Get cvar value as string
============
*/
string(string var) cvar_string;

/*
============
bprint

Broadcast print to all clients
============
*/
void(string s) bprint;

/*
============
sound

Play a sound
============
*/
void(entity e, float chan, string samp, float vol, float atten) sound;

/*
============
makevectors

Create vectors from angles
============
*/
void(vector o) makevectors;

/*
============
setmodel

Set entity model
============
*/
void(entity e, string m) setmodel;

/*
============
setsize

Set entity bounding box
============
*/
void(entity e, vector min, vector max) setsize;

/*
============
setorigin

Set entity origin
============
*/
void(entity e, vector o) setorigin;

/*
============
spawn

Create new entity
============
*/
entity() spawn;

/*
============
remove

Remove entity
============
*/
void(entity e) remove;

/*
============
tearoff

Create particle effect
============
*/
void(float count) tearoff;

/*
============
traceline

Trace line through world
============
*/
void(vector v1, vector v2, float nomonsters, entity forent) traceline;

/*
============
checkclient

Find client in view
============
*/
entity() checkclient;

/*
============
findradius

Find entities in radius
============
*/
entity(start, field fld, string match, float rad) findradius;

/*
============
nextent

Get next entity
============
*/
entity(entity e) nextent;
