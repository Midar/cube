// worldlight.cpp

#include "cube.h"

#import "DynamicEntity.h"
#import "Entity.h"
#import "Monster.h"
#import "Variable.h"

extern bool hasoverbright;

VAR(lightscale, 1, 4, 100);

// done in realtime, needs to be fast
void
lightray(float bx, float by, Entity *light)
{
	float lx = light.x + (rnd(21) - 10) * 0.1f;
	float ly = light.y + (rnd(21) - 10) * 0.1f;
	float dx = bx - lx;
	float dy = by - ly;
	float dist = (float)sqrt(dx * dx + dy * dy);
	if (dist < 1.0f)
		return;
	int reach = light.attr1;
	int steps = (int)(reach * reach * 1.6f /
	    dist); // can change this for speedup/quality?
	const int PRECBITS = 12;
	const float PRECF = 4096.0f;
	int x = (int)(lx * PRECF);
	int y = (int)(ly * PRECF);
	int l = light.attr2 << PRECBITS;
	int stepx = (int)(dx / (float)steps * PRECF);
	int stepy = (int)(dy / (float)steps * PRECF);
	// incorrect: light will fade quicker if near edge of the world
	int stepl = l / (float)steps;

	if (hasoverbright) {
		l /= lightscale;
		stepl /= lightscale;

		// coloured light version, special case because most lights are
		// white
		if (light.attr3 || light.attr4) {
			int dimness = rnd((255 - (light.attr2 + light.attr3 +
			    light.attr4) / 3) / 16 + 1);
			x += stepx * dimness;
			y += stepy * dimness;

			if (OUTBORD(x >> PRECBITS, y >> PRECBITS))
				return;

			int g = light.attr3 << PRECBITS;
			int stepg = g / (float)steps;
			int b = light.attr4 << PRECBITS;
			int stepb = b / (float)steps;
			g /= lightscale;
			stepg /= lightscale;
			b /= lightscale;
			stepb /= lightscale;
			for (int i = 0; i < steps; i++) {
				struct sqr *s = S(x >> PRECBITS, y >> PRECBITS);
				int tl = (l >> PRECBITS) + s->r;
				s->r = tl > 255 ? 255 : tl;
				tl = (g >> PRECBITS) + s->g;
				s->g = tl > 255 ? 255 : tl;
				tl = (b >> PRECBITS) + s->b;
				s->b = tl > 255 ? 255 : tl;
				if (SOLID(s))
					return;
				x += stepx;
				y += stepy;
				l -= stepl;
				g -= stepg;
				b -= stepb;
				stepl -= 25;
				stepg -= 25;
				stepb -= 25;
			}
		} else // white light, special optimized version
		{
			int dimness = rnd((255 - light.attr2) / 16 + 1);
			x += stepx * dimness;
			y += stepy * dimness;

			if (OUTBORD(x >> PRECBITS, y >> PRECBITS))
				return;

			for (int i = 0; i < steps; i++) {
				struct sqr *s = S(x >> PRECBITS, y >> PRECBITS);
				int tl = (l >> PRECBITS) + s->r;
				s->r = s->g = s->b = tl > 255 ? 255 : tl;
				if (SOLID(s))
					return;
				x += stepx;
				y += stepy;
				l -= stepl;
				stepl -= 25;
			}
		}
	} else // the old (white) light code, here for the few people with old
	       // video cards that don't support overbright
	{
		for (int i = 0; i < steps; i++) {
			struct sqr *s = S(x >> PRECBITS, y >> PRECBITS);
			int light = l >> PRECBITS;
			if (light > s->r)
				s->r = s->g = s->b = (unsigned char)light;
			if (SOLID(s))
				return;
			x += stepx;
			y += stepy;
			l -= stepl;
		}
	}
}

void
calclightsource(Entity *l)
{
	int reach = l.attr1;
	int sx = l.x - reach;
	int ex = l.x + reach;
	int sy = l.y - reach;
	int ey = l.y + reach;

	rndreset();

	const float s = 0.8f;

	for (float sx2 = (float)sx; sx2 <= ex; sx2 += s * 2) {
		lightray(sx2, (float)sy, l);
		lightray(sx2, (float)ey, l);
	}
	for (float sy2 = sy + s; sy2 <= ey - s; sy2 += s * 2) {
		lightray((float)sx, sy2, l);
		lightray((float)ex, sy2, l);
	}

	rndtime();
}

