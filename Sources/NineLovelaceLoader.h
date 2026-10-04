#import <Foundation/Foundation.h>

/*
 * NineHA Lovelace Loader
 * iOS 9 / Objective-C / ARMv7
 *
 * Completion:
 * - Dashboard list: NSArray
 * - Configuration: NSDictionary
 *
 * Il callback viene eseguito sul thread principale.
 */

typedef void (^NineLovelaceCompletion)(
    id result,
    NSError *error
);

@interface NineLovelaceLoader : NSObject

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token;

- (void)loadDashboardsWithCompletion:
    (NineLovelaceCompletion)completion;

- (void)loadConfigurationForPath:(NSString *)path
                      completion:(NineLovelaceCompletion)completion;

- (void)cancel;

@end
