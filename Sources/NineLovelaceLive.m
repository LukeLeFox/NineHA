#import "NineLovelaceLive.h"
#import "SRWebSocket.h"

@interface NineLovelaceLive () <SRWebSocketDelegate>

@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NineLiveStateHandler onState;
@property (nonatomic, copy) NineLiveStatusHandler onStatus;

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, strong) NSTimer *handshakeTimer;
@property (nonatomic, strong) NSTimer *heartbeatTimer;

@property (nonatomic, assign) BOOL stopped;
@property (nonatomic, assign) BOOL subscribed;
@property (nonatomic, assign) BOOL waitingForPong;

@end

@implementation NineLovelaceLive

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token
                          onState:(NineLiveStateHandler)onState
                         onStatus:(NineLiveStatusHandler)onStatus {
    self = [super init];

    if (self) {
        _serverURL = [serverURL copy];
        _token = [token copy];
        _onState = [onState copy];
        _onStatus = [onStatus copy];
    }

    return self;
}

#pragma mark - URL validation

- (BOOL)isPrivateIPv4:(NSString *)host {
    NSArray *parts = [host componentsSeparatedByString:@"."];

    if (parts.count != 4) return NO;

    NSCharacterSet *notDigits =
        [[NSCharacterSet characterSetWithCharactersInString:
            @"0123456789"] invertedSet];

    NSMutableArray *values = [NSMutableArray array];

    for (NSString *part in parts) {
        if (!part.length ||
            [part rangeOfCharacterFromSet:notDigits].location
                != NSNotFound) {
            return NO;
        }

        NSInteger number = [part integerValue];

        if (number < 0 || number > 255) return NO;

        [values addObject:@(number)];
    }

    NSInteger a = [values[0] integerValue];
    NSInteger b = [values[1] integerValue];

    return a == 10 ||
           (a == 172 && b >= 16 && b <= 31) ||
           (a == 192 && b == 168);
}

- (NSURL *)socketURL {
    NSURLComponents *url =
        [NSURLComponents componentsWithString:self.serverURL];

    NSString *scheme = [url.scheme lowercaseString];

    if (!url.host.length ||
        url.user.length ||
        url.password.length) {
        return nil;
    }

    if ([scheme isEqualToString:@"https"]) {
        url.scheme = @"wss";
    } else if ([scheme isEqualToString:@"http"] &&
               [self isPrivateIPv4:url.host]) {
        url.scheme = @"ws";
    } else {
        return nil;
    }

    NSString *path = url.path ?: @"";

    while (path.length && [path hasSuffix:@"/"]) {
        path = [path substringToIndex:path.length - 1];
    }

    url.path = [path stringByAppendingString:@"/api/websocket"];
    url.query = nil;
    url.fragment = nil;

    return url.URL;
}

#pragma mark - Connection

- (void)start {
    if (self.socket || self.stopped) return;

    NSURL *url = [self socketURL];

    if (!url || !self.token.length) {
        [self failWithReason:@"URL/token non valido"];
        return;
    }

    NSURLRequest *request =
        [NSURLRequest
            requestWithURL:url
               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
           timeoutInterval:20];

    self.socket =
        [[SRWebSocket alloc] initWithURLRequest:request];

    self.socket.delegate = self;

    self.handshakeTimer = [NSTimer
        scheduledTimerWithTimeInterval:25
                               target:self
                             selector:@selector(handshakeTimeout)
                             userInfo:nil
                              repeats:NO];

    [self.socket open];
}

- (void)sendJSON:(NSDictionary *)value {
    if (self.stopped || !self.socket) return;

    NSData *data =
        [NSJSONSerialization dataWithJSONObject:value
                                       options:0
                                         error:nil];

    NSString *string = data
        ? [[NSString alloc] initWithData:data
                               encoding:NSUTF8StringEncoding]
        : nil;

    if (string) {
        [self.socket send:string];
    } else {
        [self failWithReason:@"JSON non valido"];
    }
}

- (void)handshakeTimeout {
    [self failWithReason:
        @"Timeout autenticazione/sottoscrizione"];
}

#pragma mark - Heartbeat

- (void)heartbeat {
    if (!self.subscribed || self.stopped) return;

    if (self.waitingForPong) {
        [self failWithReason:@"Heartbeat senza risposta"];
        return;
    }

    self.waitingForPong = YES;

    [self sendJSON:@{
        @"id": @2,
        @"type": @"ping"
    }];
}

