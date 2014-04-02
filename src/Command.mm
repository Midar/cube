#import "cube.h"

#import "Command.h"

@implementation Command
- (int)executeWithArguments: (char**)w
	      argumentCount: (int)numargs
		     isDown: (bool)isDown
{
	// use very ad-hoc function signature, and just call it
	switch (_narg) {
	case ARG_1INT:
		if (isDown)
			((void(*)(int))_fun)(ATOI(w[1]));
		break;
	case ARG_2INT:
		if (isDown)
			((void(*)(int, int))_fun)(ATOI(w[1]), ATOI(w[2]));
		break;
	case ARG_3INT:
		if (isDown)
			((void(*)(int, int, int))_fun)(ATOI(w[1]), ATOI(w[2]),
			    ATOI(w[3]));
		break;
	case ARG_4INT:
		if (isDown)
			((void(*)(int, int, int, int))_fun)(ATOI(w[1]),
			    ATOI(w[2]), ATOI(w[3]), ATOI(w[4]));
		break;
	case ARG_NONE:
		if (isDown)
			_fun();
		break;
	case ARG_1STR:
		if (isDown)
			((void(*)(const char*))_fun)(w[1]);
		break;
	case ARG_2STR:
		if (isDown)
			((void(*)(const char*, const char*))_fun)(w[1], w[2]);
		break;
	case ARG_3STR:
		if (isDown)
			((void(*)(const char*, const char*, const char*))_fun)(
			    w[1], w[2], w[3]);
		break;
	case ARG_5STR:
		if (isDown)
			((void(*)(const char*, const char *, const char*,
			    const char*, const char*))_fun)(w[1], w[2], w[3],
			     w[4], w[5]);
		break;
	case ARG_1OSTR:
		if (isDown)
			((void(*)(OFString*))_fun)(@(w[1]));
		break;
	case ARG_2OSTR:
		if (isDown)
			((void(*)(OFString*, OFString*))_fun)(@(w[1]),
			    @(w[2]));
		break;
	case ARG_3OSTR:
		if (isDown)
			((void(*)(OFString*, OFString*, OFString*))_fun)(
			    @(w[1]), @(w[2]), @(w[3]));
		break;
	case ARG_5OSTR:
		if (isDown)
			((void(*)(OFString*, OFString*, OFString*, OFString*,
			    OFString*))_fun)(@(w[1]), @(w[2]), @(w[3]),
			    @(w[4]), @(w[5]));
		break;
	case ARG_DOWN:
		((void(*)(bool))_fun)(isDown);
		break;
	case ARG_DWN1:
		((void(*)(bool, const char*))_fun)(isDown, w[1]);
		break;
	case ARG_1EXP:
		if (isDown)
			return ((int(*)(int))_fun)(execute(w[1], isDown));
		break;
	case ARG_2EXP:
		if (isDown)
			return ((int(*)(int, int))_fun)(execute(w[1], isDown),
			    execute(w[2], isDown));
		break;
	case ARG_1EST:
		if (isDown)
			return ((int(*)(const char*))_fun)(w[1]);
		break;
	case ARG_2EST:
		if (isDown)
			return ((int(*)(const char*, const char*))_fun)(w[1],
			    w[2]);
		break;
	case ARG_VARI:
		if (isDown) {
			@autoreleasepool {
				OFMutableString *r = [OFMutableString string];

				for (int i = 1; i < numargs; i++) {
					// make string-list out of all arguments
					[r appendUTF8String: w[i]];

					if (i == numargs - 1)
						break;

					[r appendString: @" "];
				}

				((void(*)(const char*))_fun)([r UTF8String]);
			}
		}
		break;
	}

	return 0;
}
@end
