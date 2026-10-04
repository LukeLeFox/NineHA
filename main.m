#import <UIKit/UIKit.h>
#import "Sources/NineAuth.h"
#import "Sources/NineDashboard.h"
#import "Sources/NineTilesController.h"
#import "Sources/NineLovelaceController.h"
#import "Sources/NineUnstableSettingsController.h"

@interface NineHomeController : UIViewController

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UITextField *clientField;
@property (nonatomic, strong) UITextView *output;
@property (nonatomic, copy) NSString *mode;

- (void)receiveOAuth:(NSURL *)url;
- (UIViewController *)initialDashboardIfAvailable;
- (void)rememberCurrentServer;
- (void)loadDefaultProfileForLaunch;
- (void)selectServerProfile:(NSDictionary *)profile;
- (void)beginAddingServer;

@end

@implementation NineHomeController

- (void)showStatus:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.output.text = message;
    });
}

- (UITextField *)addField:(NSString *)placeholder
                       y:(CGFloat)y
                  parent:(UIView *)parent {

    UITextField *field = [[UITextField alloc]
        initWithFrame:CGRectMake(15, y,
                                 parent.bounds.size.width - 30, 38)];

    field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = placeholder;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeURL;

    [parent addSubview:field];
    return field;
}

- (void)addButton:(NSString *)title
                y:(CGFloat)y
           parent:(UIView *)parent
           action:(SEL)action {

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    button.frame = CGRectMake(15, y,
                              parent.bounds.size.width - 30, 44);

    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    button.backgroundColor =
        [UIColor colorWithRed:0.08 green:0.48 blue:0.75 alpha:1];

    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor]
                 forState:UIControlStateNormal];

    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    [parent addSubview:button];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *version = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    self.title = [NSString stringWithFormat:
        @"NineHA %@", version ?: @""];
    self.view.backgroundColor = [UIColor whiteColor];
    self.auth = [[NineAuth alloc] init];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.mode = [defaults stringForKey:@"NineHA.Mode"] ?: @"manual";

    UIScrollView *scroll = [[UIScrollView alloc]
        initWithFrame:self.view.bounds];

    scroll.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    scroll.contentSize = CGSizeMake(self.view.bounds.size.width, 720);
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 720)];

    content.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [scroll addSubview:content];

    UILabel *heading = [[UILabel alloc]
        initWithFrame:CGRectMake(15, 10,
                                 content.bounds.size.width - 30, 46)];

    heading.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    heading.text = @"Home Assistant - iOS 9";
    heading.font = [UIFont boldSystemFontOfSize:21];
    [content addSubview:heading];

    self.serverField =
        [self addField:@"https://home.example.com"
                    y:70 parent:content];

    self.serverField.text =
        [defaults stringForKey:@"NineHA.Server"];

    self.clientField =
        [self addField:@"Client ID OAuth HTTPS (opzionale)"
                    y:120 parent:content];

    self.clientField.text =
        [defaults stringForKey:@"NineHA.ClientID"];

    [self addButton:@"Salva token manuale"
                  y:185 parent:content
             action:@selector(saveManual)];

    [self addButton:@"Usa token salvato"
                  y:239 parent:content
             action:@selector(useManual)];

    [self addButton:@"Accedi con OAuth"
                  y:293 parent:content
             action:@selector(startOAuth)];

    [self addButton:@"Verifica API e leggi entità"
                  y:347 parent:content
             action:@selector(readStates)];

    [self addButton:@"Apri dashboard"
                  y:401 parent:content
             action:@selector(openDashboard)];

    self.output = [[UITextView alloc]
        initWithFrame:CGRectMake(15, 460,
                                 content.bounds.size.width - 30, 240)];

    self.output.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.output.editable = NO;
    self.output.font = [UIFont systemFontOfSize:14];
    self.output.backgroundColor =
        [UIColor colorWithWhite:0.94 alpha:1];

    self.output.text =
        @"Configura il server Home Assistant.\n"
         "Scegli token manuale oppure OAuth.";

    [content addSubview:self.output];
}

