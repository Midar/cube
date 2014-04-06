#import "cube.h"

#import "Variable.h"

@implementation Variable
- (void)assignWithName: (char*)c
		 value: (char*)w
		isDown: (bool)isDown
{
	if (!isDown)
		return;

	if (w[0] == 0)
		// var with no value just prints its current value
		conoutf("%s = %d", c, *_storage);
	else {
		if (_min > _max)
			conoutf("variable is read-only");
		else {
			int i1 = ATOI(w);

			if (i1 < _min || i1 > _max) {
				// clamp to valid range
				i1 = i1 < _min ? _min : _max;
				conoutf("valid range for %s is %d..%d",
				    c, _min, _max);
			}

			*_storage = i1;
		}

		if (_block != NULL)
			// call trigger function if available
			_block();
	}
}
@end
