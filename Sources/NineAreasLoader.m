#import "NineAreasLoader.h"
#import "SRWebSocket.h"

@interface NineAreasLoader () <SRWebSocketDelegate>

@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NineAreasCompletion completion;

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, strong) NSMutableDictionary *replies;
@property (nonatomic, strong) NSTimer *timeoutTimer;
@property (nonatomic, assign) BOOL finished;

@end

@implementation NineAreasLoader

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token
                       completion:(NineAreasCompletion)completion {
    self = [super init];

    if (self) {
        _serverURL = [serverURL copy];
        _token = [token copy];
        _completion = [completion copy];
        _replies = [NSMutableDictionary dictionary];
    }

    return self;
}

- (BOOL)isPrivateIPv4:(NSString *)host {
    NSArray *parts = [host componentsSeparatedByString:@"."];
    if (parts.count != 4) return NO;

    NSMutableArray *octets = [NSMutableArray array];

    for (NSString *part in parts) {
        if (!part.length) return NO;

        NSCharacterSet *invalid =
            [[NSCharacterSet decimalDigitCharacterSet]
                invertedSet];

        if ([part rangeOfCharacterFromSet:invalid].location
            != NSNotFound) return NO;

        NSInteger value = [part integerValue];
        if (value < 0 || value > 255) return NO;
        [octets addObject:@(value)];
    }

    NSInteger a = [octets[0] integerValue];
    NSInteger b = [octets[1] integerValue];

    return a == 10 ||
           (a == 172 && b >= 16 && b <= 31) ||
           (a == 192 && b == 168);
}

- (void)finishWithMap:(NSDictionary *)map
                names:(NSArray *)names
                error:(NSError *)error {
    if (self.finished) return;

    self.finished = YES;

    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;

    SRWebSocket *socket = self.socket;
    self.socket = nil;

    socket.delegate = nil;
    [socket close];

    self.token = nil;

    NineAreasCompletion callback = self.completion;
    self.completion = nil;

    if (callback) callback(map, names, error);
}

- (void)fail:(NSString *)message {
    NSError *error = [NSError errorWithDomain:@"NineHA.Areas"
        code:1
        userInfo:@{
            NSLocalizedDescriptionKey:
                message ?: @"Errore WebSocket"
        }];

    [self finishWithMap:nil names:nil error:error];
}

- (void)cancel {
    if (self.finished) return;

    self.finished = YES;

    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;

    self.socket.delegate = nil;
    [self.socket close];

    self.socket = nil;
    self.token = nil;
    self.completion = nil;
}

- (void)timedOut {
    [self fail:@"timeout WebSocket"];
}

- (void)start {
    if (self.finished) return;

    NSURLComponents *components =
        [NSURLComponents componentsWithString:self.serverURL];

    NSString *scheme = components.scheme.lowercaseString;

    if (![scheme isEqualToString:@"http"] &&
        ![scheme isEqualToString:@"https"]) {
        [self fail:@"URL server non valido"];
        return;
    }

    // Manteniamo la politica di sicurezza esistente:
    // HTTP soltanto per indirizzi IPv4 privati.
    if ([scheme isEqualToString:@"http"] &&
        ![self isPrivateIPv4:components.host ?: @""]) {
        [self fail:@"WS non consentito fuori dalla LAN privata"];
        return;
    }

    components.scheme =
        [scheme isEqualToString:@"https"] ? @"wss" : @"ws";

    NSString *path = components.path ?: @"";

    while ([path hasSuffix:@"/"] && path.length) {
        path = [path substringToIndex:path.length - 1];
    }

    components.path =
        [path stringByAppendingString:@"/api/websocket"];

    components.query = nil;
    components.fragment = nil;

    NSURL *url = components.URL;

    if (!url) {
        [self fail:@"URL WebSocket non valido"];
        return;
    }

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url];

    request.timeoutInterval = 20;

    self.socket =
        [[SRWebSocket alloc] initWithURLRequest:request];

    self.socket.delegate = self;
    [self.socket open];

    self.timeoutTimer = [NSTimer
        scheduledTimerWithTimeInterval:25
                               target:self
                             selector:@selector(timedOut)
                             userInfo:nil
                              repeats:NO];
}

- (void)sendJSON:(NSDictionary *)object {
    if (self.finished) return;

    NSError *error = nil;
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:object
                   options:0
                     error:&error];

    if (!data) {
        [self fail:@"serializzazione JSON fallita"];
        return;
    }

    NSString *message = [[NSString alloc]
        initWithData:data
           encoding:NSUTF8StringEncoding];

    if (!message) {
        [self fail:@"codifica JSON fallita"];
        return;
    }

    [self.socket send:message];
}

