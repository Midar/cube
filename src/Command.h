#import "Identifier.h"

// function signatures for script functions, see Command.mm
enum {
	ARG_1INT, ARG_2INT, ARG_3INT, ARG_4INT,
	ARG_NONE,
	ARG_1STR, ARG_2STR, ARG_3STR, ARG_5STR,
	ARG_1OSTR, ARG_2OSTR, ARG_3OSTR, ARG_5OSTR,
	ARG_DOWN, ARG_DWN1,
	ARG_1EXP, ARG_2EXP,
	ARG_1EST, ARG_2EST,
	ARG_VARI
};

@interface Command: Identifier
@property void (*fun)();
@property int narg;

- (int)executeWithArguments: (char**)arguments
	      argumentCount: (int)argumentCount
		     isDown: (bool)isDown;
@end
