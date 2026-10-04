#import "NineLovelaceActionEngine.h"
#import "NineLocalConfig.h"

static NSString *NHAActionString(id value) {
    return [value isKindOfClass:[NSString class]]
        ? value : nil;
}

static NSDictionary *NHAActionDict(id value) {
    return [value isKindOfClass:[NSDictionary class]]
        ? value : @{};
}

@interface NineLovelaceActionEngine ()
    <NSURLSessionTaskDelegate>

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) BOOL busy;

@end

@implementation NineLovelaceActionEngine

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode {
    self = [super init];

    if (self) {
        _auth = auth;
        _mode = [mode copy];
    }

    return self;
}

#pragma mark - Validation

- (BOOL)validIdentifier:(NSString *)value {
    if (!value.length) return NO;

    NSCharacterSet *invalid = [[NSCharacterSet
        characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyz0123456789_."]
        invertedSet];

    return [value rangeOfCharacterFromSet:invalid].location
        == NSNotFound;
}

- (NSString *)entityFromAction:(NSDictionary *)action
                         card:(NSDictionary *)card {
    id target = NHAActionDict(action[@"target"])[@"entity_id"];

    if (!target) {
        target = NHAActionDict(action[@"data"])[@"entity_id"];
    }

    if (!target) target = card[@"entity"];

    // In questa versione non eseguiamo azioni
    // su liste multiple di entità.
    return NHAActionString(target);
}

#pragma mark - Alerts

- (void)showTitle:(NSString *)title
          message:(NSString *)message
        presenter:(UIViewController *)presenter {
    if (!presenter.view.window) return;

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"OK"
                  style:UIAlertActionStyleCancel
                handler:nil]];

    [presenter presentViewController:alert
                           animated:YES
                         completion:nil];
}

#pragma mark - Card actions

