#import <Foundation/Foundation.h>

typedef void (^NineLiveStateHandler)(
    NSString *entityID,
    NSDictionary *newState
);

typedef void (^NineLiveStatusHandler)(BOOL connected);

@interface NineLiveSocket : NSObject

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token
                          onState:(NineLiveStateHandler)onState
                         onStatus:(NineLiveStatusHandler)onStatus;

- (void)start;
- (void)stop;

@end
