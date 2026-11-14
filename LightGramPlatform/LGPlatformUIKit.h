#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGRect LGPlatformKeyboardEndFrame(NSNotification *notification);
FOUNDATION_EXPORT CGRect LGPlatformKeyboardFrameInView(NSNotification *notification, UIView *view);

FOUNDATION_EXPORT void LGPlatformSetExclusiveTouch(UIView *view, BOOL enabled);
FOUNDATION_EXPORT void LGPlatformSetViewRasterization(UIView *view, BOOL enabled, CGFloat scale);
FOUNDATION_EXPORT void LGPlatformSetLayerContentsScale(CALayer *layer, CGFloat scale);

FOUNDATION_EXPORT void LGPlatformApplyLegacySegmentedControlStyle(UISegmentedControl *control, UIColor *tintColor);
FOUNDATION_EXPORT void LGPlatformSetSegmentedControlBackgroundImage(UISegmentedControl *control, UIImage *image, UIControlState state, UIBarMetrics barMetrics);
FOUNDATION_EXPORT void LGPlatformSetSegmentedControlDividerImage(UISegmentedControl *control, UIImage *image, UIControlState leftState, UIControlState rightState, UIBarMetrics barMetrics);
FOUNDATION_EXPORT void LGPlatformSetSegmentedControlTitleTextAttributes(UISegmentedControl *control, NSDictionary *attributes, UIControlState state);

FOUNDATION_EXPORT void LGPlatformPresentActionSheet(UIActionSheet *actionSheet, UIBarButtonItem *barButtonItem, UIView *sourceView, CGRect sourceRect, UIView *fallbackView, BOOL animated);
FOUNDATION_EXPORT void LGPlatformSetPopoverBackgroundColor(id popoverController, UIColor *color);
FOUNDATION_EXPORT void LGPlatformApplyNavigationBarTitleStyle(UINavigationBar *navigationBar, UIColor *textColor, UIColor *shadowColor, CGSize shadowOffset, UIFont *font);

FOUNDATION_EXPORT void LGPlatformSetLabelMinimumScaleFactor(UILabel *label, CGFloat minimumScaleFactor);
FOUNDATION_EXPORT void LGPlatformSetTextFieldSelectionRange(UITextField *textField, NSRange range);
FOUNDATION_EXPORT CGRect LGPlatformTextViewStartCaretRect(UITextView *textView);
FOUNDATION_EXPORT void LGPlatformSetTextFieldInputAccessoryView(UITextField *textField, UIView *accessoryView);
FOUNDATION_EXPORT void LGPlatformSetTextFieldInputView(UITextField *textField, UIView *inputView);
FOUNDATION_EXPORT UIView *LGPlatformTextInputView(id textInput);
FOUNDATION_EXPORT void LGPlatformSetTextInputView(id textInput, UIView *inputView);
FOUNDATION_EXPORT void LGPlatformDisableSpellChecking(id textInput);
FOUNDATION_EXPORT BOOL LGPlatformSuperclassViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, Class currentClass);
FOUNDATION_EXPORT void LGPlatformSetViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, BOOL enabled);
FOUNDATION_EXPORT UIEdgeInsets LGPlatformSuperclassViewAlignmentRectInsets(UIView *view, Class currentClass);
FOUNDATION_EXPORT CGSize LGPlatformViewIntrinsicContentSize(UIView *view);
FOUNDATION_EXPORT void LGPlatformInvalidateViewIntrinsicContentSize(UIView *view);
FOUNDATION_EXPORT void LGPlatformSetTableViewSectionIndexColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT void LGPlatformSetTableViewSectionIndexBackgroundColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT void LGPlatformSetTableViewSectionIndexTrackingBackgroundColor(UITableView *tableView, UIColor *color);
FOUNDATION_EXPORT BOOL LGPlatformSetSwitchColors(UISwitch *switchView, UIColor *onTintColor, UIColor *tintColor);
FOUNDATION_EXPORT void LGPlatformSetSwitchThumbTintColor(UISwitch *switchView, UIColor *color);
FOUNDATION_EXPORT BOOL LGPlatformPresentActivityItems(UIViewController *presenter, NSArray *items, UIView *sourceView, CGRect sourceRect, UIBarButtonItem *barButtonItem, NSUInteger permittedArrowDirections, void (^completion)(void));

