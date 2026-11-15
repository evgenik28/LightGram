#import "TGLightGramSettingsPages.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

NSArray *TGLightGramDoubleTapActions(bool outgoing)
{
    NSArray *actions = @[@"none", @"reply", @"reaction", @"forward", @"copy", @"translate"];
    return outgoing ? [actions arrayByAddingObject:@"edit"] : actions;
}

NSArray *TGLightGramMenuActionIdentifiers(void)
{
    return @[@"reply", @"copy", @"forward", @"pin", @"copyLink", @"reaction", @"select", @"report"];
}

NSString *TGLightGramMenuActionTitle(NSString *identifier)
{
    return TGLocalized([@"LightGramSettings.Menu." stringByAppendingString:identifier]);
}
