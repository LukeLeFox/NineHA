#import <Foundation/Foundation.h>

typedef void (^NineAuthCompletion)(
    NSString *token,
    NSError *error
);

@interface NineAuth : NSObject
@property (nonatomic, assign, readonly) NSInteger lastKeychainStatus;

@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *clientID;

- (BOOL)saveManualToken:(NSString *)token;
- (BOOL)hasManualToken;
- (BOOL)hasOAuthSession;

- (NSURL *)authorizationURL;
- (void)handleCallbackURL:(NSURL *)url
              completion:(NineAuthCompletion)completion;

- (void)useManualToken:(NineAuthCompletion)completion;
- (void)useOAuthToken:(NineAuthCompletion)completion;

@end


// HTTP consentito esclusivamente su indirizzi IPv4 privati.
// HTTPS continua a essere supportato normalmente.

#import <arpa/inet.h>

static inline BOOL NineHAAllowedServerURL(NSURLComponents *c) {

    if (!c || !c.host.length ||
        c.user.length || c.password.length ||
        c.query.length || c.fragment.length ||
        c.path.length) {
        return NO;
    }

    NSString *scheme = c.scheme.lowercaseString;

    if ([scheme isEqualToString:@"https"]) {
        return YES;
    }

    if (![scheme isEqualToString:@"http"]) {
        return NO;
    }

    struct in_addr address;

    if (inet_pton(AF_INET, c.host.UTF8String, &address) != 1) {
        return NO;
    }

    uint32_t ip = ntohl(address.s_addr);

    // 10.0.0.0/8
    if ((ip & 0xFF000000U) == 0x0A000000U)
        return YES;

    // 172.16.0.0/12
    if ((ip & 0xFFF00000U) == 0xAC100000U)
        return YES;

    // 192.168.0.0/16
    if ((ip & 0xFFFF0000U) == 0xC0A80000U)
        return YES;

    return NO;
}
