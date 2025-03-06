// clientextras.cpp: stuff that didn't fit in client.cpp or clientgame.cpp :)

#include "cube.h"

// render players & monsters
// very messy ad-hoc handling of animation frames, should be made more
// configurable

//              D    D    D    D'   D    D    D    D'   A   A'  P   P'  I   I'
//              R,  R'  E    L    J   J'
int frame[] = {178, 184, 190, 137, 183, 189, 197, 164, 46, 51, 54, 32, 0, 0, 40,
    1, 162, 162, 67, 168};
int range[] = {6, 6, 8, 28, 1, 1, 1, 1, 8, 19, 4, 18, 40, 1, 6, 15, 1, 1, 1, 1};

void
renderclient(dynent *d, bool team, OFString *mdlname, bool hellpig, float scale)
{
	int n = 3;
	float speed = 100.0f;
	float mz = d->o.z - d->eyeheight + 1.55f * scale;
	int basetime = -((intptr_t)d & 0xFFF);
	if (d->state == CS_DEAD) {
		int r;
		if (hellpig) {
			n = 2;
			r = range[3];
		} else {
			n = (intptr_t)d % 3;
			r = range[n];
		}
		basetime = d->lastaction;
		int t = lastmillis - d->lastaction;
		if (t < 0 || t > 20000)
			return;
		if (t > (r - 1) * 100) {
			n += 4;
			if (t > (r + 10) * 100) {
				t -= (r + 10) * 100;
				mz -= t * t / 10000000000.0f * t;
			};
		};
		if (mz < -1000)
			return;
		// mdl = (((int)d>>6)&1)+1;
		// mz = d->o.z-d->eyeheight+0.2f;
		// scale = 1.2f;
	} else if (d->state == CS_EDITING) {
		n = 16;
	} else if (d->state == CS_LAGGED) {
		n = 17;
	} else if (d->monsterstate == M_ATTACKING) {
		n = 8;
	} else if (d->monsterstate == M_PAIN) {
		n = 10;
	} else if ((!d->move && !d->strafe) || !d->moving) {
		n = 12;
	} else if (!d->onfloor && d->timeinair > 100) {
		n = 18;
	} else {
		n = 14;
		speed = 1200 / d->maxspeed * scale;
		if (hellpig)
			speed = 300 / d->maxspeed;
	}
	if (hellpig) {
		n++;
		scale *= 32;
		mz -= 1.9f;
	}
	rendermodel(mdlname, frame[n], range[n], 0, 1.5f, d->o.x, mz, d->o.y,
	    d->yaw + 90, d->pitch / 2, team, scale, speed, 0, basetime);
}

extern int democlientnum;

void
renderclients()
{
	dynent *d;
	loopv(players) if ((d = players[i]) &&
	                   (!demoplayback || i != democlientnum))
	    renderclient(d, isteam(player1->team, d->team), @"monster/ogro",
	        false, 1.0f);
}

// creation of scoreboard pseudo-menu

bool scoreson = false;

void
showscores(bool on)
{
	scoreson = on;
	menuset(((int)on) - 1);
}

static OFMutableArray<OFString *> *scoreLines;

void
renderscore(dynent *d)
{
	@autoreleasepool {
		OFString *lag = [OFString stringWithFormat:@"%d", d->plag];
		OFString *name = [OFString stringWithFormat:@"(%s)", d->name];
		OFString *line = [OFString
		    stringWithFormat:@"%d\t%@\t%d\t%s\t%@", d->frags,
		    (d->state == CS_LAGGED ? @"LAG" : lag), d->ping, d->team,
		    (d->state == CS_DEAD ? name : @(d->name))];

		if (scoreLines == nil)
			scoreLines = [[OFMutableArray alloc] init];

		[scoreLines addObject:line];

		menumanual(0, scoreLines.count - 1, line);
	}
}

static const int maxTeams = 4;
static OFString *teamName[maxTeams];
static int teamScore[maxTeams], teamsUsed;

void
addteamscore(dynent *d)
{
	if (d == NULL)
		return;

	@autoreleasepool {
		OFString *team = @(d->team);

		loopi(teamsUsed)
		{
			if ([teamName[i] isEqual:team]) {
				teamScore[i] += d->frags;
				return;
			}
		}

		if (teamsUsed == maxTeams)
			return;

		teamName[teamsUsed] = @(d->team);
		teamScore[teamsUsed++] = d->frags;
	}
}

void
renderscores()
{
	if (!scoreson)
		return;
	[scoreLines removeAllObjects];
	if (!demoplayback)
		renderscore(player1);
	loopv(players) if (players[i]) renderscore(players[i]);
	sortmenu();
	if (m_teammode) {
		teamsUsed = 0;
		loopv(players) addteamscore(players[i]);
		if (!demoplayback)
			addteamscore(player1);
		OFMutableString *teamScores = [[OFMutableString alloc] init];
		loopj(teamsUsed)
		{
			[teamScores appendFormat:@"[ %@: %d ]", teamName[j],
			            teamScore[j]];
		}
		menumanual(0, scoreLines.count, @"");
		@autoreleasepool {
			menumanual(0, scoreLines.count + 1, teamScores);
		}
	}
}

// sendmap/getmap commands, should be replaced by more intuitive map downloading

void
sendmap(OFString *mapname)
{
	@autoreleasepool {
		if (mapname.length > 0)
			save_world(mapname);
		changemap(mapname);
		mapname = getclientmap();
		OFData *mapdata = readmap(mapname);
		if (mapdata == nil)
			return;
		ENetPacket *packet = enet_packet_create(
		    NULL, MAXTRANS + mapdata.count, ENET_PACKET_FLAG_RELIABLE);
		uchar *start = packet->data;
		uchar *p = start + 2;
		putint(p, SV_SENDMAP);
		sendstring(mapname.UTF8String, p);
		putint(p, mapdata.count);
		if (65535 - (p - start) < mapdata.count) {
			conoutf(@"map %@ is too large to send", mapname);
			enet_packet_destroy(packet);
			return;
		}
		memcpy(p, mapdata.items, mapdata.count);
		p += mapdata.count;
		*(ushort *)start = ENET_HOST_TO_NET_16(p - start);
		enet_packet_resize(packet, p - start);
		sendpackettoserv(packet);
		conoutf(@"sending map %@ to server...", mapname);
		sprintf_sd(msg)(
		    "[map %@ uploaded to server, \"getmap\" to receive it]",
		    mapname);
		toserver(msg);
	}
}

void
getmap()
{
	ENetPacket *packet =
	    enet_packet_create(NULL, MAXTRANS, ENET_PACKET_FLAG_RELIABLE);
	uchar *start = packet->data;
	uchar *p = start + 2;
	putint(p, SV_RECVMAP);
	*(ushort *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	sendpackettoserv(packet);
	conoutf(@"requesting map from server...");
}

COMMAND(sendmap, ARG_1STR)
COMMAND(getmap, ARG_NONE)
