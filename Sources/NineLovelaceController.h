#import <UIKit/UIKit.h>
#import "NineAuth.h"

@interface NineLovelaceController : UITableViewController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

@end

@interface NineLegacyWebController : UIViewController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

@end