- (BOOL)prepareConnection {
    [self.view endEditing:YES];

    NSString *server = [self.serverField.text
        stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    while ([server hasSuffix:@"/"]) {
        server = [server substringToIndex:server.length - 1];
    }

    NSURLComponents *components =
        [NSURLComponents componentsWithString:server];

    if (!NineHAAllowedServerURL(components)) {

        [self showStatus:
            @"Usa HTTPS oppure HTTP con IP privato, senza percorso."];
        return NO;
    }

    NSString *client = [self.clientField.text
        stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSString *newClient = client ?: @"";

    if (self.auth.serverURL.length &&
        (![self.auth.serverURL isEqualToString:server] ||
         ![(self.auth.clientID ?: @"")
            isEqualToString:newClient])) {
        self.auth = [[NineAuth alloc] init];
    }

    self.auth.serverURL = server;
    self.auth.clientID = newClient;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:server forKey:@"NineHA.Server"];
    [defaults setObject:self.auth.clientID forKey:@"NineHA.ClientID"];

    return YES;
}

- (void)selectAuthMode:(NSString *)mode {
    self.mode = mode;

    [[NSUserDefaults standardUserDefaults]
        setObject:mode forKey:@"NineHA.Mode"];
}

- (void)saveManual {
    if (![self prepareConnection]) return;

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Token Home Assistant"
                         message:@"Inserisci il Long-Lived Access Token"
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Token";
        field.secureTextEntry = YES;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"Annulla"
                  style:UIAlertActionStyleCancel
                handler:nil]];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"Salva"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        NSString *token = alert.textFields.firstObject.text;

        if (![self.auth saveManualToken:token]) {
            [self showStatus:[NSString stringWithFormat:@"Errore Keychain: %ld", (long)self.auth.lastKeychainStatus]];
            return;
        }

        [self selectAuthMode:@"manual"];
        [self rememberCurrentServer];
        [self readStates];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)useManual {
    if (![self prepareConnection]) return;

    if (![self.auth hasManualToken]) {
        [self showStatus:
            @"Nessun token salvato per questo server."];
        return;
    }

    [self selectAuthMode:@"manual"];
    [self rememberCurrentServer];
    [self readStates];
}

- (void)startOAuth {
    if (![self prepareConnection]) return;

    NSURL *url = [self.auth authorizationURL];

    if (!url) {
        [self showStatus:
            @"Per OAuth devi configurare un Client ID HTTPS valido."];
        return;
    }

    [self showStatus:@"Apertura autorizzazione Home Assistant..."];
    [[UIApplication sharedApplication] openURL:url];
}

- (void)receiveOAuth:(NSURL *)url {
    if (![self prepareConnection]) return;

    [self.auth handleCallbackURL:url
                      completion:^(NSString *token, NSError *error) {

        if (error || !token.length) {
            [self showStatus:[NSString stringWithFormat:
                @"OAuth non riuscito: %@\n"
                 "Puoi utilizzare il token manuale.",
                error.localizedDescription ?: @"Errore sconosciuto"]];
            return;
        }

        [self selectAuthMode:@"oauth"];
        [self rememberCurrentServer];
        [self readStates];
    }];
}


- (void)rememberCurrentServer {
    NSString *url = self.auth.serverURL;

    if (!url.length) return;

    // Mai memorizzare token in NSUserDefaults.
    // Registriamo solo istanze con credenziali nel Keychain.
    if (![self.auth hasManualToken] &&
        ![self.auth hasOAuthSession]) {
        return;
    }

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    NSArray *old = [defaults arrayForKey:@"NineHA.Servers"] ?: @[];
    NSMutableArray *profiles = [NSMutableArray array];

    NSDictionary *current = @{
        @"url": url,
        @"clientID": self.auth.clientID ?: @"",
        @"mode": self.mode ?: @"manual"
    };

    BOOL found = NO;

    for (id item in old) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSString *existing = item[@"url"];

        if ([existing isKindOfClass:[NSString class]] &&
            [existing isEqualToString:url]) {
            if (!found) {
                [profiles addObject:current];
                found = YES;
            }
        } else {
            [profiles addObject:item];
        }
    }

    if (!found) {
        [profiles addObject:current];
    }

    [defaults setObject:profiles forKey:@"NineHA.Servers"];

    // Il primo server rimane predefinito finché
    // l'utente non ne sceglie esplicitamente un altro.
    if (![defaults stringForKey:@"NineHA.DefaultServer"]) {
        [defaults setObject:url forKey:@"NineHA.DefaultServer"];
    }
}

- (void)selectServerProfile:(NSDictionary *)profile {
    NSString *url = profile[@"url"];
    NSString *client = profile[@"clientID"];
    NSString *mode = profile[@"mode"];

    if (![url isKindOfClass:[NSString class]] ||
        !url.length) {
        return;
    }

    self.serverField.text = url;
    self.clientField.text =
        [client isKindOfClass:[NSString class]] ? client : @"";

    // Ogni cambio server riparte senza token OAuth in cache.
    self.auth = [[NineAuth alloc] init];

    [self selectAuthMode:
        [mode isEqualToString:@"oauth"] ? @"oauth" : @"manual"];

    [self prepareConnection];
}

