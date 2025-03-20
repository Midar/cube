// one big bad include file for the whole engine... nasty!

#import <ObjFW/ObjFW.h>

#define gamma gamma__
#include <SDL2/SDL.h>
#undef gamma

#include "tools.h"

#define _MAXDEFSTR 260

@class Entity;
@class DynamicEntity;

@interface Cube: OFObject <OFApplicationDelegate>
@property (class, readonly, nonatomic) Cube *sharedInstance;
@property (readonly, nonatomic) SDL_Window *window;
@property (readonly, nonatomic) OFIRI *gameDataIRI, *userDataIRI;
@property (nonatomic) bool repeatsKeys;
@property (nonatomic) int framesInMap;
@end

// block types, order matters!
enum {
	SOLID = 0, // entirely solid cube [only specifies wtex]
	CORNER,    // half full corner of a wall
	FHF,       // floor heightfield using neighbour vdelta values
	CHF,       // idem ceiling
	SPACE,     // entirely empty cube
	SEMISOLID, // generated by mipmapping
	MAXTYPE
};

struct sqr {
	uchar type;             // one of the above
	char floor, ceil;       // height, in cubes
	uchar wtex, ftex, ctex; // wall/floor/ceil texture ids
	uchar r, g, b;          // light value at upper left vertex
	uchar vdelta;           // vertex delta, used for heightfield cubes
	char defer; // used in mipmapping, when true this cube is not a perfect
	            // mip
	char occluded; // true when occluded
	uchar utex;    // upper wall tex id
	uchar tag;     // used by triggers
};

// hardcoded texture numbers
enum {
	DEFAULT_SKY = 0,
	DEFAULT_LIQUID,
	DEFAULT_WALL,
	DEFAULT_FLOOR,
	DEFAULT_CEIL
};

// static entity types
enum {
	NOTUSED = 0, // entity slot not in use in map
	LIGHT,       // lightsource, attr1 = radius, attr2 = intensity
	PLAYERSTART, // attr1 = angle
	I_SHELLS,
	I_BULLETS,
	I_ROCKETS,
	I_ROUNDS,
	I_HEALTH,
	I_BOOST,
	I_GREENARMOUR,
	I_YELLOWARMOUR,
	I_QUAD,
	TELEPORT, // attr1 = idx
	TELEDEST, // attr1 = angle, attr2 = idx
	MAPMODEL, // attr1 = angle, attr2 = idx
	MONSTER,  // attr1 = angle, attr2 = monstertype
	CARROT,   // attr1 = tag, attr2 = type
	JUMPPAD,  // attr1 = zpush, attr2 = ypush, attr3 = xpush
	MAXENTTYPES
};

#define MAPVERSION 5 // bump if map format changes, see worldio.cpp

// map file format header
struct header {
	char head[4];   // "CUBE"
	int version;    // any >8bit quantity is a little indian
	int headersize; // sizeof(header)
	int sfactor;    // in bits
	int numents;
	char maptitle[128];
	uchar texlists[3][256];
	int waterlevel;
	int reserved[15];
};

#define SWS(w, x, y, s) (&(w)[(y) * (s) + (x)])
#define SW(w, x, y) SWS(w, x, y, ssize)
#define S(x, y) SW(world, x, y) // convenient lookup of a lowest mip cube
#define SMALLEST_FACTOR 6       // determines number of mips there can be
#define DEFAULT_FACTOR 8
#define LARGEST_FACTOR 11 // 10 is already insane
#define SOLID(x) ((x)->type == SOLID)
#define MINBORD 2 // 2 cubes from the edge of the world are always solid
#define OUTBORD(x, y)                                                \
	((x) < MINBORD || (y) < MINBORD || (x) >= ssize - MINBORD || \
	    (y) >= ssize - MINBORD)

struct block {
	int x, y, xs, ys;
};

enum {
	GUN_FIST = 0,
	GUN_SG,
	GUN_CG,
	GUN_RL,
	GUN_RIFLE,
	GUN_FIREBALL,
	GUN_ICEBALL,
	GUN_SLIMEBALL,
	GUN_BITE,
	NUMGUNS
};

// bump if dynent/netprotocol changes or any other savegame/demo data
#define SAVEGAMEVERSION 4

enum { A_BLUE, A_GREEN, A_YELLOW }; // armour types... take 20/40/60 % off
enum {
	M_NONE = 0,
	M_SEARCH,
	M_HOME,
	M_ATTACKING,
	M_PAIN,
	M_SLEEP,
	M_AIMING
}; // monster states

#define MAXCLIENTS 256 // in a multiplayer game, can be arbitrarily changed
#define MAXTRANS 5000  // max amount of data to swallow in 1 go
#define CUBE_SERVER_PORT 28765
#define CUBE_SERVINFO_PORT 28766
#define PROTOCOL_VERSION 122 // bump when protocol changes

