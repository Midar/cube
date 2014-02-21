// rendermd2.cpp: loader code adapted from a nehe tutorial

#include "cube.h"

#import "MD2.h"

static OFMutableDictionary *mdllookup = nil;
static OFMutableArray *mapmodels = nil;
static const int FIRSTMDL = 20;
static int modelnum = 0;

static float
snap(int sn, float f)
{
	return (sn ? (float)(((int)(f + sn * 0.5f)) & (~(sn - 1))) : f);
}

@implementation MD2
@synthesize mmi = _mmi;
@synthesize loadName = _loadName;
@synthesize mdlnum = _mdlnum;

+ (instancetype)modelForName: (OFString*)name
{
	MD2 *model;

	if (mdllookup == nil)
		mdllookup = [OFMutableDictionary new];

	if ((model = mdllookup[name]) != nil)
		return model;

	model = [MD2 new];
	model.mdlnum = modelnum++;
	model.loadName = name;

	MapModelInfo *mmi = [MapModelInfo new];
	mmi.rad = mmi.h = 2;
	mmi.zoff = mmi.snap = 0;
	mmi.name = @"";
	model.mmi = mmi;

	mdllookup[name] = model;

	return model;
}

- init
{
	self = [super init];

	_mmi = [MapModelInfo new];

	return self;
}

- (void)_loadFile: (OFString*)filename
{
	OFFile *file = [OFFile fileWithPath: filename
				       mode: @"rb"];

	md2_header header;
	[file readIntoBuffer: &header
		 exactLength: sizeof(md2_header)];
	endianswap(&header, sizeof(int), sizeof(md2_header) / sizeof(int));

	if (header.magic != 844121161)
		@throw [OFInvalidFormatException exception];

	if (header.version != 8) {
		OFString *version = [OFString stringWithFormat: @"%d",
								header.version];

		@throw [OFUnsupportedVersionException
		    exceptionWithVersion: version];
	}

	_frames = (char*)[self allocMemoryWithSize: header.frameSize
					     count: header.numFrames];

	[file seekToOffset: header.offsetFrames
		    whence: SEEK_SET];
	[file readIntoBuffer: _frames
		 exactLength: header.frameSize * header.numFrames];

	for (int i = 0; i < header.numFrames; ++i)
		endianswap(_frames + i * header.frameSize, sizeof(float), 6);

	_glCommands = (int*)[self allocMemoryWithSize: sizeof(int)
						count: header.numGlCommands];

	[file seekToOffset: header.offsetGlCommands
		    whence: SEEK_SET];
	[file readIntoBuffer: _glCommands
		 exactLength: header.numGlCommands * sizeof(int)];

	endianswap(_glCommands, sizeof(int), header.numGlCommands);

	_numFrames     = header.numFrames;
	_numGlCommands = header.numGlCommands;
	_frameSize     = header.frameSize;
	_numTriangles  = header.numTriangles;
	_numVerts      = header.numVertices;

	_mverts = (vec**)[self allocMemoryWithSize: sizeof(vec*)
					     count: _numFrames];
	loopj(_numFrames) _mverts[j] = NULL;

	[file close];
}

- (void)delayedLoad
{
	OFString *name1, *name2;
	int xs, ys;

	if (_loaded)
		return;

	name1 = [OFString pathWithComponents:
	    @[ @"packages", @"models", _loadName, @"tris.md2" ]];

	@try {
		[self _loadFile: name1];
	} @catch (id e) {
		[Cube fatalError:
		    [@"loadmodel: " stringByAppendingString: name1]];
	}

	name2 = [OFString pathWithComponents:
	    @[ @"packages", @"models", _loadName, @"skin.jpg" ]];

	installtex(FIRSTMDL + _mdlnum, [name2 UTF8String], xs, ys);
	_loaded = true;
}

- (void)scaleWithFrame: (int)frame
		 scale: (float)scale
		    sn: (int)sn
{
	_mverts[frame] = (vec*)[self allocMemoryWithSize: sizeof(vec)
						   count: _numVerts];
	md2_frame *cf = (md2_frame *) ((char*)_frames + _frameSize * frame);
	float sc = 16.0f / scale;

	loop(vi, _numVerts) {
		uchar *cv = (uchar *)&cf->vertices[vi].vertex;
		vec *v = &(_mverts[frame])[vi];
		v->x =  (snap(sn, cv[0]*cf->scale[0]) + cf->translate[0]) / sc;
		v->y = -(snap(sn, cv[1]*cf->scale[1]) + cf->translate[1]) / sc;
		v->z =  (snap(sn, cv[2]*cf->scale[2]) + cf->translate[2]) / sc;
	}
}