- (void)loadDefaultProfileForLaunch {
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    // Migrazione automatica del server unico della 0.5.0.
    if (self.serverField.text.length &&
        [self prepareConnection]) {
        [self rememberCurrentServer];
    }

    NSArray *profiles =
        [defaults arrayForKey:@"NineHA.Servers"];

    if (!profiles.count) return;

    NSString *preferred =
        [defaults stringForKey:@"NineHA.DefaultServer"];

    NSDictionary *selected = nil;

    for (id item in profiles) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSString *url = item[@"url"];
        if (![url isKindOfClass:[NSString class]]) continue;

        if ([url isEqualToString:preferred]) {
            selected = item;
            break;
        }
    }

    if (!selected) {
        for (id item in profiles) {
            if ([item isKindOfClass:[NSDictionary class]] &&
                [item[@"url"] isKindOfClass:[NSString class]]) {
                selected = item;
                break;
            }
        }
    }

    if (selected) [self selectServerProfile:selected];
}

- (void)beginAddingServer {
    [self.view endEditing:YES];

    self.serverField.text = @"";
    self.clientField.text = @"";

    self.auth = [[NineAuth alloc] init];
    [self selectAuthMode:@"manual"];

    [self showStatus:
        @"Nuovo server.\n"
         "Inserisci l'indirizzo e salva un token.\n"
         "Gli altri server resteranno memorizzati."];
}


- (UIViewController *)ninehaConfiguredDashboard {

    NSString *choice =
        [NineUnstableSettingsController
            startupModeForServerURL:self.auth.serverURL];

    if ([choice isEqualToString:@"native"]) {
        return [[NineTilesController alloc]
            initWithAuth:self.auth mode:self.mode];
    }

    if ([choice isEqualToString:@"original"]) {
        return [[NineLegacyWebController alloc]
            initWithAuth:self.auth mode:self.mode];
    }

    return [[NineLovelaceController alloc]
        initWithAuth:self.auth mode:self.mode];
}

- (UIViewController *)initialDashboardIfAvailable {
    if (!self.serverField.text.length) return nil;

    if (![self prepareConnection]) return nil;

    BOOL manual = [self.auth hasManualToken];
    BOOL oauth = [self.auth hasOAuthSession];

    if (!manual && !oauth) return nil;

    // Se la modalità scelta non è disponibile,
    // selezioniamo quella che possiede credenziali.
    if ([self.mode isEqualToString:@"oauth"]) {
        if (!oauth && manual) {
            [self selectAuthMode:@"manual"];
        }
    } else if (!manual && oauth) {
        [self selectAuthMode:@"oauth"];
    }

    [self rememberCurrentServer];

    return [self ninehaConfiguredDashboard];
}

- (void)openDashboard {
    if (![self prepareConnection]) return;

    BOOL oauth = [self.mode isEqualToString:@"oauth"];
    BOOL hasCredentials = oauth
        ? [self.auth hasOAuthSession]
        : [self.auth hasManualToken];

    if (!hasCredentials) {
        [self showStatus:
            @"Configura prima una modalità di autenticazione."];
        return;
    }

    UIViewController *dashboard =
        [self ninehaConfiguredDashboard];

    [self.navigationController
        pushViewController:dashboard animated:YES];
}

