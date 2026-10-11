#import <UIKit/UIKit.h>
#import "Sources/NineAuth.h"
#import "Sources/NineHomeDashboard.h"
#import "Sources/NineIcons.h"
#import "Sources/NineTheme.h"

@interface NineSetupController : UIViewController

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UITextField *clientField;
@property (nonatomic, strong) UITextField *userField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UITextView *output;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *column;
@property (nonatomic, strong) UIView *card;

- (void)receiveOAuth:(NSURL *)url;
- (UIViewController *)initialDashboardIfAvailable;
- (void)rememberCurrentServer;
- (void)loadDefaultProfileForLaunch;
- (void)selectServerProfile:(NSDictionary *)profile;
- (void)beginAddingServer;

@end

@implementation NineSetupController

- (void)showStatus:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.output.text = message;
    });
}

- (UITextField *)addField:(NSString *)placeholder
                    label:(NSString *)title
                        y:(CGFloat)y
                   parent:(UIView *)parent {

    CGFloat width = parent.bounds.size.width - 40;

    UILabel *label = [[UILabel alloc]
        initWithFrame:CGRectMake(20, y, width, 18)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.text = title;
    label.font = NTMediumFont(12);
    label.textColor = NTSecondaryText();
    [parent addSubview:label];

    UITextField *field = [[UITextField alloc]
        initWithFrame:CGRectMake(20, y + 22, width, 44)];

    field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = NTHex(0xFFFFFF, .06f);
    field.layer.cornerRadius = 8;
    field.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
    field.layer.borderColor = NTBorder().CGColor;
    field.textColor = NTText();
    field.font = NTFont(16);
    field.tintColor = NTPrimary();
    field.keyboardAppearance = UIKeyboardAppearanceDark;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:placeholder
            attributes:@{NSForegroundColorAttributeName: NTDisabledText()}];
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeURL;

    [parent addSubview:field];
    return field;
}

