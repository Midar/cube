// loading and saving of savegames & demos, dumps the spawn state of all
// mapents, the full state of all dynents (monsters + player)

#include "cube.h"

#ifdef OF_BIG_ENDIAN
static const int islittleendian = 0;
#else
static const int islittleendian = 1;
#endif

gzFile f = NULL;
bool demorecording = false;
bool demoplayback = false;
bool demoloading = false;
dvector playerhistory;
int democlientnum = 0;

void startdemo();

void
gzput(int i)
{
	gzputc(f, i);
}

void
gzputi(int i)
{
	gzwrite(f, &i, sizeof(int));
}

void
gzputv(OFVector3D &v)
{
	gzwrite(f, &v, sizeof(OFVector3D));
}

void
gzcheck(int a, int b)
{
	if (a != b)
		fatal(@"savegame file corrupt (short)");
}

int
gzget()
{
	char c = gzgetc(f);
	return c;
}

int
gzgeti()
{
	int i;
	gzcheck(gzread(f, &i, sizeof(int)), sizeof(int));
	return i;
}

void
gzgetv(OFVector3D &v)
{
	gzcheck(gzread(f, &v, sizeof(OFVector3D)), sizeof(OFVector3D));
}

void
stop()
{
	if (f) {
		if (demorecording)
			gzputi(-1);
		gzclose(f);
	};
	f = NULL;
	demorecording = false;
	demoplayback = false;
	demoloading = false;
	loopv(playerhistory) zapdynent(playerhistory[i]);
	playerhistory.setsize(0);
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
	@autoreleasepool {
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
		gzputi(sizeof(dynent));
		gzwrite(f, getclientmap().UTF8String, _MAXDEFSTR);
		gzputi(gamemode);
		gzputi(ents.length());
		loopv(ents) gzputc(f, ents[i].spawned);
		gzwrite(f, player1, sizeof(dynent));
		dvector &monsters = getmonsters();
		gzputi(monsters.length());
		loopv(monsters) gzwrite(f, monsters[i], sizeof(dynent));
		gzputi(players.length());
		loopv(players)
		{
			gzput(players[i] == NULL);
			gzwrite(f, players[i], sizeof(dynent));
		}
	}
}

void
savegame(OFString *name)
{
	if (!m_classicsp) {
		conoutf(@"can only save classic sp games");
		return;
	}

	@autoreleasepool {
		OFString *path =
		    [OFString stringWithFormat:@"savegames/%@.csgz", name];
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:path];
		savestate(IRI);
		stop();
		conoutf(@"wrote %@", IRI.string);
	}
}
COMMAND(savegame, ARG_1STR)

void
loadstate(OFIRI *IRI)
{
	@autoreleasepool {
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

		string buf;
		gzread(f, buf, 8);
		if (strncmp(buf, "CUBESAVE", 8))
			goto out;
		if (gzgetc(f) != islittleendian)
			goto out; // not supporting save->load accross
			          // incompatible architectures simpifies things
			          // a LOT
		if (gzgeti() != SAVEGAMEVERSION || gzgeti() != sizeof(dynent))
			goto out;
		string mapname;
		gzread(f, mapname, _MAXDEFSTR);
		nextmode = gzgeti();
		@autoreleasepool {
			// continue below once map has been loaded and client &
			// server have updated
			changemap(@(mapname));
		}
		return;
	out:
		conoutf(@"aborting: savegame/demo from a different version of "
		        @"cube or cpu architecture");
		stop();
	}
}

void
loadgame(OFString *name)
{
	@autoreleasepool {
		OFString *path =
		    [OFString stringWithFormat:@"savegames/%@.csgz", name];
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:path];
		loadstate(IRI);
	}
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

	if (gzgeti() != ents.length())
		return loadgameout();
	loopv(ents)
	{
		ents[i].spawned = gzgetc(f) != 0;
		if (ents[i].type == CARROT && !ents[i].spawned)
			trigger(ents[i].attr1, ents[i].attr2, true);
	};
	restoreserverstate(ents);

	gzread(f, player1, sizeof(dynent));
	player1->lastaction = lastmillis;

	int nmonsters = gzgeti();
	dvector &monsters = getmonsters();
	if (nmonsters != monsters.length())
		return loadgameout();
	loopv(monsters)
	{
		gzread(f, monsters[i], sizeof(dynent));
		monsters[i]->enemy =
		    player1; // lazy, could save id of enemy instead
		monsters[i]->lastaction = monsters[i]->trigger =
		    lastmillis +
		    500; // also lazy, but no real noticable effect on game
		if (monsters[i]->state == CS_DEAD)
			monsters[i]->lastaction = 0;
	};
	restoremonsterstate();

	int nplayers = gzgeti();
	loopi(nplayers) if (!gzget())
	{
		dynent *d = getclient(i);
		assert(d);
		gzread(f, d, sizeof(dynent));
	};

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

	@autoreleasepool {
		OFString *path =
		    [OFString stringWithFormat:@"demos/%@.cdgz", name];
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:path];
		savestate(IRI);
		gzputi(cn);
		conoutf(@"started recording demo to %@", IRI.string);
		demorecording = true;
		starttime = lastmillis;
		ddamage = bdamage = 0;
	}
}
COMMAND(record, ARG_1STR)

