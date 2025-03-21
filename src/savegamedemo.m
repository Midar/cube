// loading and saving of savegames & demos, dumps the spawn state of all
// mapents, the full state of all dynents (monsters + player)

#include "cube.h"

#import "DynamicEntity.h"
#import "Entity.h"

#ifdef OF_BIG_ENDIAN
static const int islittleendian = 0;
#else
static const int islittleendian = 1;
#endif

static gzFile f = NULL;
bool demorecording = false;
bool demoplayback = false;
bool demoloading = false;
static OFMutableArray<DynamicEntity *> *playerhistory;
int democlientnum = 0;

extern void startdemo();

static void
gzput(int i)
{
	gzputc(f, i);
}

static void
gzputi(int i)
{
	gzwrite(f, &i, sizeof(int));
}

static void
gzputv(const OFVector3D *v)
{
	gzwrite(f, v, sizeof(OFVector3D));
}

static void
gzcheck(int a, int b)
{
	if (a != b)
		fatal(@"savegame file corrupt (short)");
}

static int
gzget()
{
	char c = gzgetc(f);
	return c;
}

static int
gzgeti()
{
	int i;
	gzcheck(gzread(f, &i, sizeof(int)), sizeof(int));
	return i;
}

static void
gzgetv(OFVector3D *v)
{
	gzcheck(gzread(f, v, sizeof(OFVector3D)), sizeof(OFVector3D));
}

void
stop()
{
	if (f) {
		if (demorecording)
			gzputi(-1);
		gzclose(f);
	}
	f = NULL;
	demorecording = false;
	demoplayback = false;
	demoloading = false;
	[playerhistory removeAllObjects];
}

void
stopifrecording()
{
	if (demorecording)
		stop();
}

void
savestate(OFIRI *IRI)
{
	stop();
	f = gzopen([IRI.fileSystemRepresentation
	               cStringWithEncoding:OFLocale.encoding],
	    "wb9");
	if (!f) {
		conoutf(@"could not write %@", IRI.string);
		return;
	}
	gzwrite(f, (void *)"CUBESAVE", 8);
	gzputc(f, islittleendian);
	gzputi(SAVEGAMEVERSION);
	OFData *data = [player1 dataBySerializing];
	gzputi(data.count);
	char map[_MAXDEFSTR] = { 0 };
	memcpy(map, getclientmap().UTF8String,
	    min(getclientmap().UTF8StringLength, _MAXDEFSTR - 1));
	gzwrite(f, map, _MAXDEFSTR);
	gzputi(gamemode);
	gzputi(ents.count);
	for (Entity *e in ents)
		gzputc(f, e.spawned);
	gzwrite(f, data.items, data.count);
	OFArray<DynamicEntity *> *monsters = getmonsters();
	gzputi(monsters.count);
	for (DynamicEntity *monster in monsters) {
		data = [monster dataBySerializing];
		gzwrite(f, data.items, data.count);
	}
	gzputi(players.count);
	for (id player in players) {
		gzput(player == [OFNull null]);
		data = [player dataBySerializing];
		gzwrite(f, data.items, data.count);
	}
}

void
savegame(OFString *name)
{
	if (!m_classicsp) {
		conoutf(@"can only save classic sp games");
		return;
	}

	OFString *path = [OFString stringWithFormat:@"savegames/%@.csgz", name];
	OFIRI *IRI =
	    [Cube.sharedInstance.userDataIRI IRIByAppendingPathComponent:path];
	savestate(IRI);
	stop();
	conoutf(@"wrote %@", IRI.string);
}
COMMAND(savegame, ARG_1STR)

void
loadstate(OFIRI *IRI)
{
	stop();
	if (multiplayer())
		return;
	f = gzopen([IRI.fileSystemRepresentation
	               cStringWithEncoding:OFLocale.encoding],
	    "rb9");
	if (!f) {
		conoutf(@"could not open %@", IRI.string);
		return;
	}

	char mapname[_MAXDEFSTR] = { 0 };
	char buf[8];
	gzread(f, buf, 8);
	if (strncmp(buf, "CUBESAVE", 8))
		goto out;
	if (gzgetc(f) != islittleendian)
		goto out; // not supporting save->load accross
		          // incompatible architectures simpifies things
		          // a LOT
	if (gzgeti() != SAVEGAMEVERSION ||
	    gzgeti() != DynamicEntity.serializedSize)
		goto out;
	gzread(f, mapname, _MAXDEFSTR);
	nextmode = gzgeti();
	// continue below once map has been loaded and client & server
	// have updated
	changemap(@(mapname));
	return;
out:
	conoutf(@"aborting: savegame/demo from a different version of "
	        @"cube or cpu architecture");
	stop();
}

void
loadgame(OFString *name)
{
	OFString *path = [OFString stringWithFormat:@"savegames/%@.csgz", name];
	OFIRI *IRI =
	    [Cube.sharedInstance.userDataIRI IRIByAppendingPathComponent:path];
	loadstate(IRI);
}
COMMAND(loadgame, ARG_1STR)

