#import <UIKit/UIKit.h>

@interface NineLightBrightnessController : UIViewController

@property (nonatomic, copy) NSString *lightName;
@property (nonatomic, assign) NSInteger initialPercent;
@property (nonatomic, copy) void (^onApply)(NSInteger percent);

@end