- (UIButton *)addButton:(NSString *)title
                   icon:(NSString *)icon
                  style:(NSInteger)style
                  frame:(CGRect)frame
                 parent:(UIView *)parent
                 action:(SEL)action {

    // style 0 = primario pieno, 1 = tonale, 2 = solo testo
    UIColor *background = style == 0 ? NTPrimary()
        : (style == 1 ? [NTPrimary() colorWithAlphaComponent:.14f]
                      : [UIColor clearColor]);
    UIColor *foreground = style == 0 ? [UIColor whiteColor] : NTPrimary();

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    button.backgroundColor = background;
    button.layer.cornerRadius = 10;

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
    NSString *glyph = NineIconGlyph(icon);

    if (glyph) {
        [text appendAttributedString:[[NSAttributedString alloc]
            initWithString:[glyph stringByAppendingString:@"  "]
                attributes:@{NSFontAttributeName: NineIconFont(18),
                             NSForegroundColorAttributeName: foreground,
                             NSBaselineOffsetAttributeName: @(-2)}]];
    }

    [text appendAttributedString:[[NSAttributedString alloc]
        initWithString:title
            attributes:@{NSFontAttributeName: NTMediumFont(15),
                         NSForegroundColorAttributeName: foreground}]];

    [button setAttributedTitle:text forState:UIControlStateNormal];

    NSMutableAttributedString *pressed = [text mutableCopy];
    [pressed addAttribute:NSForegroundColorAttributeName
                    value:[foreground colorWithAlphaComponent:.5f]
                    range:NSMakeRange(0, pressed.length)];
    [button setAttributedTitle:pressed forState:UIControlStateHighlighted];

    [button addTarget:self
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    [parent addSubview:button];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"NineHA";
    self.view.backgroundColor = NTBackground();
    self.auth = [[NineAuth alloc] init];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.mode = [defaults stringForKey:@"NineHA.Mode"] ?: @"manual";

    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [self.view addSubview:self.scroll];

    CGFloat width = 440;
    self.column = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, width, 760)];
    [self.scroll addSubview:self.column];

    UIImageView *logo = [[UIImageView alloc]
        initWithFrame:CGRectMake((width - 84) / 2, 36, 84, 84)];
    logo.image = [UIImage imageNamed:@"Icon-76"]
        ?: [UIImage imageNamed:@"Icon-60"];
    logo.layer.cornerRadius = 19;
    logo.clipsToBounds = YES;
    logo.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin;
    [self.column addSubview:logo];

    UILabel *heading = [[UILabel alloc]
        initWithFrame:CGRectMake(0, 132, width, 36)];
    heading.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    heading.text = @"NineHA";
    heading.textAlignment = NSTextAlignmentCenter;
    heading.font = NTMediumFont(30);
    heading.textColor = NTText();
    [self.column addSubview:heading];

    NSString *version = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    UILabel *subtitle = [[UILabel alloc]
        initWithFrame:CGRectMake(0, 168, width, 22)];
    subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    subtitle.text = [NSString stringWithFormat:
        @"Client Home Assistant per iOS 9 · %@", version ?: @""];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.font = NTFont(14);
    subtitle.textColor = NTSecondaryText();
    [self.column addSubview:subtitle];

    self.card = [[UIView alloc]
        initWithFrame:CGRectMake(0, 212, width, 424)];
    self.card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.card.backgroundColor = NTCard();
    self.card.layer.cornerRadius = 16;
    self.card.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
    self.card.layer.borderColor = NTBorder().CGColor;
    [self.column addSubview:self.card];

    self.serverField =
        [self addField:@"http://homeassistant.local:8123"
                 label:@"INDIRIZZO DEL SERVER"
                     y:20 parent:self.card];

    self.serverField.text =
        [defaults stringForKey:@"NineHA.Server"];

    // Il Client ID serve solo per OAuth: viene chiesto al momento.
    self.clientField = [[UITextField alloc] init];
    self.clientField.text =
        [defaults stringForKey:@"NineHA.ClientID"];

    self.userField =
        [self addField:@"Nome utente"
                 label:@"NOME UTENTE"
                     y:94 parent:self.card];
    self.userField.keyboardType = UIKeyboardTypeDefault;
    self.userField.text = [defaults stringForKey:@"NineHA.Username"];

    self.passwordField =
        [self addField:@"Password"
                 label:@"PASSWORD"
                     y:168 parent:self.card];
    self.passwordField.keyboardType = UIKeyboardTypeDefault;
    self.passwordField.secureTextEntry = YES;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    [self.passwordField addTarget:self
                           action:@selector(loginWithPassword)
                 forControlEvents:UIControlEventEditingDidEndOnExit];

    CGFloat inner = width - 40;

    self.loginButton =
        [self addButton:@"Accedi" icon:@"login"
                  style:0 frame:CGRectMake(20, 254, inner, 48)
                 parent:self.card action:@selector(loginWithPassword)];

    CGFloat half = (inner - 10) / 2;

    UIButton *token =
        [self addButton:@"Token" icon:@"key-variant"
                  style:1 frame:CGRectMake(20, 312, half, 44)
                 parent:self.card action:@selector(saveManual)];
    token.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleRightMargin;

    UIButton *oauth =
        [self addButton:@"OAuth" icon:@"shield-account"
                  style:1 frame:CGRectMake(30 + half, 312, half, 44)
                 parent:self.card action:@selector(askOAuthClient)];
    oauth.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleLeftMargin;

    UIButton *open =
        [self addButton:@"Apri la dashboard" icon:nil
                  style:2 frame:CGRectMake(20, 366, half, 40)
                 parent:self.card action:@selector(openDashboard)];
    open.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleRightMargin;

    UIButton *check =
        [self addButton:@"Verifica connessione" icon:nil
                  style:2 frame:CGRectMake(30 + half, 366, half, 40)
                 parent:self.card action:@selector(readStates)];
    check.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleLeftMargin;

    self.output = [[UITextView alloc]
        initWithFrame:CGRectMake(0, 650, width, 110)];
    self.output.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.output.editable = NO;
    self.output.font = NTFont(13);
    self.output.textColor = NTSecondaryText();
    self.output.backgroundColor = [UIColor clearColor];
    self.output.textAlignment = NSTextAlignmentCenter;
    self.output.scrollEnabled = NO;

    self.output.text =
        @"Accedi con il tuo utente Home Assistant, oppure usa un "
         "token di accesso a lunga durata (Profilo > Sicurezza). "
         "La password non viene salvata sul dispositivo.";

    [self.column addSubview:self.output];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize size = self.view.bounds.size;
    CGFloat width = MIN((CGFloat)440, size.width - 32);
    CGFloat height = 770;

    // Colonna centrata, anche verticalmente quando c'è spazio.
    CGFloat top = MAX((CGFloat)0, floorf((size.height - height) / 2));

    self.column.frame = CGRectMake(floorf((size.width - width) / 2),
                                   top, width, height);
    self.scroll.contentSize = CGSizeMake(size.width, top + height);
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

