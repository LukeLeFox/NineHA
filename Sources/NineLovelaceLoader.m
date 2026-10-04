#import "NineLovelaceLoader.h"
#import "SRWebSocket.h"

typedef NS_ENUM(NSInteger, NineLovelaceRequest) {
    NineLovelaceRequestNone = 0,
    NineLovelaceRequestDashboards,
    NineLovelaceRequestConfig
};

@interface NineLovelaceLoader () <SRWebSocketDelegate>

@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *dashboardPath;

@property (nonatomic, copy) NineLovelaceCompletion completion;

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, assign) NineLovelaceRequest requestKind;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL finished;

@end

@implementation NineLovelaceLoader

#pragma mark - Initialization

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token {

    self = [super init];

    if (self) {
        _serverURL = [serverURL copy];
        _token = [token copy];
        _requestKind = NineLovelaceRequestNone;
    }

    return self;
}

#pragma mark - Network validation

- (BOOL)isPrivateIPv4:(NSString *)host {

    NSArray *parts = [host componentsSeparatedByString:@"."];

    if (parts.count != 4) {
        return NO;
    }

    NSMutableArray *numbers = [NSMutableArray array];

    NSCharacterSet *invalidCharacters =
        [[NSCharacterSet characterSetWithCharactersInString:
            @"0123456789"] invertedSet];

    for (NSString *part in parts) {

        if (!part.length ||
            [part rangeOfCharacterFromSet:
                invalidCharacters].location != NSNotFound) {
            return NO;
        }

        NSInteger value = [part integerValue];

        if (value < 0 || value > 255) {
            return NO;
        }

        [numbers addObject:@(value)];
    }

    NSInteger first = [numbers[0] integerValue];
    NSInteger second = [numbers[1] integerValue];

    return first == 10 ||
           (first == 172 && second >= 16 && second <= 31) ||
           (first == 192 && second == 168);
}

- (NSURL *)webSocketURL {

    NSURLComponents *components =
        [NSURLComponents componentsWithString:self.serverURL];

    NSString *scheme = components.scheme.lowercaseString;

    if (![scheme isEqualToString:@"http"] &&
        ![scheme isEqualToString:@"https"]) {
        return nil;
    }

    if (!components.host.length ||
        components.user.length ||
        components.password.length) {
        return nil;
    }

    if ([scheme isEqualToString:@"http"]) {

        if (![self isPrivateIPv4:components.host]) {
            return nil;
        }

        components.scheme = @"ws";

    } else {

        components.scheme = @"wss";
    }

    NSString *path = components.path ?: @"";

    while ([path hasSuffix:@"/"] && path.length) {
        path = [path substringToIndex:path.length - 1];
    }

    components.path =
        [path stringByAppendingString:@"/api/websocket"];

    components.query = nil;
    components.fragment = nil;

    return components.URL;
}

#pragma mark - Public API

- (void)loadDashboardsWithCompletion:
    (NineLovelaceCompletion)completion {

    if (self.started || self.finished) {
        return;
    }

    self.requestKind = NineLovelaceRequestDashboards;
    self.completion = completion;

    [self start];
}

- (void)loadConfigurationForPath:(NSString *)path
                      completion:(NineLovelaceCompletion)completion {

    if (self.started || self.finished) {
        return;
    }

    self.requestKind = NineLovelaceRequestConfig;
    self.dashboardPath = path;
    self.completion = completion;

    [self start];
}

#pragma mark - Connection

- (void)start {

    if (self.started || self.finished) {
        return;
    }

    self.started = YES;

    NSURL *url = [self webSocketURL];

    if (!url) {
        [self fail:@"Indirizzo WebSocket non consentito"];
        return;
    }

    if (!self.token.length) {
        [self fail:@"Token non disponibile"];
        return;
    }

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url];

    request.timeoutInterval = 20;

    self.socket =
        [[SRWebSocket alloc] initWithURLRequest:request];

    self.socket.delegate = self;

    [self.socket open];

    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:25
                               target:self
                             selector:@selector(connectionTimedOut)
                             userInfo:nil
                              repeats:NO];
}

- (void)connectionTimedOut {
    [self fail:@"Timeout connessione Lovelace"];
}

#pragma mark - JSON

- (void)sendJSON:(NSDictionary *)message {

    if (self.finished || !self.socket) {
        return;
    }

    NSError *error = nil;

    NSData *data =
        [NSJSONSerialization dataWithJSONObject:message
                                       options:0
                                         error:&error];

    if (!data) {
        [self fail:@"Impossibile creare richiesta JSON"];
        return;
    }

    NSString *json =
        [[NSString alloc] initWithData:data
                             encoding:NSUTF8StringEncoding];

    if (!json) {
        [self fail:@"Codifica JSON non riuscita"];
        return;
    }

    [self.socket send:json];
}

