#import <UIKit/UIKit.h>

@interface NineUnstableSettingsController : UITableViewController

- (instancetype)initWithServerURL:(NSString *)serverURL;

+ (NSInteger)intervalForGroup:(NSInteger)group
                    serverURL:(NSString *)serverURL;

+ (NSString *)summaryForServerURL:(NSString *)serverURL;
+ (NSString *)startupModeForServerURL:(NSString *)serverURL;
+ (void)setStartupMode:(NSString *)mode
              serverURL:(NSString *)serverURL;

@end