void
loadgameout()
{
	stop();
	conoutf(@"loadgame incomplete: savegame from a different version of "
	        @"this map");
}

void
loadgamerest()
{
	if (demoplayback || !f)
		return;

	if (gzgeti() != ents.count)
		return loadgameout();

	for (Entity *e in ents) {
		e.spawned = (gzgetc(f) != 0);

		if (e.type == CARROT && !e.spawned)
			trigger(e.attr1, e.attr2, true);
	}

	restoreserverstate(ents);

	OFMutableData *data =
	    [OFMutableData dataWithCapacity:DynamicEntity.serializedSize];
	[data increaseCountBy:DynamicEntity.serializedSize];
	gzread(f, data.mutableItems, data.count);
	[player1 setFromSerializedData:data];
	player1.lastaction = lastmillis;

	int nmonsters = gzgeti();
	OFArray<DynamicEntity *> *monsters = getmonsters();
	if (nmonsters != monsters.count)
		return loadgameout();

	for (DynamicEntity *monster in monsters) {
		gzread(f, data.mutableItems, data.count);
		[monster setFromSerializedData:data];
		// lazy, could save id of enemy instead
		monster.enemy = player1;
		// also lazy, but no real noticable effect on game
		monster.lastaction = monster.trigger = lastmillis + 500;
		if (monster.state == CS_DEAD)
			monster.lastaction = 0;
	}
	restoremonsterstate();

	int nplayers = gzgeti();
	loopi(nplayers) if (!gzget())
	{
		DynamicEntity *d = getclient(i);
		assert(d);
		gzread(f, data.mutableItems, data.count);
		[d setFromSerializedData:data];
	}

	conoutf(@"savegame restored");
	if (demoloading)
		startdemo();
	else
		stop();
}

// demo functions

int starttime = 0;
int playbacktime = 0;
int ddamage, bdamage;
OFVector3D dorig;

void
record(OFString *name)
{
	if (m_sp) {
		conoutf(@"cannot record singleplayer games");
		return;
	}

	int cn = getclientnum();
	if (cn < 0)
		return;

	OFString *path = [OFString stringWithFormat:@"demos/%@.cdgz", name];
	OFIRI *IRI =
	    [Cube.sharedInstance.userDataIRI IRIByAppendingPathComponent:path];
	savestate(IRI);
	gzputi(cn);
	conoutf(@"started recording demo to %@", IRI.string);
	demorecording = true;
	starttime = lastmillis;
	ddamage = bdamage = 0;
}
COMMAND(record, ARG_1STR)

void
demodamage(int damage, const OFVector3D *o)
{
	ddamage = damage;
	dorig = *o;
}

void
demoblend(int damage)
{
	bdamage = damage;
}

void
incomingdemodata(uchar *buf, int len, bool extras)
{
	if (!demorecording)
		return;
	gzputi(lastmillis - starttime);
	gzputi(len);
	gzwrite(f, buf, len);
	gzput(extras);
	if (extras) {
		gzput(player1.gunselect);
		gzput(player1.lastattackgun);
		gzputi(player1.lastaction - starttime);
		gzputi(player1.gunwait);
		gzputi(player1.health);
		gzputi(player1.armour);
		gzput(player1.armourtype);
		loopi(NUMGUNS) gzput(player1.ammo[i]);
		gzput(player1.state);
		gzputi(bdamage);
		bdamage = 0;
		gzputi(ddamage);
		if (ddamage) {
			gzputv(&dorig);
			ddamage = 0;
		}
		// FIXME: add all other client state which is not send through
		// the network
	}
}

void
demo(OFString *name)
{
	OFString *path = [OFString stringWithFormat:@"demos/%@.cdgz", name];
	OFIRI *IRI =
	    [Cube.sharedInstance.userDataIRI IRIByAppendingPathComponent:path];
	loadstate(IRI);
	demoloading = true;
}
COMMAND(demo, ARG_1STR)

void
stopreset()
{
	conoutf(@"demo stopped (%d msec elapsed)", lastmillis - starttime);
	stop();
	[players removeAllObjects];
	disconnect(false, false);
}

VAR(demoplaybackspeed, 10, 100, 1000);
int
scaletime(int t)
{
	return (int)(t * (100.0f / demoplaybackspeed)) + starttime;
}

void
readdemotime()
{
	if (gzeof(f) || (playbacktime = gzgeti()) == -1) {
		stopreset();
		return;
	}
	playbacktime = scaletime(playbacktime);
}

void
startdemo()
{
	democlientnum = gzgeti();
	demoplayback = true;
	starttime = lastmillis;
	conoutf(@"now playing demo");
	setclient(democlientnum, [player1 copy]);
	readdemotime();
}

VAR(demodelaymsec, 0, 120, 500);

