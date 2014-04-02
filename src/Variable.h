#import "Identifier.h"

@interface Variable: Identifier
@property int min, max;
@property void (*fun)();
@property int *storage;
@property int narg;

- (void)assignWithName: (char*)name
		 value: (char*)value
		isDown: (bool)isDown;
@end