// network messages codes, c2s, c2c, s2c
enum {
	SV_INITS2C,
	SV_INITC2S,
	SV_POS,
	SV_TEXT,
	SV_SOUND,
	SV_CDIS,
	SV_DIED,
	SV_DAMAGE,
	SV_SHOT,
	SV_FRAGS,
	SV_TIMEUP,
	SV_EDITENT,
	SV_MAPRELOAD,
	SV_ITEMACC,
	SV_MAPCHANGE,
	SV_ITEMSPAWN,
	SV_ITEMPICKUP,
	SV_DENIED,
	SV_PING,
	SV_PONG,
	SV_CLIENTPING,
	SV_GAMEMODE,
	SV_EDITH,
	SV_EDITT,
	SV_EDITS,
	SV_EDITD,
	SV_EDITE,
	SV_SENDMAP,
	SV_RECVMAP,
	SV_SERVMSG,
	SV_ITEMLIST,
	SV_EXT,
};

enum { CS_ALIVE = 0, CS_DEAD, CS_LAGGED, CS_EDITING };

// hardcoded sounds, defined in sounds.cfg
enum {
	S_JUMP = 0,
	S_LAND,
	S_RIFLE,
	S_PUNCH1,
	S_SG,
	S_CG,
	S_RLFIRE,
	S_RLHIT,
	S_WEAPLOAD,
	S_ITEMAMMO,
	S_ITEMHEALTH,
	S_ITEMARMOUR,
	S_ITEMPUP,
	S_ITEMSPAWN,
	S_TELEPORT,
	S_NOAMMO,
	S_PUPOUT,
	S_PAIN1,
	S_PAIN2,
	S_PAIN3,
	S_PAIN4,
	S_PAIN5,
	S_PAIN6,
	S_DIE1,
	S_DIE2,
	S_FLAUNCH,
	S_FEXPLODE,
	S_SPLASH1,
	S_SPLASH2,
	S_GRUNT1,
	S_GRUNT2,
	S_RUMBLE,
	S_PAINO,
	S_PAINR,
	S_DEATHR,
	S_PAINE,
	S_DEATHE,
	S_PAINS,
	S_DEATHS,
	S_PAINB,
	S_DEATHB,
	S_PAINP,
	S_PIGGR2,
	S_PAINH,
	S_DEATHH,
	S_PAIND,
	S_DEATHD,
	S_PIGR1,
	S_ICEBALL,
	S_SLIMEBALL,
	S_JUMPPAD,
};

// vertex array format

struct vertex {
	float u, v, x, y, z;
	uchar r, g, b, a;
};

// globals ooh naughty

extern sqr *world,
    *wmip[];       // map data, the mips are sequential 2D arrays in memory
extern header hdr; // current map header
extern int sfactor, ssize;     // ssize = 2^sfactor
extern int cubicsize, mipsize; // cubicsize = ssize^2
// special client ent that receives input and acts as camera
extern DynamicEntity *player1;
// all the other clients (in multiplayer)
extern OFMutableArray *players;
extern bool editmode;
extern OFMutableArray<Entity *> *ents; // map entities
extern OFVector3D worldpos; // current target of the crosshair in the world
extern int lastmillis;      // last time
extern int curtime;         // current frame time
extern int gamemode, nextmode;
extern int xtraverts;
extern bool demoplayback;

#define DMF 16.0f
#define DAF 1.0f
#define DVF 100.0f

#define VIRTW 2400 // virtual screen size for text & HUD
#define VIRTH 1800
#define FONTH 64
#define PIXELTAB (VIRTW / 12)

#define PI (3.1415927f)
#define PI2 (2 * PI)

// simplistic vector ops
#define dotprod(u, v) ((u).x * (v).x + (u).y * (v).y + (u).z * (v).z)
#define vmul(u, f)                                                   \
	{                                                            \
		OFVector3D tmp_ = u;                                 \
		float tmp2_ = f;                                     \
		u = OFMakeVector3D(                                  \
		    tmp_.x * tmp2_, tmp_.y * tmp2_, tmp_.z * tmp2_); \
	}
#define vdiv(u, f)                                                   \
	{                                                            \
		OFVector3D tmp_ = u;                                 \
		float tmp2_ = f;                                     \
		u = OFMakeVector3D(                                  \
		    tmp_.x / tmp2_, tmp_.y / tmp2_, tmp_.z / tmp2_); \
	}
#define vadd(u, v)                                                   \
	{                                                            \
		OFVector3D tmp_ = u;                                 \
		u = OFMakeVector3D(                                  \
		    tmp_.x + (v).x, tmp_.y + (v).y, tmp_.z + (v).z); \
	}
