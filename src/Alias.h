#import "Identifier.h"

@interface Alias: Identifier
@property (copy) OFString *action;

- (int)executeWithArguments: (char**)arguments
	      argumentCount: (int)argumentCount
		     isDown: (bool)isDown;
@end