// spline interpolation
#define catmulrom(z, a, b, c, s, dest)           \
	{                                        \
		OFVector3D t1 = b, t2 = c;       \
                                                 \
		vsub(t1, z);                     \
		vmul(t1, 0.5f);                  \
		vsub(t2, a);                     \
		vmul(t2, 0.5f);                  \
                                                 \
		float s2 = s * s;                \
		float s3 = s * s2;               \
                                                 \
		dest = a;                        \
		OFVector3D t = b;                \
                                                 \
		vmul(dest, 2 * s3 - 3 * s2 + 1); \
		vmul(t, -2 * s3 + 3 * s2);       \
		vadd(dest, t);                   \
		vmul(t1, s3 - 2 * s2 + s);       \
		vadd(dest, t1);                  \
		vmul(t2, s3 - s2);               \
		vadd(dest, t2);                  \
	}

void
fixwrap(DynamicEntity *a, DynamicEntity *b)
{
	while (b.yaw - a.yaw > 180)
		a.yaw += 360;
	while (b.yaw - a.yaw < -180)
		a.yaw -= 360;
}

void
demoplaybackstep()
{
	while (demoplayback && lastmillis >= playbacktime) {
		int len = gzgeti();
		if (len < 1 || len > MAXTRANS) {
			conoutf(
			    @"error: huge packet during demo play (%d)", len);
			stopreset();
			return;
		}
		uchar buf[MAXTRANS];
		gzread(f, buf, len);
		localservertoclient(buf, len); // update game state

		DynamicEntity *target = players[democlientnum];
		assert(target);

		int extras;
		// read additional client side state not present in normal
		// network stream
		if ((extras = gzget())) {
			target.gunselect = gzget();
			target.lastattackgun = gzget();
			target.lastaction = scaletime(gzgeti());
			target.gunwait = gzgeti();
			target.health = gzgeti();
			target.armour = gzgeti();
			target.armourtype = gzget();
			loopi(NUMGUNS) target.ammo[i] = gzget();
			target.state = gzget();
			target.lastmove = playbacktime;
			if ((bdamage = gzgeti()))
				damageblend(bdamage);
			if ((ddamage = gzgeti())) {
				gzgetv(&dorig);
				particle_splash(3, ddamage, 1000, &dorig);
			}
			// FIXME: set more client state here
		}

		// insert latest copy of player into history
		if (extras &&
		    (playerhistory.count == 0 ||
		        playerhistory.lastObject.lastupdate != playbacktime)) {
			DynamicEntity *d = [target copy];
			d.lastupdate = playbacktime;

			if (playerhistory == nil)
				playerhistory = [[OFMutableArray alloc] init];

			[playerhistory addObject:d];

			if (playerhistory.count > 20)
				[playerhistory removeObjectAtIndex:0];
		}

		readdemotime();
	}

	if (!demoplayback)
		return;

	int itime = lastmillis - demodelaymsec;
	// find 2 positions in history that surround interpolation time point
	size_t count = playerhistory.count;
	for (ssize_t i = count - 1; i >= 0; i--) {
		if (playerhistory[i].lastupdate < itime) {
			DynamicEntity *a = playerhistory[i];
			DynamicEntity *b = a;

			if (i + 1 < playerhistory.count)
				b = playerhistory[i + 1];

			player1 = b;
			// interpolate pos & angles
			if (a != b) {
				DynamicEntity *c = b;
				if (i + 2 < playerhistory.count)
					c = playerhistory[i + 2];
				DynamicEntity *z = a;
				if (i - 1 >= 0)
					z = playerhistory[i - 1];
				// if(a==z || b==c)
				//	printf("* %d\n", lastmillis);
				float bf = (itime - a.lastupdate) /
				    (float)(b.lastupdate - a.lastupdate);
				fixwrap(a, player1);
				fixwrap(c, player1);
				fixwrap(z, player1);
				vdist(dist, v, z.o, c.o);
				// if teleport or spawn, don't interpolate
				if (dist < 16) {
					catmulrom(
					    z.o, a.o, b.o, c.o, bf, player1.o);
					OFVector3D vz = OFMakeVector3D(
					    z.yaw, z.pitch, z.roll);
					OFVector3D va = OFMakeVector3D(
					    a.yaw, a.pitch, a.roll);
					OFVector3D vb = OFMakeVector3D(
					    b.yaw, b.pitch, b.roll);
					OFVector3D vc = OFMakeVector3D(
					    c.yaw, c.pitch, c.roll);
					OFVector3D vp1 =
					    OFMakeVector3D(player1.yaw,
					        player1.pitch, player1.roll);
					catmulrom(vz, va, vb, vc, bf, vp1);
					z.yaw = vz.x;
					z.pitch = vz.y;
					z.roll = vz.z;
					a.yaw = va.x;
					a.pitch = va.y;
					a.roll = va.z;
					b.yaw = vb.x;
					b.pitch = vb.y;
					b.roll = vb.z;
					c.yaw = vc.x;
					c.pitch = vc.y;
					c.roll = vc.z;
					player1.yaw = vp1.x;
					player1.pitch = vp1.y;
					player1.roll = vp1.z;
				}
				fixplayer1range();
			}
			break;
		}
	}
	// if(player1->state!=CS_DEAD) showscores(false);
}

void
stopn()
{
	if (demoplayback)
		stopreset();
	else
		stop();
	conoutf(@"demo stopped");
}
COMMANDN(stop, stopn, ARG_NONE)