- (void)webSocket:(SRWebSocket *)socket
didReceiveMessage:(id)message {
    if (self.finished || socket != self.socket) return;

    NSData *data = nil;

    if ([message isKindOfClass:[NSString class]]) {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([message isKindOfClass:[NSData class]]) {
        data = message;
    }

    if (!data) return;

    NSDictionary *json = [NSJSONSerialization
        JSONObjectWithData:data
                   options:0
                     error:nil];

    if (![json isKindOfClass:[NSDictionary class]]) {
        [self fail:@"risposta JSON non valida"];
        return;
    }

    NSString *type = json[@"type"];

    if ([type isEqualToString:@"auth_required"]) {
        [self sendJSON:@{
            @"type": @"auth",
            @"access_token": self.token ?: @""
        }];
        return;
    }

    if ([type isEqualToString:@"auth_invalid"]) {
        [self fail:@"autenticazione rifiutata"];
        return;
    }

    if ([type isEqualToString:@"auth_ok"]) {
        [self sendJSON:@{
            @"id": @1,
            @"type": @"config/area_registry/list"
        }];

        [self sendJSON:@{
            @"id": @2,
            @"type": @"config/entity_registry/list_for_display"
        }];

        [self sendJSON:@{
            @"id": @3,
            @"type": @"config/device_registry/list"
        }];
        return;
    }

    if (![type isEqualToString:@"result"]) return;

    NSNumber *messageID = json[@"id"];

    if (![messageID isKindOfClass:[NSNumber class]]) return;

    NSInteger identifier = messageID.integerValue;

    if (identifier < 1 || identifier > 3) return;

    if (![json[@"success"] boolValue]) {
        [self fail:[NSString stringWithFormat:
            @"registro %ld non accessibile", (long)identifier]];
        return;
    }

    id result = json[@"result"];

    if (!result || result == [NSNull null]) {
        [self fail:@"registro vuoto o non valido"];
        return;
    }

    self.replies[@(identifier)] = result;

    if (self.replies.count == 3) {
        [self buildAreaMap];
    }
}

- (void)buildAreaMap {
    NSArray *areas = self.replies[@1];
    NSDictionary *entityResult = self.replies[@2];
    NSArray *devices = self.replies[@3];

    if (![areas isKindOfClass:[NSArray class]] ||
        ![entityResult isKindOfClass:[NSDictionary class]] ||
        ![devices isKindOfClass:[NSArray class]]) {
        [self fail:@"formato registri inatteso"];
        return;
    }

    NSArray *entities = entityResult[@"entities"];

    if (![entities isKindOfClass:[NSArray class]]) {
        [self fail:@"registro entità non valido"];
        return;
    }

    NSMutableDictionary *areaNames =
        [NSMutableDictionary dictionary];

    for (id entry in areas) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;

        NSString *identifier = entry[@"area_id"];
        if (![identifier isKindOfClass:[NSString class]])
            identifier = entry[@"id"];

        NSString *name = entry[@"name"];

        if ([identifier isKindOfClass:[NSString class]] &&
            identifier.length &&
            [name isKindOfClass:[NSString class]] &&
            name.length) {
            areaNames[identifier] = name;
        }
    }

    NSMutableDictionary *devicesByID =
        [NSMutableDictionary dictionary];

    for (id device in devices) {
        if (![device isKindOfClass:[NSDictionary class]]) continue;

        NSString *identifier = device[@"id"];

        if ([identifier isKindOfClass:[NSString class]] &&
            identifier.length) {
            devicesByID[identifier] = device;
        }
    }

    NSMutableDictionary *map =
        [NSMutableDictionary dictionary];

    for (id entry in entities) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;

        NSString *entityID = entry[@"ei"];
        if (![entityID isKindOfClass:[NSString class]] ||
            !entityID.length) continue;

        NSString *name = nil;
        NSString *areaID = entry[@"ai"];

        // Priorità all'area specifica dell'entità.
        if ([areaID isKindOfClass:[NSString class]]) {
            name = areaNames[areaID];
        }

        // Altrimenti ereditiamo l'area dal dispositivo.
        if (!name.length) {
            NSString *deviceID = entry[@"di"];

            // Include la possibilità di dispositivi figli.
            for (NSInteger depth = 0; depth < 12; depth++) {
                if (![deviceID isKindOfClass:[NSString class]] ||
                    !deviceID.length) break;

                NSDictionary *device = devicesByID[deviceID];

                if (![device isKindOfClass:[NSDictionary class]])
                    break;

                NSString *deviceArea = device[@"area_id"];

                if ([deviceArea isKindOfClass:[NSString class]]) {
                    name = areaNames[deviceArea];
                }

                if (name.length) break;

                deviceID = device[@"parent_device_id"];
            }
        }

        if (name.length) {
            map[entityID] = name;
        }
    }

    if (!areaNames.count) {
        [self fail:@"nessuna stanza disponibile"];
        return;
    }

    NSArray *sorted = [[NSSet setWithArray:
        [areaNames allValues]].allObjects
            sortedArrayUsingSelector:
                @selector(localizedCaseInsensitiveCompare:)];

    [self finishWithMap:map names:sorted error:nil];
}

- (void)webSocket:(SRWebSocket *)socket
 didFailWithError:(NSError *)error {
    if (socket != self.socket) return;

    [self fail:[NSString stringWithFormat:
        @"connessione WS (%ld)", (long)error.code]];
}

- (void)webSocket:(SRWebSocket *)socket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    if (socket != self.socket || self.finished) return;

    [self fail:[NSString stringWithFormat:
        @"WS chiuso (%ld)", (long)code]];
}

@end
