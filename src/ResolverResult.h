#import <ObjFW/ObjFW.h>

#import "cube.h"

OF_DIRECT_MEMBERS
@interface ResolverResult: OFObject
@property (readonly, nonatomic) OFString *query;
@property (readonly, nonatomic) ENetAddress address;

+ (instancetype)resultWithQuery: (OFString *)query
			address: (ENetAddress)address;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithQuery: (OFString *)query
		      address: (ENetAddress)address OF_DESIGNATED_INITIALIZER;
@end
