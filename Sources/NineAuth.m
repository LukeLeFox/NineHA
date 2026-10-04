
#import "NineAuth.h"
#import <Security/Security.h>

static NSString *const NAService = @"org.nineha.client.auth";

static NSError *NAError(NSString *message) {
    return [NSError errorWithDomain:@"NineHA.Auth"
                               code:1
                           userInfo:@{
        NSLocalizedDescriptionKey: message ?: @"Errore sconosciuto"
    }];
}

static void NAComplete(NineAuthCompletion cb,
                       NSString *token, NSError *error) {
    if (!cb) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        cb(token, error);
    });
}

static NSString *NAEncode(NSString *value) {
    NSCharacterSet *allowed = [NSCharacterSet
        characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
         "0123456789-._~"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

@interface NineAuth ()
@property (nonatomic, assign, readwrite) NSInteger lastKeychainStatus;
@property (nonatomic, copy) NSString *cachedOAuthToken;
@property (nonatomic, strong) NSDate *oauthExpiry;
@end

@implementation NineAuth

- (NSString *)baseURL {
    NSString *s = [self.serverURL
        stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSURLComponents *c = [NSURLComponents componentsWithString:s];

    if (!NineHAAllowedServerURL(c)) {
        return nil;
    }

    while ([s hasSuffix:@"/"]) {
        s = [s substringToIndex:s.length - 1];
    }
    return s;
}

- (NSString *)accountForKind:(NSString *)kind {
    NSString *base = [self baseURL];
    if (!base) return nil;
    if ([kind isEqualToString:@"oauth"]) {
        if (!self.clientID.length) return nil;
        return [NSString stringWithFormat:@"%@|oauth|%@",
                base, self.clientID];
    }
    return [base stringByAppendingString:@"|manual"];
}

- (NSMutableDictionary *)keychainQuery:(NSString *)kind {
    NSString *account = [self accountForKind:kind];
    if (!account) return nil;

    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: NAService,
        (__bridge id)kSecAttrAccount: account
    } mutableCopy];
}

- (BOOL)storeSecret:(NSString *)secret kind:(NSString *)kind {
    NSMutableDictionary *query = [self keychainQuery:kind];
    if (!query || !secret.length) return NO;

    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *add = [query mutableCopy];
    add[(__bridge id)kSecValueData] = data;
    add[(__bridge id)kSecAttrAccessible] =
        (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);

    if (status == errSecDuplicateItem) {
        status = SecItemUpdate(
            (__bridge CFDictionaryRef)query,
            (__bridge CFDictionaryRef)@{
                (__bridge id)kSecValueData: data
            });
    }
    self.lastKeychainStatus = status;
    return status == errSecSuccess;
}

- (NSString *)readSecret:(NSString *)kind {
    NSMutableDictionary *q = [self keychainQuery:kind];
    if (!q) return nil;

    q[(__bridge id)kSecReturnData] = @YES;
    q[(__bridge id)kSecMatchLimit] =
        (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching(
        (__bridge CFDictionaryRef)q, &result);

    if (status != errSecSuccess || !result) return nil;

    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data
                                encoding:NSUTF8StringEncoding];
}

- (BOOL)saveManualToken:(NSString *)token {
    NSString *clean = [token stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [self storeSecret:clean kind:@"manual"];
}

- (BOOL)hasManualToken {
    return [self readSecret:@"manual"].length > 0;
}

- (BOOL)hasOAuthSession {
    return [self readSecret:@"oauth"].length > 0;
}

- (void)useManualToken:(NineAuthCompletion)completion {
    NSString *token = [self readSecret:@"manual"];
    NAComplete(completion, token,
        token.length ? nil : NAError(@"Token manuale non presente"));
}

- (void)tokenRequest:(NSDictionary *)fields
          completion:(void (^)(NSDictionary *, NSError *))completion {

    NSString *base = [self baseURL];
    if (!base) {
        NAComplete(^(NSString *unused, NSError *error) {
            completion(nil, error);
        }, nil, NAError(@"Serve un indirizzo HTTPS valido"));
        return;
    }

    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in fields) {
        [pairs addObject:[NSString stringWithFormat:@"%@=%@",
            NAEncode(key), NAEncode([fields[key] description])]];
    }

    NSString *body = [pairs componentsJoinedByString:@"&"];
    NSURL *url = [NSURL URLWithString:
                  [base stringByAppendingString:@"/auth/token"]];

    NSMutableURLRequest *req =
        [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 20;
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    [req setValue:@"application/x-www-form-urlencoded"
forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession]
      dataTaskWithRequest:req
      completionHandler:^(NSData *data, NSURLResponse *response,
                          NSError *error) {
        NSInteger status =
            [(NSHTTPURLResponse *)response statusCode];

        NSDictionary *json = nil;
        if (data.length) {
            id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:nil];
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                json = parsed;
            }
        }

        NSError *failure = error;
        if (!failure && status != 200) {
            NSString *description = json[@"error_description"];
            if (![description isKindOfClass:[NSString class]]) {
                description = [NSString stringWithFormat:
                               @"Errore HTTP %ld", (long)status];
            }
            failure = NAError(description);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(json, failure);
        });
    }] resume];
}

