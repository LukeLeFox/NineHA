#import <UIKit/UIKit.h>
#import "NineAuth.h"

/*
 * Dashboard principale di NineHA: ricostruisce in UIKit la
 * panoramica per stanze dell'app ufficiale Home Assistant
 * (badge, sezioni per area, tile card e pannello dettagli).
 */
@interface NineHomeDashboard : UIViewController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode;

@end