- (void)loginWithPassword {
    if (![self prepareConnection]) return;

    NSString *username = [self.userField.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text ?: @"";

    if (!username.length || !password.length) {
        [self showStatus:@"Inserisci nome utente e password."];
        return;
    }

    [[NSUserDefaults standardUserDefaults]
        setObject:username forKey:@"NineHA.Username"];

    self.loginButton.enabled = NO;
    self.loginButton.alpha = .5f;
    [self showStatus:@"Accesso in corso..."];

    __weak typeof(self) weakSelf = self;

    [self.auth loginWithUsername:username
                        password:password
                      mfaHandler:^(NineAuthMFAResponder respond) {
        [weakSelf askMFACode:respond];
    } completion:^(NSString *token, NSError *error) {
        NineSetupController *owner = weakSelf;
        if (!owner) return;

        owner.loginButton.enabled = YES;
        owner.loginButton.alpha = 1;
        owner.passwordField.text = @"";

        if (error || !token.length) {
            [owner showStatus:error.localizedDescription
                ?: @"Accesso non riuscito."];
            return;
        }

        [owner selectAuthMode:@"password"];
        [owner rememberCurrentServer];
        [owner showStatus:@"Accesso eseguito."];
        [owner.navigationController
            pushViewController:[owner ninehaConfiguredDashboard]
                      animated:YES];
    }];
}

- (void)askMFACode:(NineAuthMFAResponder)respond {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Verifica in due passaggi"
                         message:@"Inserisci il codice dell'app di autenticazione."
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Codice";
        field.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *a) {
        respond(nil);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Verifica"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        respond(alert.textFields.firstObject.text ?: @"");
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)askOAuthClient {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Accesso OAuth"
                         message:@"Client ID HTTPS registrato per NineHA."
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://client.example.com";
        field.text = self.clientField.text;
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Continua"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        self.clientField.text = alert.textFields.firstObject.text;
        [self startOAuth];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
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
        ![self.auth hasOAuthSession] &&
        ![self.auth hasPasswordSession]) {
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
        [@[@"oauth", @"password"] containsObject:mode] ? mode : @"manual"];

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
        @"Nuovo server: inserisci l'indirizzo e salva un token. "
         "Gli altri server resteranno memorizzati."];
}


- (UIViewController *)ninehaConfiguredDashboard {
    return [[NineHomeDashboard alloc]
        initWithAuth:self.auth mode:self.mode];
}

- (UIViewController *)initialDashboardIfAvailable {
    if (!self.serverField.text.length) return nil;

    if (![self prepareConnection]) return nil;

    // Se la modalità scelta non ha credenziali,
    // selezioniamo la prima che le possiede.
    if (![self.auth hasCredentialsForMode:self.mode]) {
        NSString *available = nil;
        for (NSString *mode in @[@"password", @"manual", @"oauth"]) {
            if ([self.auth hasCredentialsForMode:mode]) {
                available = mode;
                break;
            }
        }
        if (!available) return nil;
        [self selectAuthMode:available];
    }

    [self rememberCurrentServer];

    return [self ninehaConfiguredDashboard];
}

- (void)openDashboard {
    if (![self prepareConnection]) return;

    BOOL hasCredentials = [self.auth hasCredentialsForMode:self.mode];

    if (!hasCredentials) {
        [self showStatus:
            @"Salva prima un token oppure accedi con OAuth."];
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

            [self showStatus:[NSString stringWithFormat:
                @"Connessione riuscita (%@).\n"
                 "%lu entità disponibili. Tocca \"Apri la dashboard\".",
                [self.mode isEqualToString:@"oauth"] ? @"OAuth"
                    : ([self.mode isEqualToString:@"password"]
                        ? @"utente e password" : @"token"),
                (unsigned long)states.count]];

        }] resume];
    };

    [self.auth useTokenForMode:self.mode completion:completion];
}

@end

@interface NineHAAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NineSetupController *home;
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
    self.window.backgroundColor = NTBackground();
    self.window.tintColor = NTPrimary();

    NTApplyAppearance();

    self.home = [[NineSetupController alloc] init];

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