- (NSURL *)authorizationURL {
    NSString *base = [self baseURL];
    NSURLComponents *client =
        [NSURLComponents componentsWithString:self.clientID];

    if (!base || ![client.scheme.lowercaseString
                   isEqualToString:@"https"] || !client.host.length) {
        return nil;
    }

    uint8_t bytes[16];
    if (SecRandomCopyBytes(kSecRandomDefault,
                           sizeof(bytes), bytes) != errSecSuccess) {
        return nil;
    }

    NSMutableString *state = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) {
        [state appendFormat:@"%02x", bytes[i]];
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:state forKey:@"NineHA.PendingState"];
    [d setObject:base forKey:@"NineHA.PendingServer"];
    [d setObject:self.clientID forKey:@"NineHA.PendingClient"];
    [d setObject:@([[NSDate date] timeIntervalSince1970])
         forKey:@"NineHA.PendingTime"];
    [d synchronize];

    NSURLComponents *url = [NSURLComponents componentsWithString:
        [base stringByAppendingString:@"/auth/authorize"]];

    url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"response_type"
                                   value:@"code"],
        [NSURLQueryItem queryItemWithName:@"client_id"
                                   value:self.clientID],
        [NSURLQueryItem queryItemWithName:@"redirect_uri"
                                   value:@"nineha://auth"],
        [NSURLQueryItem queryItemWithName:@"state"
                                   value:state]
    ];

    return url.URL;
}

- (void)handleCallbackURL:(NSURL *)url
               completion:(NineAuthCompletion)completion {

    NSURLComponents *components =
        [NSURLComponents componentsWithURL:url
                   resolvingAgainstBaseURL:NO];

    NSString *code = nil, *state = nil, *authError = nil;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"code"]) code = item.value;
        if ([item.name isEqualToString:@"state"]) state = item.value;
        if ([item.name isEqualToString:@"error"]) authError = item.value;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *expected = [d stringForKey:@"NineHA.PendingState"];
    NSString *server = [d stringForKey:@"NineHA.PendingServer"];
    NSString *client = [d stringForKey:@"NineHA.PendingClient"];
    NSTimeInterval age = [[NSDate date] timeIntervalSince1970] -
                         [d doubleForKey:@"NineHA.PendingTime"];

    BOOL valid =
        [[components.scheme lowercaseString] isEqualToString:@"nineha"] &&
        [[components.host lowercaseString] isEqualToString:@"auth"] &&
        expected.length && [state isEqualToString:expected] &&
        age >= 0 && age < 600 &&
        [server isEqualToString:[self baseURL]] &&
        [client isEqualToString:self.clientID];

    if (!valid) {
        NAComplete(completion, nil,
                   NAError(@"Callback OAuth non valido o scaduto"));
        return;
    }

    [d removeObjectForKey:@"NineHA.PendingState"];
    [d synchronize];

    if (authError.length || !code.length) {
        NAComplete(completion, nil,
                   NAError(@"Autorizzazione annullata o non riuscita"));
        return;
    }

    [self tokenRequest:@{
        @"grant_type": @"authorization_code",
        @"client_id": self.clientID,
        @"code": code
    } completion:^(NSDictionary *result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSString *refresh = result[@"refresh_token"];
        NSString *access = result[@"access_token"];

        if (![refresh isKindOfClass:[NSString class]] ||
            ![access isKindOfClass:[NSString class]] ||
            ![self storeSecret:refresh kind:@"oauth"]) {
            completion(nil, NAError(@"Impossibile salvare OAuth"));
            return;
        }

        self.cachedOAuthToken = access;
        NSTimeInterval seconds = [result[@"expires_in"] doubleValue];
        self.oauthExpiry = [NSDate dateWithTimeIntervalSinceNow:seconds];

        completion(access, nil);
    }];
}

- (void)useOAuthToken:(NineAuthCompletion)completion {
    if (self.cachedOAuthToken.length &&
        [self.oauthExpiry timeIntervalSinceNow] > 60) {
        NAComplete(completion, self.cachedOAuthToken, nil);
        return;
    }

    NSString *refresh = [self readSecret:@"oauth"];
    if (!refresh.length || !self.clientID.length) {
        NAComplete(completion, nil,
                   NAError(@"Sessione OAuth non disponibile"));
        return;
    }

    [self tokenRequest:@{
        @"grant_type": @"refresh_token",
        @"client_id": self.clientID,
        @"refresh_token": refresh
    } completion:^(NSDictionary *result, NSError *error) {
        NSString *access = result[@"access_token"];

        if (error || ![access isKindOfClass:[NSString class]]) {
            completion(nil, error ?: NAError(@"Refresh OAuth fallito"));
            return;
        }

        self.cachedOAuthToken = access;
        NSTimeInterval seconds = [result[@"expires_in"] doubleValue];
        self.oauthExpiry = [NSDate dateWithTimeIntervalSinceNow:seconds];

        completion(access, nil);
    }];
}

@end