// median filter, smooths out random noise in light and makes it more mipable
void
postlightarea(const struct block *a)
{
	// assumes area not on edge of world
	for (int x = 0; x < a->xs; x++) {
		for (int y = 0; y < a->ys; y++) {
			struct sqr *s = S(x + a->x, y + a->y);

			// median is 4/2/1 instead
#define median(m)							 \
	s->m = (s->m * 2 + SW(s, 1, 0)->m * 2 + SW(s, 0, 1)->m * 2 +	 \
	    SW(s, -1, 0)->m * 2 + SW(s, 0, -1)->m * 2 + SW(s, 1, 1)->m + \
	    SW(s, 1, -1)->m + SW(s, -1, 1)->m + SW(s, -1, -1)->m) / 14;
			median(r);
			median(g);
			median(b);
		}
	}

	remip(a, 0);
}

void
calclight()
{
	for (int x = 0; x < ssize; x++) {
		for (int y = 0; y < ssize; y++) {
			struct sqr *s = S(x, y);
			s->r = s->g = s->b = 10;
		}
	}

	for (Entity *e in ents)
		if (e.type == LIGHT)
			calclightsource(e);

	struct block b = { 1, 1, ssize - 2, ssize - 2 };
	postlightarea(&b);
	setvar(@"fullbright", 0);
}

VARP(dynlight, 0, 16, 32);

static OFMutableData *dlights;

void
cleardlights()
{
	while (dlights.count > 0) {
		struct block *backup = *(struct block **)[dlights lastItem];
		[dlights removeLastItem];
		blockpaste(backup);
		OFFreeMemory(backup);
	}
}

void
dodynlight(OFVector3D vold, OFVector3D v, int reach, int strength,
    DynamicEntity *owner)
{
	if (!reach)
		reach = dynlight;
	if ([owner isKindOfClass: Monster.class])
		reach = reach / 2;
	if (!reach)
		return;
	if (v.x < 0 || v.y < 0 || v.x > ssize || v.y > ssize)
		return;

	int creach = reach + 16; // dependant on lightray random offsets!
	struct block b = { (int)v.x - creach, (int)v.y - creach, creach * 2 + 1,
		creach * 2 + 1 };

	if (b.x < 1)
		b.x = 1;
	if (b.y < 1)
		b.y = 1;
	if (b.xs + b.x > ssize - 2)
		b.xs = ssize - 2 - b.x;
	if (b.ys + b.y > ssize - 2)
		b.ys = ssize - 2 - b.y;

	if (dlights == nil)
		dlights = [[OFMutableData alloc]
		    initWithItemSize: sizeof(struct block *)];

	// backup area before rendering in dynlight
	struct block *copy = blockcopy(&b);
	[dlights addItem: &copy];

	Entity *l = [Entity entity];
	l.x = v.x;
	l.y = v.y;
	l.z = v.z;
	l.attr1 = reach;
	l.type = LIGHT;
	l.attr2 = strength;
	calclightsource(l);
	postlightarea(&b);
}

// utility functions also used by editing code

struct block *
blockcopy(const struct block *s)
{
	struct block *b = OFAllocZeroedMemory(
	    1, sizeof(struct block) + s->xs * s->ys * sizeof(struct sqr));
	*b = *s;
	struct sqr *q = (struct sqr *)(b + 1);
	for (int x = s->x; x < s->xs + s->x; x++)
		for (int y = s->y; y < s->ys + s->y; y++)
			*q++ = *S(x, y);
	return b;
}

void
blockpaste(const struct block *b)
{
	struct sqr *q = (struct sqr *)(b + 1);
	for (int x = b->x; x < b->xs + b->x; x++)
		for (int y = b->y; y < b->ys + b->y; y++)
			*S(x, y) = *q++;
	remipmore(b, 0);
}
