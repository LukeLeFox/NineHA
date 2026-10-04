#import <UIKit/UIKit.h>
#import "NineAuth.h"

@interface NineTilesController : UITableViewController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

@end
