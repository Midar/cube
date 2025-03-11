#import "MenuItem.h"

@implementation MenuItem
- (instancetype)initWithText:(OFString *)text action:(OFString *)action
{
	self = [super init];

	_text = [text copy];
	_action = [action copy];

	return self;
}

- (OFComparisonResult)compare:(id)otherObject
{
	MenuItem *otherItem;

	if (![otherObject isKindOfClass:MenuItem.class])
		@throw [OFInvalidArgumentException exception];

	int x, y;
	@try {
		x = _text.intValue;
	} @catch (OFInvalidFormatException *e) {
		x = 0;
	}

	@try {
		y = otherItem.text.intValue;
	} @catch (OFInvalidFormatException *e) {
		y = 0;
	}

	if (x > y)
		return OFOrderedAscending;
	if (x < y)
		return OFOrderedDescending;

	return OFOrderedSame;
}
@end
