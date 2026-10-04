#import <UIKit/UIKit.h>
#import "NineAuth.h"

@interface NineLovelaceActionEngine : NSObject

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

- (void)performCard:(NSDictionary *)card
            gesture:(NSString *)gesture
          presenter:(UIViewController *)presenter;

- (void)setLightBrightness:(NSString *)entity
                percentage:(NSInteger)percentage
                 presenter:(UIViewController *)presenter;

- (void)cancel;

@end
