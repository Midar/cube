// clientextras.cpp: stuff that didn't fit in client.cpp or clientgame.cpp :)

#include "cube.h"

#import "Command.h"
#import "Monster.h"
#import "Player.h"

// render players & monsters
// very messy ad-hoc handling of animation frames, should be made more
// configurable

// D    D    D    D'   D    D    D    D'   A   A'  P   P'  I   I'
// R,  R'  E    L    J   J'
int frame[] = {
	178, 184, 190, 137, 183, 189, 197, 164, 46, 51, 54, 32, 0, 0, 40, 1,
	162, 162, 67, 168
};
int range[] = {
	6, 6, 8, 28, 1, 1, 1, 1, 8, 19, 4, 18, 40, 1, 6, 15, 1, 1, 1, 1
};

void
renderclient(
    DynamicEntity *d, bool team, OFString *mdlname, bool hellpig, float scale)
{
	int n = 3;
	float speed = 100.0f;
	float mz = d.origin.z - d.eyeHeight + 1.55f * scale;
	intptr_t tmp = (intptr_t)d;
	int basetime = -(tmp & 0xFFF);
	if (d.state == CS_DEAD) {
		int r;
		if (hellpig) {
			n = 2;
			r = range[3];
		} else {
			n = (intptr_t)d % 3;
			r = range[n];
		}
		basetime = d.lastAction;
		int t = lastmillis - d.lastAction;
		if (t < 0 || t > 20000)
			return;
		if (t > (r - 1) * 100) {
			n += 4;
			if (t > (r + 10) * 100) {
				t -= (r + 10) * 100;
				mz -= t * t / 10000000000.0f * t;
			}
		}
		if (mz < -1000)
			return;
		// mdl = (((int)d>>6)&1)+1;
		// mz = d.o.z-d.eyeHeight+0.2f;
		// scale = 1.2f;
	} else if (d.state == CS_EDITING)
		n = 16;
	else if (d.state == CS_LAGGED)
		n = 17;
	else if ([d isKindOfClass: Monster.class] &&
	    ((Monster *)d).monsterState == M_ATTACKING)
		n = 8;
	else if ([d isKindOfClass: Monster.class] &&
	    ((Monster *)d).monsterState == M_PAIN)
		n = 10;
	else if ((!d.move && !d.strafe) || !d.moving)
		n = 12;
	else if (!d.onFloor && d.timeInAir > 100)
		n = 18;
	else {
		n = 14;
		speed = 1200 / d.maxSpeed * scale;
		if (hellpig)
			speed = 300 / d.maxSpeed;
	}
	if (hellpig) {
		n++;
		scale *= 32;
		mz -= 1.9f;
	}
	rendermodel(mdlname, frame[n], range[n], 0, 1.5f,
	    OFMakeVector3D(d.origin.x, mz, d.origin.y), d.yaw + 90, d.pitch / 2,
	    team, scale, speed, 0, basetime);
}

extern int democlientnum;

void
renderclients()
{
	[players enumerateObjectsUsingBlock: ^ (Player *player, size_t i,
	    bool *stop) {
		if ([player isKindOfClass: Player.class] &&
		    (!demoplayback || i != democlientnum))
			renderclient(player, isteam(Player.player1.team,
			    [player team]), @"monster/ogro", false, 1.0f);
	}];
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

static void
renderscore(Player *d)
{
	OFString *lag = [OFString stringWithFormat: @"%d", d.lag];
	OFString *name = [OFString stringWithFormat: @"(%@)", d.name];
	OFString *line = [OFString stringWithFormat: @"%d\t%@\t%d\t%@\t%@",
	    d.frags, (d.state == CS_LAGGED ? @"LAG" : lag), d.ping, d.team,
	    (d.state == CS_DEAD ? name : d.name)];

	if (scoreLines == nil)
		scoreLines = [[OFMutableArray alloc] init];

	[scoreLines addObject: line];

	menumanual(0, scoreLines.count - 1, line);
}

#define maxTeams 4
static OFString *teamName[maxTeams];
static int teamScore[maxTeams];
static size_t teamsUsed;

static void
addteamscore(Player *d)
{
	for (size_t i = 0; i < teamsUsed; i++) {
		if ([teamName[i] isEqual: d.team]) {
			teamScore[i] += d.frags;
			return;
		}
	}

	if (teamsUsed == maxTeams)
		return;

	teamName[teamsUsed] = d.team;
	teamScore[teamsUsed++] = d.frags;
}

void
renderscores()
{
	if (!scoreson)
		return;
	[scoreLines removeAllObjects];
	if (!demoplayback)
		renderscore(Player.player1);
	for (Player *player in players)
		if ([player isKindOfClass: Player.class])
			renderscore(player);
	sortmenu();
	if (m_teammode) {
		teamsUsed = 0;
		for (Player *player in players)
			if ([player isKindOfClass: Player.class])
				addteamscore(player);
		if (!demoplayback)
			addteamscore(Player.player1);
		OFMutableString *teamScores = [OFMutableString string];
		for (size_t j = 0; j < teamsUsed; j++)
			[teamScores appendFormat:
			    @"[ %@: %d ]", teamName[j], teamScore[j]];
		menumanual(0, scoreLines.count, @"");
		menumanual(0, scoreLines.count + 1, teamScores);
	}
}

// sendmap/getmap commands, should be replaced by more intuitive map downloading

COMMAND(sendmap, ARG_1STR, (^ (OFString *mapname) {
	if (mapname.length > 0)
		save_world(mapname);
	changemap(mapname);
	mapname = getclientmap();
	OFData *mapdata = readmap(mapname);
	if (mapdata == nil)
		return;
	ENetPacket *packet = enet_packet_create(
	    NULL, MAXTRANS + mapdata.count, ENET_PACKET_FLAG_RELIABLE);
	unsigned char *start = packet->data;
	unsigned char *p = start + 2;
	putint(&p, SV_SENDMAP);
	sendstring(mapname, &p);
	putint(&p, mapdata.count);
	if (65535 - (p - start) < mapdata.count) {
		conoutf(@"map %@ is too large to send", mapname);
		enet_packet_destroy(packet);
		return;
	}
	memcpy(p, mapdata.items, mapdata.count);
	p += mapdata.count;
	*(unsigned short *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	sendpackettoserv(packet);
	conoutf(@"sending map %@ to server...", mapname);
	OFString *msg = [OFString stringWithFormat:
	    @"[map %@ uploaded to server, \"getmap\" to receive it]", mapname];
	toserver(msg);
}))

COMMAND(getmap, ARG_NONE, ^ {
	ENetPacket *packet =
	    enet_packet_create(NULL, MAXTRANS, ENET_PACKET_FLAG_RELIABLE);
	unsigned char *start = packet->data;
	unsigned char *p = start + 2;
	putint(&p, SV_RECVMAP);
	*(unsigned short *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	sendpackettoserv(packet);
	conoutf(@"requesting map from server...");
})