- (void)renderWithLight: (vec&)light
		  frame: (int)frame
		  range: (int)range
		      x: (float)x
		      y: (float)y
		      z: (float)z
		    yaw: (float)yaw
		  pitch: (float)pitch
		  scale: (float)scale
		  speed: (float)speed
		   snap: (int)snap
	       basetime: (int)basetime
{
	loopi(range)
		if(!_mverts[frame+i])
			[self scaleWithFrame: frame + i
				       scale: scale
					  sn: snap];

	glPushMatrix();
	glTranslatef(x, y, z);
	glRotatef(yaw+180, 0, -1, 0);
	glRotatef(pitch, 0, 0, 1);

	glColor3fv((float *)&light);

	if (_displaylist && frame == 0 && range == 1) {
		glCallList(_displaylist);
		xtraverts += _displaylistverts;
	} else {
		if (frame == 0 && range == 1) {
			static int displaylistn = 10;
			glNewList(_displaylist = displaylistn++, GL_COMPILE);
			_displaylistverts = xtraverts;
		}

		int time = lastmillis - basetime;
		int fr1 = (int)(time / speed);
		float frac1 = (time - fr1 * speed) / speed;
		float frac2 = 1 - frac1;
		fr1 = fr1 % range + frame;
		int fr2 = fr1 + 1;
		if (fr2 >= frame + range) fr2 = frame;
		vec *verts1 = _mverts[fr1];
		vec *verts2 = _mverts[fr2];

		for (int *command = _glCommands; (*command) != 0;) {
			int numVertex = *command++;
			if (numVertex > 0)
				glBegin(GL_TRIANGLE_STRIP);
			else {
				glBegin(GL_TRIANGLE_FAN);
				numVertex = -numVertex;
			}

			loopi(numVertex) {
				float tu = *((float*)command++);
				float tv = *((float*)command++);
				glTexCoord2f(tu, tv);
				int vn = *command++;
				vec &v1 = verts1[vn];
				vec &v2 = verts2[vn];
				#define ip(c) (v1.c * frac2 + v2.c * frac1)
				glVertex3f(ip(x), ip(z), ip(y));
			}

			xtraverts += numVertex;

			glEnd();
		}

		if (_displaylist) {
			glEndList();
			_displaylistverts = xtraverts - _displaylistverts;
		}
	}

	glPopMatrix();
}
@end

@implementation MapModelInfo
@synthesize rad = _rad;
@synthesize h = _h;
@synthesize zoff = _zoff;
@synthesize snap = _snap;
@synthesize name = _name;
@end

void
mapmodel(OFString *rad, OFString *h, OFString *zoff, OFString *snap,
    OFString *name)
{
	@autoreleasepool {
		MD2 *model = [MD2 modelForName: name];

		MapModelInfo *mmi = [MapModelInfo new];
		mmi.rad = [rad decimalValue];
		mmi.h = [h decimalValue];
		mmi.zoff = [zoff decimalValue];
		mmi.snap = [snap decimalValue];
		mmi.name = model.loadName;
		model.mmi = mmi;

		[mapmodels addObject: model];
	}
}

void
mapmodelreset()
{
	[mapmodels removeAllObjects];
}

MapModelInfo*
getmminfo(int i)
{
	if (i < mapmodels.count)
		return [mapmodels[i] mmi];

	return (MapModelInfo*)0;
}

void
rendermodel(OFString *mdl, int frame, int range, int tex, float rad, float x,
    float y, float z, float yaw, float pitch, bool teammate, float scale,
    float speed, int snap, int basetime)
{
	@autoreleasepool {
		MD2 *m = [MD2 modelForName: mdl];

		if (isoccluded(player1->o.x, player1->o.y, x-rad, z-rad,
		    rad * 2))
			return;

		[m delayedLoad];

		int xs, ys;
		glBindTexture(GL_TEXTURE_2D,
		    tex ? lookuptexture(tex, xs, ys) : FIRSTMDL + m.mdlnum);

		int ix = (int)x;
		int iy = (int)z;
		vec light = { 1.0f, 1.0f, 1.0f };

		if (!OUTBORD(ix, iy)) {
			sqr *s = S(ix, iy);
			float ll = 256.0f; // 0.96f;
			float of = 0.0f; // 0.1f;
			light.x = s->r / ll + of;
			light.y = s->g / ll + of;
			light.z = s->b / ll + of;
		}

		if (teammate) {
			light.x *= 0.6f;
			light.y *= 0.7f;
			light.z *= 1.2f;
		}

		[m renderWithLight: light
			     frame: frame
			     range: range
				 x: x
				 y: y
				 z: z
			       yaw: yaw
			     pitch: pitch
			     scale: scale
			     speed: speed
			      snap: snap
			  basetime: basetime];
	}
}

void
init_MD2()
{
	COMMAND(mapmodel, ARG_5OSTR);
	COMMAND(mapmodelreset, ARG_NONE);
}
