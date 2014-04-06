#import "cube.h"

#import "Command.h"

@implementation Command
- (int)executeWithArguments: (char**)w
	      argumentCount: (int)numargs
		     isDown: (bool)isDown
{
	switch (_type) {
	case ARG_1INT:
		if (isDown)
			_block(ATOI(w[1]));
		break;
	case ARG_2INT:
		if (isDown)
			_block(ATOI(w[1]), ATOI(w[2]));
		break;
	case ARG_3INT:
		if (isDown)
			_block(ATOI(w[1]), ATOI(w[2]), ATOI(w[3]));
		break;
	case ARG_4INT:
		if (isDown)
			_block(ATOI(w[1]), ATOI(w[2]), ATOI(w[3]), ATOI(w[4]));
		break;
	case ARG_NONE:
		if (isDown)
			_block();
		break;
	case ARG_1STR:
		if (isDown)
			_block(w[1]);
		break;
	case ARG_2STR:
		if (isDown)
			_block(w[1], w[2]);
		break;
	case ARG_3STR:
		if (isDown)
			_block(w[1], w[2], w[3]);
		break;
	case ARG_5STR:
		if (isDown)
			_block(w[1], w[2], w[3], w[4], w[5]);
		break;
	case ARG_1OSTR:
		if (isDown)
			_block(@(w[1]));
		break;
	case ARG_2OSTR:
		if (isDown)
			_block(@(w[1]), @(w[2]));
		break;
	case ARG_3OSTR:
		if (isDown)
			_block(@(w[1]), @(w[2]), @(w[3]));
		break;
	case ARG_5OSTR:
		if (isDown)
			_block(@(w[1]), @(w[2]), @(w[3]), @(w[4]), @(w[5]));
		break;
	case ARG_DOWN:
		_block(isDown);
		break;
	case ARG_DWN1:
		_block(isDown, w[1]);
		break;
	case ARG_1EXP:
		if (isDown)
			return ((int(^)(int))_block)(execute(w[1], isDown));
		break;
	case ARG_2EXP:
		if (isDown)
			return ((int(^)(int, int))_block)(execute(w[1], isDown),
			    execute(w[2], isDown));
		break;
	case ARG_1EST:
		if (isDown)
			return ((int(^)(const char*))_block)(w[1]);
		break;
	case ARG_2EST:
		if (isDown)
			return ((int(^)(const char*, const char*))_block)(w[1],
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

				((void(^)(const char*))_block)([r UTF8String]);
			}
		}
		break;
	}

	return 0;
}
@end
