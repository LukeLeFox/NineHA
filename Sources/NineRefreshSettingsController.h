#import <UIKit/UIKit.h>

extern NSString *const NineRefreshSettingsChangedNotification;

@interface NineRefreshSettingsController : UITableViewController

// 0 = Live (eventi WebSocket), altrimenti secondi tra le letture REST.
+ (NSInteger)entityIntervalForServerURL:(NSString *)serverURL;

- (instancetype)initWithServerURL:(NSString *)serverURL;

@end