#pragma mark - SocketRocket

- (void)webSocket:(SRWebSocket *)socket
didReceiveMessage:(id)message {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self webSocket:socket didReceiveMessage:message];
        });
        return;
    }

    if (self.stopped || socket != self.socket) return;

    NSData *data = nil;

    if ([message isKindOfClass:[NSString class]]) {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([message isKindOfClass:[NSData class]]) {
        data = message;
    }

    if (!data) return;

    id obj = [NSJSONSerialization JSONObjectWithData:data
                                              options:0
                                                error:nil];

    if (![obj isKindOfClass:[NSDictionary class]]) return;

    NSDictionary *reply = obj;
    NSString *type = reply[@"type"];

    if (![type isKindOfClass:[NSString class]]) return;

    if ([type isEqualToString:@"auth_required"]) {
        [self sendJSON:@{
            @"type": @"auth",
            @"access_token": self.token ?: @""
        }];
    }

    else if ([type isEqualToString:@"auth_ok"]) {
        self.token = nil;

        [self sendJSON:@{
            @"id": @1,
            @"type": @"subscribe_events",
            @"event_type": @"state_changed"
        }];
    }

    else if ([type isEqualToString:@"auth_invalid"]) {
        [self failWithReason:@"Autenticazione rifiutata"];
    }

    else if ([type isEqualToString:@"result"] &&
             [reply[@"id"] integerValue] == 1) {

        if (![reply[@"success"] boolValue]) {
            [self failWithReason:
                @"subscribe_events rifiutato"];
            return;
        }

        self.subscribed = YES;

        [self.handshakeTimer invalidate];
        self.handshakeTimer = nil;

        self.heartbeatTimer = [NSTimer
            scheduledTimerWithTimeInterval:30
                                   target:self
                                 selector:@selector(heartbeat)
                                 userInfo:nil
                                  repeats:YES];

        if (self.onStatus) self.onStatus(YES);
    }

    else if ([type isEqualToString:@"pong"] &&
             [reply[@"id"] integerValue] == 2) {
        self.waitingForPong = NO;
    }

    else if ([type isEqualToString:@"event"] &&
             self.subscribed &&
             [reply[@"id"] integerValue] == 1) {

        NSDictionary *event = reply[@"event"];

        if (![event isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSString *eventType = event[@"event_type"];

        if (![eventType isKindOfClass:[NSString class]] ||
            ![eventType isEqualToString:@"state_changed"]) {
            return;
        }

        NSDictionary *details = event[@"data"];

        if (![details isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSString *entity = details[@"entity_id"];

        if (![entity isKindOfClass:[NSString class]] ||
            !entity.length) {
            return;
        }

        id changed = details[@"new_state"];

        NSDictionary *state =
            [changed isKindOfClass:[NSDictionary class]]
                ? changed
                : nil;

        if (self.onState) {
            self.onState(entity, state);
        }
    }
}

- (void)webSocket:(SRWebSocket *)socket
 didFailWithError:(NSError *)error {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self webSocket:socket didFailWithError:error];
        });
        return;
    }

    if (socket == self.socket) {
        [self failWithReason:@"Socket disconnesso"];
    }
}

- (void)webSocket:(SRWebSocket *)socket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self webSocket:socket
             didCloseWithCode:code
                       reason:reason
                     wasClean:wasClean];
        });
        return;
    }

    if (socket == self.socket) {
        [self failWithReason:@"Connessione chiusa"];
    }
}

#pragma mark - Cleanup

- (void)failWithReason:(NSString *)reason {
    if (self.stopped) return;

    NSLog(@"NineHA Live: %@", reason);

    NineLiveStatusHandler callback = self.onStatus;

    [self stop];

    if (callback) callback(NO);
}

- (void)stop {
    if (self.stopped) return;

    self.stopped = YES;

    [self.handshakeTimer invalidate];
    [self.heartbeatTimer invalidate];

    self.handshakeTimer = nil;
    self.heartbeatTimer = nil;

    self.token = nil;

    self.socket.delegate = nil;
    [self.socket close];
    self.socket = nil;

    self.onState = nil;
    self.onStatus = nil;
}

- (void)dealloc {
    [self stop];
}

@end
