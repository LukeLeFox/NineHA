#import "NineWSRequest.h"
#import "NineAuth.h"
#import "SRWebSocket.h"

@interface NineWSRequest () <SRWebSocketDelegate>
@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, strong) NSArray *commands;
@property (nonatomic, strong) NSMutableDictionary *results;
@property (nonatomic, copy) NineWSCompletion completion;
@property (nonatomic, strong) NSTimer *timeout;
@property (nonatomic, assign) BOOL finished;
@end

// Le richieste attive restano vive fino alla risposta.
static NSMutableSet *NineWSActive(void) {
    static NSMutableSet *active;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ active = [NSMutableSet set]; });
    return active;
}

@implementation NineWSRequest

+ (NineWSRequest *)sendCommands:(NSArray *)commands
                      serverURL:(NSString *)serverURL
                          token:(NSString *)token
                     completion:(NineWSCompletion)completion {
    NineWSRequest *request = [[NineWSRequest alloc] init];
    request.commands = commands;
    request.token = token;
    request.completion = completion;
    request.results = [NSMutableDictionary dictionary];
    [NineWSActive() addObject:request];
    [request openWithServer:serverURL];
    return request;
}

- (void)openWithServer:(NSString *)serverURL {
    NSURLComponents *components = [NSURLComponents componentsWithString:serverURL];

    // Stessa politica degli indirizzi usata per le chiamate REST.
    if (!NineHAAllowedServerURL(components) || !self.token.length) {
        [self failWith:@"Indirizzo del server non valido"];
        return;
    }

    components.scheme = [components.scheme.lowercaseString isEqualToString:@"https"]
        ? @"wss" : @"ws";
    components.path = @"/api/websocket";

    NSURLRequest *request = [NSURLRequest requestWithURL:components.URL
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:20];
    self.socket = [[SRWebSocket alloc] initWithURLRequest:request];
    self.socket.delegate = self;

    self.timeout = [NSTimer scheduledTimerWithTimeInterval:30
                                                    target:self
                                                  selector:@selector(timedOut)
                                                  userInfo:nil
                                                   repeats:NO];
    [self.socket open];
}

- (void)send:(NSDictionary *)message {
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    NSString *text = data ? [[NSString alloc] initWithData:data
                                                  encoding:NSUTF8StringEncoding] : nil;
    if (text) [self.socket send:text];
}

- (void)webSocket:(SRWebSocket *)socket didReceiveMessage:(id)message {
    if (self.finished || socket != self.socket) return;

    NSData *data = [message isKindOfClass:[NSString class]]
        ? [message dataUsingEncoding:NSUTF8StringEncoding] : message;
    id json = [data isKindOfClass:[NSData class]]
        ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![json isKindOfClass:[NSDictionary class]]) return;

    NSString *type = json[@"type"];

    if ([type isEqualToString:@"auth_required"]) {
        [self send:@{@"type": @"auth", @"access_token": self.token ?: @""}];
    } else if ([type isEqualToString:@"auth_invalid"]) {
        [self failWith:@"Autenticazione rifiutata"];
    } else if ([type isEqualToString:@"auth_ok"]) {
        self.token = nil;
        for (NSUInteger i = 0; i < self.commands.count; i++) {
            NSMutableDictionary *command = [self.commands[i] mutableCopy];
            command[@"id"] = @(i + 1);
            [self send:command];
        }
        if (!self.commands.count) [self finishWith:nil];
    } else if ([type isEqualToString:@"result"]) {
        NSInteger identifier = [json[@"id"] integerValue];
        if (identifier < 1 || identifier > (NSInteger)self.commands.count) return;

        id result = [json[@"success"] boolValue] ? json[@"result"] : nil;
        self.results[@(identifier)] = result ?: [NSNull null];

        if (self.results.count == self.commands.count) {
            NSMutableArray *ordered = [NSMutableArray array];
            for (NSUInteger i = 1; i <= self.commands.count; i++) {
                [ordered addObject:self.results[@(i)]];
            }
            [self finishWith:ordered];
        }
    }
}

- (void)webSocket:(SRWebSocket *)socket didFailWithError:(NSError *)error {
    if (socket == self.socket) [self failWith:@"Connessione WebSocket non riuscita"];
}

- (void)webSocket:(SRWebSocket *)socket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    if (socket == self.socket) [self failWith:@"Connessione chiusa"];
}

- (void)timedOut {
    [self failWith:@"Tempo scaduto"];
}

- (void)failWith:(NSString *)message {
    if (self.finished) return;
    NSError *error = [NSError errorWithDomain:@"NineHA.WS" code:1
        userInfo:@{NSLocalizedDescriptionKey: message}];
    [self complete:nil error:error];
}

- (void)finishWith:(NSArray *)results {
    [self complete:results ?: @[] error:nil];
}

- (void)complete:(NSArray *)results error:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;

    [self.timeout invalidate];
    self.timeout = nil;
    self.socket.delegate = nil;
    [self.socket close];
    self.socket = nil;
    self.token = nil;

    NineWSCompletion completion = self.completion;
    self.completion = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(results, error);
        [NineWSActive() removeObject:self];
    });
}

- (void)cancel {
    self.completion = nil;
    [self complete:nil error:nil];
}

@end