#define vsub(u, v)                                                   \
	{                                                            \
		OFVector3D tmp_ = u;                                 \
		u = OFMakeVector3D(                                  \
		    tmp_.x - (v).x, tmp_.y - (v).y, tmp_.z - (v).z); \
	}
#define vdist(d, v, e, s) \
	OFVector3D v = s; \
	vsub(v, e);       \
	float d = (float)sqrt(dotprod(v, v));
#define vreject(v, u, max)                                 \
	((v).x > (u).x + (max) || (v).x < (u).x - (max) || \
	    (v).y > (u).y + (max) || (v).y < (u).y - (max))
#define vlinterp(v, f, u, g)                   \
	{                                      \
		(v).x = (v).x * f + (u).x * g; \
		(v).y = (v).y * f + (u).y * g; \
		(v).z = (v).z * f + (u).z * g; \
	}

#define sgetstr()                        \
	{                                \
		char *t = text;          \
		do {                     \
			*t = getint(&p); \
		} while (*t++);          \
	} // used by networking

#define m_noitems (gamemode >= 4)
#define m_noitemsrail (gamemode <= 5)
#define m_arena (gamemode >= 8)
#define m_tarena (gamemode >= 10)
#define m_teammode (gamemode & 1 && gamemode > 2)
#define m_sp (gamemode < 0)
#define m_dmsp (gamemode == -1)
#define m_classicsp (gamemode == -2)
#define isteam(a, b) (m_teammode && [a isEqual:b])

// function signatures for script functions, see command.mm
enum {
	ARG_1INT,
	ARG_2INT,
	ARG_3INT,
	ARG_4INT,
	ARG_NONE,
	ARG_1STR,
	ARG_2STR,
	ARG_3STR,
	ARG_5STR,
	ARG_DOWN,
	ARG_DWN1,
	ARG_1EXP,
	ARG_2EXP,
	ARG_1EST,
	ARG_2EST,
	ARG_VARI
};

// nasty macros for registering script functions, abuses globals to avoid
// excessive infrastructure
#define COMMANDN(name, fun, nargs)                                   \
	OF_CONSTRUCTOR()                                             \
	{                                                            \
		enqueueInit(^{                                       \
			addcommand(@ #name, (void (*)())fun, nargs); \
		});                                                  \
	}
#define COMMAND(name, nargs) COMMANDN(name, name, nargs)
#define VARP(name, min, cur, max)                                       \
	int name;                                                       \
	OF_CONSTRUCTOR()                                                \
	{                                                               \
		enqueueInit(^{                                          \
			name = variable(                                \
			    @ #name, min, cur, max, &name, NULL, true); \
		});                                                     \
	}
#define VAR(name, min, cur, max)                                         \
	int name;                                                        \
	OF_CONSTRUCTOR()                                                 \
	{                                                                \
		enqueueInit(^{                                           \
			name = variable(                                 \
			    @ #name, min, cur, max, &name, NULL, false); \
		});                                                      \
	}
#define VARF(name, min, cur, max, body)                                        \
	void var_##name();                                                     \
	static int name;                                                       \
	OF_CONSTRUCTOR()                                                       \
	{                                                                      \
		enqueueInit(^{                                                 \
			name = variable(                                       \
			    @ #name, min, cur, max, &name, var_##name, false); \
		});                                                            \
	}                                                                      \
	void var_##name() { body; }
#define VARFP(name, min, cur, max, body)                                      \
	void var_##name();                                                    \
	static int name;                                                      \
	OF_CONSTRUCTOR()                                                      \
	{                                                                     \
		enqueueInit(^{                                                \
			name = variable(                                      \
			    @ #name, min, cur, max, &name, var_##name, true); \
		});                                                           \
	}                                                                     \
	void var_##name() { body; }

#define ATOI(s) strtol(s, NULL, 0) // supports hexadecimal numbers

#ifdef WIN32
# define WIN32_LEAN_AND_MEAN
# include "windows.h"
# define _WINDOWS
# define ZLIB_DLL
#else
# include <dlfcn.h>
#endif

#include <time.h>

#ifdef OF_MACOS
# define GL_SILENCE_DEPRECATION
# define GL_EXT_texture_env_combine 1
# include <OpenGL/gl.h>
# include <OpenGL/glext.h>
# include <OpenGL/glu.h>
#else
# include <GL/gl.h>
# include <GL/glext.h>
# include <GL/glu.h>
#endif

#include <SDL.h>
#include <SDL_image.h>

#include <enet/enet.h>

#include <zlib.h>

#include "protos.h" // external function decls