- (void)performCard:(NSDictionary *)card
            gesture:(NSString *)gesture
          presenter:(UIViewController *)presenter {

    if (self.busy || !presenter.view.window) return;

    NSDictionary *configuration = NHAActionDict(card);

    NSString *actionKey =
        [gesture isEqualToString:@"hold"]
        ? @"hold_action" : @"tap_action";

    NSDictionary *action =
        NHAActionDict(configuration[actionKey]);

    NSString *kind =
        NHAActionString(action[@"action"]);

    if (!kind.length ||
        [kind isEqualToString:@"none"]) {
        return;
    }

    if ([kind isEqualToString:@"more-info"]) {
        [self showTitle:@"Dettagli"
                message:@"I dettagli nativi della card "
                        "saranno disponibili nel prossimo blocco."
              presenter:presenter];
        return;
    }

    NSString *entity =
        [self entityFromAction:action card:configuration];

    NSString *domain = nil;
    NSString *service = nil;
    NSDictionary *payload = @{};

    BOOL sensitive = NO;
    BOOL destructive = NO;

    if ([kind isEqualToString:@"toggle"]) {

        if (![self validIdentifier:entity]) return;

        NSArray *parts =
            [entity componentsSeparatedByString:@"."];

        if (parts.count != 2) return;

        domain = parts[0];

        if (![@[@"light", @"switch", @"input_boolean"]
                containsObject:domain]) {
            [self showTitle:@"Azione non supportata"
                    message:@"Toggle non consentito "
                            "per questa entità."
                  presenter:presenter];
            return;
        }

        service = @"toggle";
        payload = @{@"entity_id": entity};

    } else if ([kind isEqualToString:@"call-service"] ||
               [kind isEqualToString:@"perform-action"]) {

        NSString *fullService =
            NHAActionString(action[@"service"])
            ?: NHAActionString(action[@"perform_action"]);

        if ([fullService isEqualToString:@"button.press"] &&
            [entity hasPrefix:@"button."] &&
            [self validIdentifier:entity]) {

            domain = @"button";
            service = @"press";
            payload = @{@"entity_id": entity};

        } else if (NINEHA_NAS_GRACEFUL_ACTION.length &&
                   [fullService isEqualToString:
                    NINEHA_NAS_GRACEFUL_ACTION]) {

            domain = NINEHA_NAS_GRACEFUL_DOMAIN;
            service = NINEHA_NAS_GRACEFUL_SERVICE;
            sensitive = YES;

        } else if (NINEHA_NAS_FORCE_ACTION.length &&
                   [fullService isEqualToString:
                    NINEHA_NAS_FORCE_ACTION] &&
                   [gesture isEqualToString:@"hold"]) {

            domain = NINEHA_NAS_FORCE_DOMAIN;
            service = NINEHA_NAS_FORCE_SERVICE;
            sensitive = YES;
            destructive = YES;

        } else {
            [self showTitle:@"Servizio non supportato"
                    message:fullService
                        ?: @"Azione non riconosciuta"
                  presenter:presenter];
            return;
        }

    } else {
        [self showTitle:@"Azione non supportata"
                message:kind
              presenter:presenter];
        return;
    }

    NSString *confirmationText =
        NHAActionString(
            NHAActionDict(action[@"confirmation"])[@"text"]);

    if (!confirmationText.length && sensitive) {
        confirmationText = destructive
            ? @"Confermi l'arresto forzato della VM NAS?"
            : @"Confermi l'accensione o lo spegnimento "
              "graceful della VM NAS?";
    }

    if (confirmationText.length) {
        UIAlertController *confirmation =
            [UIAlertController
                alertControllerWithTitle:
                    destructive
                        ? @"Operazione forzata"
                        : @"Conferma azione"
                                 message:confirmationText
                          preferredStyle:
                            UIAlertControllerStyleAlert];

        [confirmation addAction:[UIAlertAction
            actionWithTitle:@"Annulla"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

        [confirmation addAction:[UIAlertAction
            actionWithTitle:@"Conferma"
                      style:destructive
                        ? UIAlertActionStyleDestructive
                        : UIAlertActionStyleDefault
                    handler:^(UIAlertAction *selected) {
            [self executeDomain:domain
                       service:service
                       payload:payload
                     presenter:presenter];
        }]];

        [presenter presentViewController:confirmation
                               animated:YES
                             completion:nil];
    } else {
        [self executeDomain:domain
                   service:service
                   payload:payload
                 presenter:presenter];
    }
}

// NineHA.LightBrightness6C2
// Riutilizziamo autenticazione e REST esistenti.

- (void)setLightBrightness:(NSString *)entity
                percentage:(NSInteger)percentage
                 presenter:(UIViewController *)presenter {

    NSArray *parts =
        [entity componentsSeparatedByString:@"."];

    if (parts.count != 2 ||
        ![parts[0] isEqualToString:@"light"] ||
        ![self validIdentifier:entity] ||
        percentage < 1 ||
        percentage > 100) {
        return;
    }

    [self executeDomain:@"light"
               service:@"turn_on"
               payload:@{
                   @"entity_id": entity,
                   @"brightness_pct": @(percentage)
               }
             presenter:presenter];
}

#pragma mark - REST execution

- (void)executeDomain:(NSString *)domain
              service:(NSString *)service
              payload:(NSDictionary *)payload
            presenter:(UIViewController *)presenter {

    if (self.busy || !presenter.view.window) return;

    NSURLComponents *base =
        [NSURLComponents
            componentsWithString:self.auth.serverURL];

    if (!NineHAAllowedServerURL(base)) {
        [self showTitle:@"Server non valido"
                message:@"Endpoint Home Assistant non consentito."
              presenter:presenter];
        return;
    }

    if (![self validIdentifier:domain] ||
        ![self validIdentifier:service]) {
        return;
    }

    NSString *address = [NSString stringWithFormat:
        @"%@/api/services/%@/%@",
        self.auth.serverURL, domain, service];

    NSURL *url = [NSURL URLWithString:address];

    if (!url) return;

    self.busy = YES;
    __weak UIViewController *weakPresenter = presenter;

    NineAuthCompletion callback =
        ^(NSString *token, NSError *authError) {

        dispatch_async(dispatch_get_main_queue(), ^{

            UIViewController *owner = weakPresenter;

            if (!owner || !owner.view.window) {
                self.busy = NO;
                return;
            }

            if (authError || !token.length) {
                self.busy = NO;

                [self showTitle:@"Autenticazione"
                        message:@"Token non disponibile."
                      presenter:owner];
                return;
            }

            NSData *body = [NSJSONSerialization
                dataWithJSONObject:payload
                           options:0
                             error:nil];

            if (!body) {
                self.busy = NO;
                return;
            }

            NSMutableURLRequest *request =
                [NSMutableURLRequest requestWithURL:url];

            request.HTTPMethod = @"POST";
            request.HTTPBody = body;
            request.timeoutInterval = 20;

            [request setValue:@"application/json"
                forHTTPHeaderField:@"Content-Type"];

            [request setValue:
                [@"Bearer " stringByAppendingString:token]
                forHTTPHeaderField:@"Authorization"];

            NSURLSessionConfiguration *configuration =
                [NSURLSessionConfiguration
                    ephemeralSessionConfiguration];

            self.session = [NSURLSession
                sessionWithConfiguration:configuration
                               delegate:self
                          delegateQueue:nil];

            NSURLSession *session = self.session;

            [[session dataTaskWithRequest:request
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *networkError) {

                NSInteger status =
                    [response
                        isKindOfClass:[NSHTTPURLResponse class]]
                    ? [(NSHTTPURLResponse *)response statusCode]
                    : 0;

                dispatch_async(dispatch_get_main_queue(), ^{
                    self.busy = NO;

                    if (self.session == session) {
                        self.session = nil;
                    }

                    [session finishTasksAndInvalidate];

                    UIViewController *current = weakPresenter;

                    if (!current || !current.view.window)
                        return;

                    if (networkError ||
                        status < 200 || status >= 300) {

                        NSString *message = networkError
                            ? @"Connessione al server non riuscita."
                            : [NSString stringWithFormat:
                                @"Home Assistant: HTTP %ld",
                                (long)status];

                        [self showTitle:@"Comando non riuscito"
                                message:message
                              presenter:current];
                    }
                    // Nessun cambio stato ottimistico:
                    // attendiamo state_changed da HA.
                });

            }] resume];
        });
    };

    if ([self.mode isEqualToString:@"oauth"]) {
        [self.auth useOAuthToken:callback];
    } else {
        [self.auth useManualToken:callback];
    }
}

#pragma mark - Redirect protection

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)cancel {
    [self.session invalidateAndCancel];
    self.session = nil;
    self.busy = NO;
}

- (void)dealloc {
    [self cancel];
}

@end
