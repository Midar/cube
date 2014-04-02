#import <ObjFW/ObjFW.h>

@interface Identifier: OFObject
@property (copy) OFString *name;
@property bool persist;
@end
