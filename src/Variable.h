#import "Identifier.h"

@interface Variable: Identifier
@property int min, max;
@property (copy) void (^block)(void);
@property int *storage;
@property int type;

- (void)assignWithName: (char*)name
		 value: (char*)value
		isDown: (bool)isDown;
@end
