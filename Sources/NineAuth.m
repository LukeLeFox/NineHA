
#import "NineAuth.h"
#import <Security/Security.h>

static NSString *const NAService = @"org.nineha.client.auth";

// Identità del client per il login con password. Home Assistant
// accetta redirect_uri sullo stesso host del client_id senza
// contattarlo; il redirect non viene mai seguito.
static NSString *const NAPasswordClientID = @"https://lukelefox.github.io/NineHA/";
static NSString *const NAPasswordRedirect = @"https://lukelefox.github.io/NineHA/auth";

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
@property (nonatomic, copy) NSString *cachedPasswordToken;
@property (nonatomic, strong) NSDate *passwordExpiry;
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
    if ([kind isEqualToString:@"password"]) {
        return [base stringByAppendingString:@"|password"];
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

#pragma mark - Login con nome utente e password

- (BOOL)hasPasswordSession {
    return [self readSecret:@"password"].length > 0;
}

- (BOOL)hasCredentialsForMode:(NSString *)mode {
    if ([mode isEqualToString:@"oauth"]) return [self hasOAuthSession];
    if ([mode isEqualToString:@"password"]) return [self hasPasswordSession];
    return [self hasManualToken];
}

- (void)useTokenForMode:(NSString *)mode
             completion:(NineAuthCompletion)completion {
    if ([mode isEqualToString:@"oauth"]) {
        [self useOAuthToken:completion];
    } else if ([mode isEqualToString:@"password"]) {
        [self usePasswordToken:completion];
    } else {
        [self useManualToken:completion];
    }
}

// POST JSON verso il login flow, senza seguire redirect.
- (void)flowRequest:(NSString *)path
               body:(NSDictionary *)body
         completion:(void (^)(NSDictionary *json, NSError *error))completion {

    NSString *base = [self baseURL];
    NSURL *url = base
        ? [NSURL URLWithString:[base stringByAppendingString:path]] : nil;

    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, NAError(@"Indirizzo del server non valido"));
        });
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body
                                                       options:0
                                                         error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request
                completionHandler:^(NSData *data, NSURLResponse *response,
                                    NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        id json = data.length
            ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]
            : nil;

        NSError *failure = error;
        if (!failure && (status < 200 || status >= 300)) {
            failure = NAError(status == 404 || status == 405
                ? @"Login con password non disponibile su questo server"
                : [NSString stringWithFormat:@"Errore HTTP %ld", (long)status]);
        }
        if (!failure && ![json isKindOfClass:[NSDictionary class]]) {
            failure = NAError(@"Risposta di login non valida");
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(failure ? nil : json, failure);
        });
        [session finishTasksAndInvalidate];
    }] resume];
}