FOUNDATION_EXPORT void LGPlatformBeginReceivingRemoteControlEvents(UIApplication *application);
FOUNDATION_EXPORT void LGPlatformEndReceivingRemoteControlEvents(UIApplication *application);
FOUNDATION_EXPORT void LGPlatformSetStatusBarHidden(UIApplication *application, BOOL hidden, NSInteger animation);
typedef NSUInteger LGPlatformBackgroundTaskIdentifier;
#define LGPlatformBackgroundTaskInvalid ((LGPlatformBackgroundTaskIdentifier)-1)
FOUNDATION_EXPORT LGPlatformBackgroundTaskIdentifier LGPlatformBeginBackgroundTask(UIApplication *application, void (^expirationHandler)(void));
FOUNDATION_EXPORT void LGPlatformEndBackgroundTask(UIApplication *application, LGPlatformBackgroundTaskIdentifier identifier);
FOUNDATION_EXPORT BOOL LGPlatformViewControllerIsTransitioning(UIViewController *viewController);
FOUNDATION_EXPORT NSArray *LGPlatformChildViewControllers(UIViewController *viewController);
FOUNDATION_EXPORT BOOL LGPlatformAccessibilityInvertColorsEnabled(void);
FOUNDATION_EXPORT void LGPlatformHideAccessibilityElements(UIView *view);
FOUNDATION_EXPORT BOOL LGPlatformSupportsModernLoginIntro(void);
FOUNDATION_EXPORT BOOL LGPlatformControlAnimationsEnabled(void);
FOUNDATION_EXPORT BOOL LGPlatformTransientAnimationsEnabled(void);
FOUNDATION_EXPORT void LGPlatformInstallUIKitGuards(void);
FOUNDATION_EXPORT NSURL *LGPlatformBundleResourceURL(NSBundle *bundle, NSString *name, NSString *extension);
FOUNDATION_EXPORT void LGPlatformConfigureWebViewMediaPlayback(id webView, BOOL allowsInlinePlayback, BOOL requiresUserAction);

typedef NSInteger LGPlatformMessageComposeResult;
enum
{
    LGPlatformMessageComposeResultCancelled = 0,
    LGPlatformMessageComposeResultSent = 1,
    LGPlatformMessageComposeResultFailed = 2
};

FOUNDATION_EXPORT BOOL LGPlatformCanSendTextMessage(void);
FOUNDATION_EXPORT id LGPlatformCreateTextMessageComposer(id delegate, NSArray *recipients, NSString *body);
FOUNDATION_EXPORT NSArray *LGPlatformTextMessageComposerRecipients(id composer);
FOUNDATION_EXPORT NSString *LGPlatformTextMessageComposerBody(id composer);
FOUNDATION_EXPORT BOOL LGPlatformOpenTextMessage(NSArray *recipients);

FOUNDATION_EXPORT id LGPlatformCreateLocalNotification(void);
FOUNDATION_EXPORT id LGPlatformLocalNotificationFromLaunchOptions(NSDictionary *launchOptions);
FOUNDATION_EXPORT NSDictionary *LGPlatformLocalNotificationUserInfo(id notification);
FOUNDATION_EXPORT NSString *LGPlatformLocalNotificationSoundName(id notification);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationFireDate(id notification, NSDate *fireDate);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationAlertBody(id notification, NSString *alertBody);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationSoundName(id notification, NSString *soundName);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationUserInfo(id notification, NSDictionary *userInfo);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationCategory(id notification, NSString *category);
FOUNDATION_EXPORT void LGPlatformSetLocalNotificationAlertTitle(id notification, NSString *alertTitle);
FOUNDATION_EXPORT NSString *LGPlatformDefaultLocalNotificationSoundName(void);
FOUNDATION_EXPORT void LGPlatformPresentLocalNotificationNow(UIApplication *application, id notification);
FOUNDATION_EXPORT BOOL LGPlatformSetBackgroundFetchEnabled(UIApplication *application, BOOL enabled);
FOUNDATION_EXPORT void LGPlatformScheduleLocalNotification(UIApplication *application, id notification);
FOUNDATION_EXPORT void LGPlatformCancelLocalNotification(UIApplication *application, id notification);
FOUNDATION_EXPORT NSArray *LGPlatformScheduledLocalNotifications(UIApplication *application);
FOUNDATION_EXPORT void LGPlatformCancelAllLocalNotifications(UIApplication *application);
FOUNDATION_EXPORT id LGPlatformCreateUserNotificationAction(NSString *identifier, NSString *title, BOOL destructive, BOOL authenticationRequired, BOOL foreground, BOOL textInput);
FOUNDATION_EXPORT id LGPlatformCreateUserNotificationCategory(NSString *identifier, NSArray *defaultActions, NSArray *minimalActions);
FOUNDATION_EXPORT BOOL LGPlatformUserNotificationSettingsSupported(UIApplication *application);
FOUNDATION_EXPORT BOOL LGPlatformRegisterUserNotificationSettings(UIApplication *application, NSArray *categories);