- (void)sendLovelaceRequest {

    if (self.requestKind == NineLovelaceRequestDashboards) {

        [self sendJSON:@{
            @"id": @1,
            @"type": @"lovelace/dashboards/list"
        }];

        return;
    }

    if (self.requestKind == NineLovelaceRequestConfig) {

        NSMutableDictionary *request =
            [NSMutableDictionary dictionaryWithDictionary:@{
                @"id": @1,
                @"type": @"lovelace/config"
            }];

        /*
         * Il percorso "lovelace" identifica la
         * dashboard predefinita.
         */
        NSString *path = self.dashboardPath;

        if (path.length &&
            ![path isEqualToString:@"lovelace"]) {

            request[@"url_path"] = path;
        }

        [self sendJSON:request];
    }
}

#pragma mark - SocketRocket delegate

- (void)webSocket:(SRWebSocket *)socket
didReceiveMessage:(id)message {

    if (self.finished || socket != self.socket) {
        return;
    }

    NSData *data = nil;

    if ([message isKindOfClass:[NSString class]]) {

        data = [(NSString *)message
            dataUsingEncoding:NSUTF8StringEncoding];

    } else if ([message isKindOfClass:[NSData class]]) {

        data = message;
    }

    if (!data) {
        [self fail:@"Messaggio WebSocket non valido"];
        return;
    }

    NSError *parseError = nil;

    id parsed =
        [NSJSONSerialization JSONObjectWithData:data
                                        options:0
                                          error:&parseError];

    if (![parsed isKindOfClass:[NSDictionary class]]) {
        [self fail:@"Risposta WebSocket non valida"];
        return;
    }

    NSDictionary *response = parsed;
    NSString *type = response[@"type"];

    if (![type isKindOfClass:[NSString class]]) {
        return;
    }

    if ([type isEqualToString:@"auth_required"]) {

        [self sendJSON:@{
            @"type": @"auth",
            @"access_token": self.token ?: @""
        }];

        return;
    }

    if ([type isEqualToString:@"auth_invalid"]) {

        [self fail:@"Autenticazione Home Assistant rifiutata"];
        return;
    }

    if ([type isEqualToString:@"auth_ok"]) {

        // Non serve più conservare il token in memoria.
        self.token = nil;

        [self sendLovelaceRequest];
        return;
    }

    if (![type isEqualToString:@"result"]) {
        return;
    }

    NSNumber *identifier = response[@"id"];

    if (![identifier isKindOfClass:[NSNumber class]] ||
        identifier.integerValue != 1) {
        return;
    }

    if (![response[@"success"] boolValue]) {

        NSString *code = @"errore";

        NSDictionary *details = response[@"error"];

        if ([details isKindOfClass:[NSDictionary class]] &&
            [details[@"code"] isKindOfClass:[NSString class]]) {
            code = details[@"code"];
        }

        [self fail:[NSString stringWithFormat:
            @"Lovelace: richiesta rifiutata (%@)", code]];

        return;
    }

    id result = response[@"result"];

    if (self.requestKind == NineLovelaceRequestDashboards) {

        if (![result isKindOfClass:[NSArray class]]) {
            [self fail:@"Elenco dashboard non valido"];
            return;
        }

    } else if (self.requestKind == NineLovelaceRequestConfig) {

        if (![result isKindOfClass:[NSDictionary class]]) {
            [self fail:@"Configurazione Lovelace non valida"];
            return;
        }

    } else {

        [self fail:@"Richiesta sconosciuta"];
        return;
    }

    [self finishWithResult:result
                     error:nil
                    notify:YES];
}

- (void)webSocket:(SRWebSocket *)socket
 didFailWithError:(NSError *)error {

    if (self.finished || socket != self.socket) {
        return;
    }

    [self fail:[NSString stringWithFormat:
        @"Errore WebSocket (%ld)", (long)error.code]];
}

- (void)webSocket:(SRWebSocket *)socket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {

    if (self.finished || socket != self.socket) {
        return;
    }

    [self fail:[NSString stringWithFormat:
        @"Connessione chiusa (%ld)", (long)code]];
}

#pragma mark - Completion and cleanup

- (void)fail:(NSString *)message {

    NSError *error =
        [NSError errorWithDomain:@"NineHA.Lovelace"
                            code:1
                        userInfo:@{
        NSLocalizedDescriptionKey:
            message ?: @"Errore sconosciuto"
    }];

    [self finishWithResult:nil
                     error:error
                    notify:YES];
}

- (void)finishWithResult:(id)result
                   error:(NSError *)error
                  notify:(BOOL)notify {

    if (self.finished) {
        return;
    }

    self.finished = YES;

    [self.timer invalidate];
    self.timer = nil;

    self.socket.delegate = nil;
    [self.socket close];
    self.socket = nil;

    self.token = nil;

    NineLovelaceCompletion callback = self.completion;
    self.completion = nil;

    if (notify && callback) {

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(result, error);
        });
    }
}

- (void)cancel {

    [self finishWithResult:nil
                     error:nil
                    notify:NO];
}

- (void)dealloc {
    [self cancel];
}

@end