void
demodamage(int damage, OFVector3D &o)
{
	ddamage = damage;
	dorig = o;
};
void
demoblend(int damage)
{
	bdamage = damage;
};

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
		gzput(player1->gunselect);
		gzput(player1->lastattackgun);
		gzputi(player1->lastaction - starttime);
		gzputi(player1->gunwait);
		gzputi(player1->health);
		gzputi(player1->armour);
		gzput(player1->armourtype);
		loopi(NUMGUNS) gzput(player1->ammo[i]);
		gzput(player1->state);
		gzputi(bdamage);
		bdamage = 0;
		gzputi(ddamage);
		if (ddamage) {
			gzputv(dorig);
			ddamage = 0;
		}
		// FIXME: add all other client state which is not send through
		// the network
	}
}

void
demo(OFString *name)
{
	@autoreleasepool {
		OFString *path =
		    [OFString stringWithFormat:@"demos/%@.cdgz", name];
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:path];
		loadstate(IRI);
		demoloading = true;
	}
}
COMMAND(demo, ARG_1STR)

void
stopreset()
{
	conoutf(@"demo stopped (%d msec elapsed)", lastmillis - starttime);
	stop();
	loopv(players) zapdynent(players[i]);
	disconnect(0, 0);
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
	dynent *d = getclient(democlientnum);
	assert(d);
	*d = *player1;
	readdemotime();
}

VAR(demodelaymsec, 0, 120, 500);

// spline interpolation
void
catmulrom(OFVector3D &z, OFVector3D &a, OFVector3D &b, OFVector3D &c, float s,
    OFVector3D &dest)
{
	OFVector3D t1 = b, t2 = c;

	vsub(t1, z);
	vmul(t1, 0.5f) vsub(t2, a);
	vmul(t2, 0.5f);

	float s2 = s * s;
	float s3 = s * s2;

	dest = a;
	OFVector3D t = b;

	vmul(dest, 2 * s3 - 3 * s2 + 1);
	vmul(t, -2 * s3 + 3 * s2);
	vadd(dest, t);
	vmul(t1, s3 - 2 * s2 + s);
	vadd(dest, t1);
	vmul(t2, s3 - s2);
	vadd(dest, t2);
};

void
fixwrap(dynent *a, dynent *b)
{
	while (b->yaw - a->yaw > 180)
		a->yaw += 360;
	while (b->yaw - a->yaw < -180)
		a->yaw -= 360;
};

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

		dynent *target = players[democlientnum];
		assert(target);

		int extras;
		if (extras = gzget()) // read additional client side state not
		                      // present in normal network stream
		{
			target->gunselect = gzget();
			target->lastattackgun = gzget();
			target->lastaction = scaletime(gzgeti());
			target->gunwait = gzgeti();
			target->health = gzgeti();
			target->armour = gzgeti();
			target->armourtype = gzget();
			loopi(NUMGUNS) target->ammo[i] = gzget();
			target->state = gzget();
			target->lastmove = playbacktime;
			if (bdamage = gzgeti())
				damageblend(bdamage);
			if (ddamage = gzgeti()) {
				gzgetv(dorig);
				particle_splash(3, ddamage, 1000, dorig);
			}
			// FIXME: set more client state here
		}

		// insert latest copy of player into history
		if (extras &&
		    (playerhistory.empty() ||
		        playerhistory.last()->lastupdate != playbacktime)) {
			dynent *d = newdynent();
			*d = *target;
			d->lastupdate = playbacktime;
			playerhistory.add(d);
			if (playerhistory.length() > 20) {
				zapdynent(playerhistory[0]);
				playerhistory.remove(0);
			}
		}

		readdemotime();
	}

	if (demoplayback) {
		int itime = lastmillis - demodelaymsec;
		loopvrev(playerhistory) if (playerhistory[i]->lastupdate <
		                            itime) // find 2 positions in
		                                   // history that surround
		                                   // interpolation time point
		{
			dynent *a = playerhistory[i];
			dynent *b = a;
			if (i + 1 < playerhistory.length())
				b = playerhistory[i + 1];
			*player1 = *b;
			if (a != b) // interpolate pos & angles
			{
				dynent *c = b;
				if (i + 2 < playerhistory.length())
					c = playerhistory[i + 2];
				dynent *z = a;
				if (i - 1 >= 0)
					z = playerhistory[i - 1];
				// if(a==z || b==c) printf("* %d\n",
				// lastmillis);
				float bf =
				    (itime - a->lastupdate) /
				    (float)(b->lastupdate - a->lastupdate);
				fixwrap(a, player1);
				fixwrap(c, player1);
				fixwrap(z, player1);
				vdist(dist, v, z->o, c->o);
				if (dist < 16) // if teleport or spawn, dont't
				               // interpolate
				{
					catmulrom(z->o, a->o, b->o, c->o, bf,
					    player1->o);
					catmulrom(*(OFVector3D *)&z->yaw,
					    *(OFVector3D *)&a->yaw,
					    *(OFVector3D *)&b->yaw,
					    *(OFVector3D *)&c->yaw, bf,
					    *(OFVector3D *)&player1->yaw);
				}
				fixplayer1range();
			}
			break;
		}
		// if(player1->state!=CS_DEAD) showscores(false);
	}
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
