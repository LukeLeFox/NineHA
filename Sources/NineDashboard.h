#import <UIKit/UIKit.h>
#import "NineAuth.h"

@interface NineDashboard : UITableViewController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

@end