- (void)readStates {
    if (![self prepareConnection]) return;

    [self showStatus:@"Connessione a Home Assistant..."];

    NineAuthCompletion completion =
        ^(NSString *token, NSError *error) {

        if (error || !token.length) {
            [self showStatus:error.localizedDescription
                ?: @"Token non disponibile."];
            return;
        }

        NSString *urlString =
            [self.auth.serverURL stringByAppendingString:@"/api/states"];

        NSMutableURLRequest *request =
            [NSMutableURLRequest requestWithURL:
                [NSURL URLWithString:urlString]];

        request.timeoutInterval = 20;

        [request setValue:
            [@"Bearer " stringByAppendingString:token]
            forHTTPHeaderField:@"Authorization"];

        [request setValue:@"application/json"
            forHTTPHeaderField:@"Accept"];

        [[[NSURLSession sharedSession]
          dataTaskWithRequest:request
          completionHandler:^(NSData *data,
                              NSURLResponse *response,
                              NSError *networkError) {

            if (networkError) {
                [self showStatus:[NSString stringWithFormat:
                    @"Errore connessione:\n%@",
                    networkError.localizedDescription]];
                return;
            }

            NSInteger status =
                [(NSHTTPURLResponse *)response statusCode];

            if (status != 200) {
                [self showStatus:[NSString stringWithFormat:
                    @"Home Assistant: HTTP %ld",
                    (long)status]];
                return;
            }

            NSError *jsonError = nil;

            id json = data.length
                ? [NSJSONSerialization JSONObjectWithData:data
                                                 options:0
                                                   error:&jsonError]
                : nil;

            if (![json isKindOfClass:[NSArray class]]) {
                [self showStatus:@"Risposta API non valida."];
                return;
            }

            NSArray *states = (NSArray *)json;

            NSMutableString *result =
                [NSMutableString stringWithFormat:
                    @"CONNESSIONE RIUSCITA\n"
                     "Modalità: %@\n"
                     "Entità: %lu\n\n",
                    self.mode,
                    (unsigned long)states.count];

            NSUInteger limit = MIN((NSUInteger)8, states.count);

            for (NSUInteger i = 0; i < limit; i++) {
                NSDictionary *entity = states[i];

                if (![entity isKindOfClass:[NSDictionary class]]) {
                    continue;
                }

                NSDictionary *attributes = entity[@"attributes"];

                NSString *name = nil;
                if ([attributes isKindOfClass:[NSDictionary class]]) {
                    id friendly = attributes[@"friendly_name"];
                    if ([friendly isKindOfClass:[NSString class]]) {
                        name = friendly;
                    }
                }

                if (!name.length) {
                    name = entity[@"entity_id"];
                }

                id value = entity[@"state"];

                [result appendFormat:@"%@: %@\n",
                    name ?: @"Entità",
                    value ?: @"N/D"];
            }

            [self showStatus:result];

        }] resume];
    };

    if ([self.mode isEqualToString:@"oauth"]) {
        [self.auth useOAuthToken:completion];
    } else {
        [self.auth useManualToken:completion];
    }
}

@end

@interface NineHAAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NineHomeController *home;
@end

@implementation NineHAAppDelegate

- (void)handleServerAction:(NSNotification *)notification {
    NSDictionary *details = [notification.userInfo copy];

    // Evitiamo di modificare lo stack mentre UITableView
    // sta ancora elaborando la selezione della riga.
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *navigation =
            (UINavigationController *)self.window.rootViewController;

        if (![navigation isKindOfClass:[UINavigationController class]])
            return;

        NSString *action = details[@"action"];

        if ([action isEqualToString:@"add"]) {
            [self.home beginAddingServer];

            [navigation setViewControllers:@[self.home]
                                  animated:NO];
            return;
        }

        if ([action isEqualToString:@"switch"]) {
            NSDictionary *profile = details[@"profile"];

            if (![profile isKindOfClass:[NSDictionary class]]) return;

            [self.home selectServerProfile:profile];

            UIViewController *dashboard =
                [self.home initialDashboardIfAvailable];

            if (dashboard) {
                [navigation setViewControllers:
                    @[self.home, dashboard] animated:NO];
            } else {
                [navigation setViewControllers:
                    @[self.home] animated:NO];
            }
        }
    });
}


- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)options {

    self.window = [[UIWindow alloc]
        initWithFrame:[UIScreen mainScreen].bounds];

    self.home = [[NineHomeController alloc] init];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleServerAction:)
               name:@"NineHA.ServerAction"
             object:nil];

    UINavigationController *navigation =
        [[UINavigationController alloc]
         initWithRootViewController:self.home];

    // Carichiamo i campi e le preferenze della schermata iniziale.
    (void)self.home.view;

    // Preferenza dell'utente oppure server unico preesistente.
    [self.home loadDefaultProfileForLaunch];

    UIViewController *initial =
        [self.home initialDashboardIfAvailable];

    if (initial) {
        [navigation setViewControllers:
            @[self.home, initial] animated:NO];
    }

    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];

    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary *)options {

    if (![[url.scheme lowercaseString] isEqualToString:@"nineha"] ||
        ![[url.host lowercaseString] isEqualToString:@"auth"]) {
        return NO;
    }

    [self.home receiveOAuth:url];
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(
            argc,
            argv,
            nil,
            NSStringFromClass([NineHAAppDelegate class])
        );
    }
}
