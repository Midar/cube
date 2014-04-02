#import <ObjFW/ObjFW.h>

struct md2_header {
	int magic;
	int version;
	int skinWidth, skinHeight;
	int frameSize;
	int numSkins, numVertices, numTexcoords;
	int numTriangles, numGlCommands, numFrames;
	int offsetSkins, offsetTexcoords, offsetTriangles;
	int offsetFrames, offsetGlCommands, offsetEnd;
};

struct md2_vertex {
	uchar vertex[3], lightNormalIndex;
};

struct md2_frame {
	float	   scale[3];
	float	   translate[3];
	char	   name[16];
	md2_vertex vertices[1];
};

@interface MD2: OFObject
{
	int _numGlCommands;
	int *_glCommands;
	int _numTriangles;
	int _frameSize;
	int _numFrames;
	int _numVerts;
	char *_frames;
	vec **_mverts;
	int _displaylist;
	int _displaylistverts;

	bool _loaded;
}

@property (retain, nonatomic) MapModelInfo *mmi;
@property (copy, nonatomic) OFString *loadName;
@property int mdlnum;

+ (instancetype)modelForName: (OFString*)name;
- (void)_loadFile: (OFString*)filename;
- (void)delayedLoad;
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
	       basetime: (int)basetime;
- (void)scaleWithFrame: (int)frame
		 scale: (float)scale
		    sn: (int)sn;
@end