static NSString *NAFlowErrorText(NSDictionary *errors) {
    id base = [errors isKindOfClass:[NSDictionary class]] ? errors[@"base"] : nil;
    if ([base isEqualToString:@"invalid_auth"])
        return @"Nome utente o password non validi";
    if ([base isEqualToString:@"invalid_code"])
        return @"Codice di verifica non valido";
    if ([base isKindOfClass:[NSString class]])
        return [@"Accesso non riuscito: " stringByAppendingString:base];
    return @"Accesso non riuscito";
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               mfaHandler:(void (^)(NineAuthMFAResponder respond))mfaHandler
               completion:(NineAuthCompletion)completion {

    if (!username.length || !password.length) {
        NAComplete(completion, nil, NAError(@"Inserisci nome utente e password"));
        return;
    }

    [self flowRequest:@"/auth/login_flow"
                 body:@{
        @"client_id": NAPasswordClientID,
        @"handler": @[@"homeassistant", [NSNull null]],
        @"redirect_uri": NAPasswordRedirect
    } completion:^(NSDictionary *json, NSError *error) {
        NSString *flowID = json[@"flow_id"];

        if (error || ![flowID isKindOfClass:[NSString class]] ||
            !flowID.length) {
            completion(nil, error ?: NAError(@"Login flow non avviato"));
            return;
        }

        [self continueFlow:flowID
                      body:@{@"client_id": NAPasswordClientID,
                             @"username": username,
                             @"password": password}
                mfaHandler:mfaHandler
                completion:completion];
    }];
}

- (void)continueFlow:(NSString *)flowID
                body:(NSDictionary *)body
          mfaHandler:(void (^)(NineAuthMFAResponder respond))mfaHandler
          completion:(NineAuthCompletion)completion {

    NSString *path = [@"/auth/login_flow/" stringByAppendingString:
        [flowID stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet alphanumericCharacterSet]]];

    [self flowRequest:path body:body
           completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSString *type = json[@"type"];
        NSString *step = json[@"step_id"];
        NSDictionary *errors = json[@"errors"];

        if ([type isEqualToString:@"create_entry"]) {
            NSString *code = json[@"result"];
            if (![code isKindOfClass:[NSString class]] || !code.length) {
                completion(nil, NAError(@"Codice di autorizzazione mancante"));
                return;
            }
            [self exchangePasswordCode:code completion:completion];
            return;
        }

        if ([type isEqualToString:@"abort"]) {
            NSString *reason = json[@"reason"];
            completion(nil, NAError([reason isKindOfClass:[NSString class]]
                ? [@"Accesso interrotto: " stringByAppendingString:reason]
                : @"Accesso interrotto"));
            return;
        }

        if (![type isEqualToString:@"form"]) {
            completion(nil, NAError(@"Risposta di login inattesa"));
            return;
        }

        // Errore sul passo corrente (credenziali o codice errati).
        if ([errors isKindOfClass:[NSDictionary class]] && errors.count) {
            completion(nil, NAError(NAFlowErrorText(errors)));
            return;
        }

        // Autenticazione a due fattori: chiediamo il codice.
        if ([step isEqualToString:@"mfa"] && mfaHandler) {
            mfaHandler(^(NSString *code) {
                if (!code.length) {
                    completion(nil, NAError(@"Accesso annullato"));
                    return;
                }
                [self continueFlow:flowID
                              body:@{@"client_id": NAPasswordClientID,
                                     @"code": code}
                        mfaHandler:mfaHandler
                        completion:completion];
            });
            return;
        }

        completion(nil, NAError(@"Passo di login non supportato"));
    }];
}

- (void)exchangePasswordCode:(NSString *)code
                  completion:(NineAuthCompletion)completion {
    [self tokenRequest:@{
        @"grant_type": @"authorization_code",
        @"client_id": NAPasswordClientID,
        @"code": code
    } completion:^(NSDictionary *result, NSError *error) {
        NSString *access = result[@"access_token"];
        NSString *refresh = result[@"refresh_token"];

        if (error || ![access isKindOfClass:[NSString class]] ||
            ![refresh isKindOfClass:[NSString class]]) {
            completion(nil, error ?: NAError(@"Token non ricevuto"));
            return;
        }

        if (![self storeSecret:refresh kind:@"password"]) {
            completion(nil, NAError(@"Impossibile salvare la sessione"));
            return;
        }

        self.cachedPasswordToken = access;
        self.passwordExpiry = [NSDate dateWithTimeIntervalSinceNow:
            [result[@"expires_in"] doubleValue]];

        completion(access, nil);
    }];
}

- (void)usePasswordToken:(NineAuthCompletion)completion {
    if (self.cachedPasswordToken.length &&
        [self.passwordExpiry timeIntervalSinceNow] > 60) {
        NAComplete(completion, self.cachedPasswordToken, nil);
        return;
    }

    NSString *refresh = [self readSecret:@"password"];
    if (!refresh.length) {
        NAComplete(completion, nil,
                   NAError(@"Sessione scaduta: accedi di nuovo"));
        return;
    }

    [self tokenRequest:@{
        @"grant_type": @"refresh_token",
        @"client_id": NAPasswordClientID,
        @"refresh_token": refresh
    } completion:^(NSDictionary *result, NSError *error) {
        NSString *access = result[@"access_token"];

        if (error || ![access isKindOfClass:[NSString class]]) {
            completion(nil, error ?: NAError(@"Rinnovo della sessione non riuscito"));
            return;
        }

        self.cachedPasswordToken = access;
        self.passwordExpiry = [NSDate dateWithTimeIntervalSinceNow:
            [result[@"expires_in"] doubleValue]];

        completion(access, nil);
    }];
}

@end
