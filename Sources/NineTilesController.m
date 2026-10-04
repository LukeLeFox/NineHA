#import "NineTilesController.h"
#import "NineDashboard.h"
#import "NineGlyphView.h"
#import "NineAreasLoader.h"
#import "NineServersController.h"
#import "NineLovelaceController.h"
#import "NineLovelaceLive.h"
#import "NineUnstableSettingsController.h"
#import <math.h>

@interface NineLightLevelController : UIViewController
@property (nonatomic, copy) NSString *lightName;
@property (nonatomic, assign) NSInteger initialLevel;
@property (nonatomic, copy) void (^onApply)(NSInteger);
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *percentage;
@end

@implementation NineLightLevelController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Luminosità";
    self.view.backgroundColor = [UIColor blackColor];

    CGFloat width = self.view.bounds.size.width;

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 80, width - 40, 70)];
    name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont boldSystemFontOfSize:22];
    name.numberOfLines = 2;
    name.textAlignment = NSTextAlignmentCenter;
    name.text = self.lightName;
    [self.view addSubview:name];

    self.percentage = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 170, width - 40, 50)];
    self.percentage.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.percentage.textColor = [UIColor whiteColor];
    self.percentage.textAlignment = NSTextAlignmentCenter;
    self.percentage.font = [UIFont systemFontOfSize:30];
    [self.view addSubview:self.percentage];

    self.slider = [[UISlider alloc]
        initWithFrame:CGRectMake(25, 245, width - 50, 45)];
    self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.slider.minimumValue = 1;
    self.slider.maximumValue = 100;
    self.slider.value = MAX(1, MIN(100, self.initialLevel));
    [self.slider addTarget:self
                    action:@selector(updatePercentage)
          forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.slider];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
         initWithTitle:@"Applica"
                 style:UIBarButtonItemStyleDone
                target:self
                action:@selector(applyLevel)];

    [self updatePercentage];
}

- (void)updatePercentage {
    self.percentage.text = [NSString stringWithFormat:
        @"%ld%%", (long)lroundf(self.slider.value)];
}

- (void)applyLevel {
    NSInteger level = (NSInteger)lroundf(self.slider.value);
    if (self.onApply) self.onApply(level);
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@interface NineTilesController () <NSURLSessionTaskDelegate>
@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NSArray *states;
@property (nonatomic, strong) NSDictionary *stateByID;
@property (nonatomic, strong) NSDictionary *areaByID;
@property (nonatomic, strong) NSArray *configuredAreaNames;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) UIScrollView *roomsScroll;
@property (nonatomic, copy) NSString *selectedRoom;
@property (nonatomic, strong) NSMutableSet *favorites;
@property (nonatomic, strong) NSMutableSet *hiddenEntities;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NineLovelaceLive *nativeLive;
@property (nonatomic, strong) NSTimer *nativeRetryTimer;
@property (nonatomic, strong) NSTimer *nativeDrawTimer;
@property (nonatomic, strong) NSMutableDictionary *nativeChanges;
@property (nonatomic, assign) BOOL nativeConnected;
@property (nonatomic, assign) BOOL nativeConnecting;
@property (nonatomic, assign) NSUInteger nativeEpoch;
@property (nonatomic, assign) NSInteger nativeRetryCount;
@property (nonatomic, strong) UIControl *drawerShade;
@property (nonatomic, strong) UIView *drawerPanel;
@property (nonatomic, assign) BOOL drawerClosing;
@property (nonatomic, strong) UIView *brightnessOverlay;
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UILabel *brightnessLabel;
@property (nonatomic, copy) NSString *brightnessEntityID;
@property (nonatomic, strong) UIView *temperatureOverlay;
@property (nonatomic, strong) UIStepper *temperatureStepper;
@property (nonatomic, strong) UILabel *temperatureValue;
@property (nonatomic, copy) NSString *temperatureEntityID;
@property (nonatomic, copy) NSString *temperatureUnit;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL requestedAreas;
@property (nonatomic, copy) NSString *areasStatus;
@property (nonatomic, strong) NineAreasLoader *areasLoader;
@property (nonatomic, assign) NSUInteger areaFetchGeneration;
@end

@implementation NineTilesController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _auth = auth;
        _mode = [mode copy];
        _states = @[];
        _stateByID = @{};
        _areaByID = @{};
        _sections = @[];
        _favorites = [NSMutableSet set];
        _hiddenEntities = [NSMutableSet set];
    }
    return self;
}

- (void)createSession {
    if (self.session) return;

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 20;
    config.timeoutIntervalForResource = 30;

    self.session = [NSURLSession
        sessionWithConfiguration:config
                       delegate:self
                  delegateQueue:nil];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Il nome reale arriva successivamente da /api/config.
    self.title = @"Home Assistant";

    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 132;
    self.tableView.tableFooterView = [[UIView alloc] init];

    self.selectedRoom = @"__all__";

    UIScrollView *rooms = [[UIScrollView alloc]
        initWithFrame:CGRectMake(
            0, 0, self.view.bounds.size.width, 54)];

    rooms.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;
    rooms.backgroundColor = [UIColor blackColor];
    rooms.showsHorizontalScrollIndicator = NO;
    rooms.alwaysBounceHorizontal = YES;

    self.roomsScroll = rooms;
    self.tableView.tableHeaderView = rooms;

    UIScreenEdgePanGestureRecognizer *edge =
        [[UIScreenEdgePanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(drawerEdgePan:)];

    edge.edges = UIRectEdgeLeft;
    [self.tableView addGestureRecognizer:edge];


    // Una sola azione visibile: il menu principale.
    self.navigationItem.rightBarButtonItems = nil;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"☰"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(openMenu)];


    // Refresh disponibile dal menu laterale.
    // Nessun UIRefreshControl sulla dashboard.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    self.favorites = [NSMutableSet setWithArray:
        [d arrayForKey:@"NineHA.Favorites"] ?: @[]];

    self.hiddenEntities = [NSMutableSet setWithArray:
        [d arrayForKey:@"NineHA.HiddenEntities"] ?: @[]];

    [self rebuildSections];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self refreshAll];
    [self configureNativeRefreshTimer];
    [self connectNativeLive];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.timer invalidate];
    self.timer = nil;
    [self stopNativeLive];

    [self.areasLoader cancel];
    self.areasLoader = nil;
    self.areaFetchGeneration++;
    self.requestedAreas = NO;

    [self.drawerShade removeFromSuperview];
    self.drawerShade = nil;
    self.drawerPanel = nil;
    self.drawerClosing = NO;

    [self.session invalidateAndCancel];
    self.session = nil;
    self.loading = NO;

    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    self.navigationController.navigationBar.barTintColor = nil;
    self.navigationController.navigationBar.tintColor = nil;
}


- (void)openServers {
    NineServersController *controller =
        [[NineServersController alloc]
            initWithStyle:UITableViewStyleGrouped];

    [self.navigationController
        pushViewController:controller animated:YES];
}


- (void)drawerPerformAction:(NSInteger)action {
    if (!self.drawerShade || self.drawerClosing) return;

    self.drawerClosing = YES;

    UIControl *shade = self.drawerShade;
    UIView *panel = self.drawerPanel;

    [UIView animateWithDuration:0.22
                     animations:^{
        CGRect frame = panel.frame;
        frame.origin.x = -frame.size.width;
        panel.frame = frame;
        shade.backgroundColor =
            [UIColor colorWithWhite:0 alpha:0];
    } completion:^(BOOL finished) {

        [shade removeFromSuperview];
        self.drawerShade = nil;
        self.drawerPanel = nil;
        self.drawerClosing = NO;

        switch (action) {
            case 2:
                [self openList];
                break;
            case 3:
                [self manualRefresh];
                break;
            case 4:
                [self openServers];
                break;
            case 5:
                [self.navigationController
                    popToRootViewControllerAnimated:YES];
                break;

            case 6: {
                NineLegacyWebController *web =
                    [[NineLegacyWebController alloc]
                        initWithAuth:self.auth mode:self.mode];

                [self.navigationController
                    pushViewController:web animated:YES];
                break;
            }

            case 7: {
                NineLovelaceController *rebuilder =
                    [[NineLovelaceController alloc]
                        initWithAuth:self.auth mode:self.mode];

                [self.navigationController
                    pushViewController:rebuilder animated:YES];
                break;
            }

            case 8: {
                NineUnstableSettingsController *settings =
                    [[NineUnstableSettingsController alloc]
                        initWithServerURL:self.auth.serverURL];

                [self.navigationController
                    pushViewController:settings animated:YES];
                break;
            }

            default:
                break;
        }
    }];
}

- (void)drawerBackgroundTapped {
    [self drawerPerformAction:0];
}

- (void)drawerItemTapped:(UIButton *)sender {
    [self drawerPerformAction:sender.tag];
}

- (void)drawerSwipeLeft:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        [self drawerPerformAction:0];
    }
}

- (void)drawerEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self openMenu];
    }
}

- (void)openMenu {
    if (self.drawerShade || self.drawerClosing) return;

    UIView *host = self.navigationController.view;
    if (!host) return;

    CGFloat width = host.bounds.size.width;
    CGFloat height = host.bounds.size.height;
    CGFloat panelWidth = MIN((CGFloat)320, width * .82f);

    UIControl *shade = [[UIControl alloc]
        initWithFrame:host.bounds];

    shade.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    shade.backgroundColor =
        [UIColor colorWithWhite:0 alpha:0];

    [shade addTarget:self
              action:@selector(drawerBackgroundTapped)
    forControlEvents:UIControlEventTouchUpInside];

    UIView *panel = [[UIView alloc]
        initWithFrame:CGRectMake(-panelWidth, 0,
                                 panelWidth, height)];

    panel.autoresizingMask =
        UIViewAutoresizingFlexibleHeight;

    panel.backgroundColor =
        [UIColor colorWithRed:.09 green:.105 blue:.13 alpha:1];

    [shade addSubview:panel];

    // Intestazione simile alla navigazione Home Assistant.
    UIView *header = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, panelWidth, 132)];

    header.backgroundColor =
        [UIColor colorWithRed:.08 green:.31 blue:.46 alpha:1];
    [panel addSubview:header];

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 14, panelWidth-40, 34)];

    name.text = self.title;
    name.font = [UIFont boldSystemFontOfSize:22];
    name.textColor = [UIColor whiteColor];
    [header addSubview:name];

    UILabel *server = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 54, panelWidth-40, 40)];

    server.text = self.auth.serverURL ?: @"Server non configurato";
    server.numberOfLines = 2;
    server.lineBreakMode = NSLineBreakByTruncatingMiddle;
    server.font = [UIFont systemFontOfSize:12];
    server.textColor =
        [UIColor colorWithWhite:.86 alpha:1];
    [header addSubview:server];

    UILabel *count = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 103, panelWidth-40, 18)];

    count.text = [NSString stringWithFormat:
        @"%lu entità · %@",
        (unsigned long)self.states.count,
        self.areasStatus ?: @"stanze in caricamento"];

    count.font = [UIFont systemFontOfSize:12];
    count.textColor =
        [UIColor colorWithWhite:.8 alpha:1];
    [header addSubview:count];

    UIScrollView *scroll = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 132,
                                 panelWidth, height-132)];

    scroll.autoresizingMask =
        UIViewAutoresizingFlexibleHeight;
    scroll.backgroundColor = [UIColor clearColor];
    [panel addSubview:scroll];

    NSString *refreshSummary =
        [NineUnstableSettingsController
            summaryForServerURL:self.auth.serverURL];

    NSArray *titles = @[
        @"Dashboard",
        @"Elenco entità",
        @"Aggiorna dashboard",
        @"Server e predefinito",
        @"Configurazione e accesso",
        @"Lovelace originale (unstable)",
        @"Lovelace Rebuilder (low power)",
        @"Aggiornamenti"
    ];

    NSArray *symbols = @[
        @"menu.home",
        @"menu.list",
        @"menu.refresh",
        @"menu.server",
        @"menu.settings",
        @"menu.home",
        @"menu.list",
        @"menu.refresh"
    ];

    UILabel *heading = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 297, panelWidth-40, 24)];

    heading.text = @"UNSTABLE LAB";
    heading.font = [UIFont boldSystemFontOfSize:11];
    heading.textColor =
        [UIColor colorWithWhite:.60 alpha:1];

    [scroll addSubview:heading];

    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        CGFloat y = i < 5 ? 10 + i * 58
                            : 327 + (i-5) * 58;

        UIButton *row = [UIButton
            buttonWithType:UIButtonTypeCustom];

        row.frame = CGRectMake(8, y, panelWidth-16, 52);
        row.tag = i + 1;
        row.layer.cornerRadius = 10;
        row.backgroundColor = i == 0
            ? [UIColor colorWithRed:.16 green:.25 blue:.32 alpha:1]
            : [UIColor clearColor];

        NineGlyphView *glyph = [[NineGlyphView alloc]
            initWithFrame:CGRectMake(13, 12, 28, 28)];

        glyph.entityID = symbols[i];
        glyph.tintColor =
            [UIColor colorWithRed:.49 green:.79 blue:.96 alpha:1];

        [row addSubview:glyph];

        UILabel *label = [[UILabel alloc]
            initWithFrame:CGRectMake(55, 4,
                                     panelWidth-84, 44)];

        if (i == 7) {
            label.numberOfLines = 2;
            label.text = [NSString stringWithFormat:
                @"Aggiornamenti%@\n%@",
                [self nativeWantsLive]
                    ? (self.nativeConnected
                        ? @" · WS attivo"
                        : @" · REST fallback")
                    : @"",
                refreshSummary];
        } else {
            label.text = titles[i];
        }
        label.textColor = [UIColor whiteColor];
        label.font =
            [UIFont systemFontOfSize:(i == 7 ? 12 : 15)];
        [row addSubview:label];

        [row addTarget:self
                action:@selector(drawerItemTapped:)
      forControlEvents:UIControlEventTouchUpInside];

        [scroll addSubview:row];
    }

    UILabel *footer = [[UILabel alloc]
        initWithFrame:CGRectMake(20, 528, panelWidth-40, 50)];

    footer.numberOfLines = 2;
    NSString *version = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    NSString *headline = [NSString stringWithFormat:
        @"NineHA %@", version ?: @""];

    NSString *subtitle = @"iOS 9 - Nativo ARMv7";

    NSString *fullText = [NSString stringWithFormat:
        @"%@\n%@", headline, subtitle];

    NSMutableAttributedString *styled =
        [[NSMutableAttributedString alloc]
            initWithString:fullText];

    [styled addAttribute:NSFontAttributeName
                   value:[UIFont boldSystemFontOfSize:19]
                   range:NSMakeRange(0, headline.length)];

    [styled addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:13]
                   range:NSMakeRange(headline.length + 1,
                                     subtitle.length)];

    footer.attributedText = styled;
    footer.textColor =
        [UIColor colorWithWhite:.55 alpha:1];
    [scroll addSubview:footer];

    scroll.contentSize = CGSizeMake(panelWidth, 610);

    UISwipeGestureRecognizer *swipe =
        [[UISwipeGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(drawerSwipeLeft:)];

    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [panel addGestureRecognizer:swipe];

    self.drawerShade = shade;
    self.drawerPanel = panel;

    [host addSubview:shade];

    [UIView animateWithDuration:0.24
                     animations:^{
        CGRect frame = panel.frame;
        frame.origin.x = 0;
        panel.frame = frame;

        shade.backgroundColor =
            [UIColor colorWithWhite:0 alpha:.58];
    }];
}

- (void)openList {
    NineDashboard *list = [[NineDashboard alloc]
        initWithAuth:self.auth mode:self.mode];
    [self.navigationController
        pushViewController:list animated:YES];
}

- (void)withToken:(NineAuthCompletion)completion {
    if ([self.mode isEqualToString:@"oauth"]) {
        [self.auth useOAuthToken:completion];
    } else {
        [self.auth useManualToken:completion];
    }
}


#pragma mark - Native dashboard live refresh

- (BOOL)nativeWantsLive {
    return [NineUnstableSettingsController
        intervalForGroup:1
               serverURL:self.auth.serverURL] == 0;
}

- (void)configureNativeRefreshTimer {
    [self.timer invalidate];
    self.timer = nil;

    NSInteger seconds =
        [NineUnstableSettingsController
            intervalForGroup:1
                   serverURL:self.auth.serverURL];

    if (seconds == 0) {
        if (self.nativeConnected) return;
        seconds = 45;
    }

    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
                               target:self
                             selector:@selector(fetchStates)
                             userInfo:nil
                              repeats:YES];

    NSLog(@"NineHA Native: REST interval %ld s",
          (long)seconds);
}

- (void)stopNativeLive {
    self.nativeEpoch++;

    [self.nativeRetryTimer invalidate];
    self.nativeRetryTimer = nil;

    [self.nativeDrawTimer invalidate];
    self.nativeDrawTimer = nil;

    [self.nativeLive stop];
    self.nativeLive = nil;

    self.nativeChanges = nil;
    self.nativeConnecting = NO;
    self.nativeConnected = NO;
    self.nativeRetryCount = 0;
}

- (void)scheduleNativeLiveRetry {
    if (!self.view.window ||
        ![self nativeWantsLive] ||
        self.nativeRetryTimer)
        return;

    self.nativeRetryCount =
        MIN(self.nativeRetryCount + 1, 5);

    NSTimeInterval delay =
        MIN(60.0,
            5.0 * (1 << (self.nativeRetryCount - 1)));

    NSLog(@"NineHA Native: retry WS in %.0f s",
          delay);

    self.nativeRetryTimer = [NSTimer
        scheduledTimerWithTimeInterval:delay
                               target:self
                             selector:@selector(nativeRetryConnection)
                             userInfo:nil
                              repeats:NO];
}

- (void)nativeRetryConnection {
    self.nativeRetryTimer = nil;
    [self connectNativeLive];
}

- (void)connectNativeLive {
    if (![self nativeWantsLive] ||
        !self.view.window ||
        self.nativeLive ||
        self.nativeConnecting)
        return;

    self.nativeConnecting = YES;

    NSUInteger epoch = ++self.nativeEpoch;

    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token,
                      NSError *error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            NineTilesController *owner = weakSelf;

            if (!owner ||
                owner.nativeEpoch != epoch ||
                !owner.view.window ||
                ![owner nativeWantsLive])
                return;

            if (error || !token.length) {
                owner.nativeConnecting = NO;
                [owner scheduleNativeLiveRetry];
                return;
            }

            owner.nativeLive =
                [[NineLovelaceLive alloc]
                    initWithServerURL:owner.auth.serverURL
                                token:token
                              onState:^(NSString *entityID,
                                        NSDictionary *newState) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    NineTilesController *current = weakSelf;

                    if (current &&
                        current.nativeEpoch == epoch &&
                        current.nativeConnected &&
                        current.view.window) {

                        [current
                            receiveNativeLiveEntity:entityID
                                              state:newState];
                    }
                });

            } onStatus:^(BOOL ready) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    NineTilesController *current = weakSelf;

                    if (current &&
                        current.nativeEpoch == epoch) {

                        [current
                            nativeLiveStatusChanged:ready];
                    }
                });
            }];

            [owner.nativeLive start];
        });
    }];
}

- (void)nativeLiveStatusChanged:(BOOL)ready {
    self.nativeConnecting = NO;
    self.nativeConnected = ready;

    if (ready) {
        self.nativeRetryCount = 0;

        NSLog(@"NineHA Native: WS state_changed ATTIVO");

        // Recuperiamo eventuali eventi persi.
        [self fetchStates];

    } else {
        [self.nativeLive stop];
        self.nativeLive = nil;

        NSLog(@"NineHA Native: fallback REST");

        [self scheduleNativeLiveRetry];
    }

    [self configureNativeRefreshTimer];
}

- (BOOL)nativeEntityIsDisplayed:(NSString *)entityID {
    for (NSDictionary *section in self.sections) {
        for (NSDictionary *row in section[@"items"]) {
            if ([row[@"entity_id"] isEqual:entityID])
                return YES;
        }
    }

    return NO;
}

- (void)receiveNativeLiveEntity:(NSString *)entityID
                          state:(NSDictionary *)newState {

    if (!entityID.length ||
        ![self nativeEntityIsDisplayed:entityID])
        return;

    if (!self.nativeChanges) {
        self.nativeChanges =
            [NSMutableDictionary dictionary];
    }

    self.nativeChanges[entityID] =
        newState ?: (id)[NSNull null];

    // Accorpiamo aggiornamenti ravvicinati.
    if (!self.nativeDrawTimer) {
        self.nativeDrawTimer = [NSTimer
            scheduledTimerWithTimeInterval:0.25
                                   target:self
                                 selector:@selector(flushNativeLiveChanges)
                                 userInfo:nil
                                  repeats:NO];
    }
}

- (void)flushNativeLiveChanges {
    self.nativeDrawTimer = nil;

    if (!self.view.window ||
        !self.nativeChanges.count)
        return;

    NSDictionary *changes =
        [self.nativeChanges copy];

    [self.nativeChanges removeAllObjects];

    NSMutableArray *updated =
        [NSMutableArray arrayWithCapacity:self.states.count];

    NSMutableDictionary *index =
        [self.stateByID mutableCopy];

    if (!index) {
        index = [NSMutableDictionary dictionary];
    }

    for (NSDictionary *entry in self.states) {
        NSString *entity = entry[@"entity_id"];

        id replacement =
            entity ? changes[entity] : nil;

        if (replacement == [NSNull null]) {
            if (entity) {
                [index removeObjectForKey:entity];
            }
            continue;
        }

        NSDictionary *value =
            [replacement isKindOfClass:[NSDictionary class]]
                ? replacement
                : entry;

        [updated addObject:value];

        if (entity) {
            index[entity] = value;
        }
    }

    self.states = updated;
    self.stateByID = index;

    [self rebuildSections];
}

- (void)manualRefresh {
    self.requestedAreas = NO;
    [self refreshAll];
}

- (void)refreshAll {
    [self createSession];
    [self fetchInstanceName];
    [self fetchStates];

    if (!self.requestedAreas) {
        self.requestedAreas = YES;
        [self fetchAreas];
    }
}


- (void)fetchInstanceName {
    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) return;

        NSString *address = [self.auth.serverURL
            stringByAppendingString:@"/api/config"];

        NSURL *url = [NSURL URLWithString:address];

        NSMutableURLRequest *request =
            [NSMutableURLRequest requestWithURL:url];

        request.timeoutInterval = 20;

        [request setValue:
            [@"Bearer " stringByAppendingString:token]
            forHTTPHeaderField:@"Authorization"];

        [request setValue:@"application/json"
            forHTTPHeaderField:@"Accept"];

        [self createSession];

        NSURLSessionDataTask *task =
            [self.session dataTaskWithRequest:request
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *networkError) {

            if (networkError || !data.length) return;

            NSInteger status =
                [(NSHTTPURLResponse *)response statusCode];

            if (status != 200) return;

            id json = [NSJSONSerialization
                JSONObjectWithData:data
                           options:0
                             error:nil];

            if (![json isKindOfClass:[NSDictionary class]])
                return;

            NSString *name = json[@"location_name"];

            if (![name isKindOfClass:[NSString class]])
                return;

            name = [name stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (!name.length) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.title = name;
            });
        }];

        [task resume];
    }];
}



- (void)fetchAreas {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fetchAreas];
        });
        return;
    }

    NSUInteger generation = ++self.areaFetchGeneration;

    [self.areasLoader cancel];
    self.areasLoader = nil;

    self.areasStatus = @"stanze in caricamento";

    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *authError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) owner = weakSelf;

            if (!owner ||
                generation != owner.areaFetchGeneration) return;

            if (authError || !token.length) {
                owner.requestedAreas = NO;
                owner.areasStatus = @"token non disponibile";
                return;
            }

            NineAreasLoader *loader =
                [[NineAreasLoader alloc]
                    initWithServerURL:owner.auth.serverURL
                               token:token
                          completion:^(NSDictionary *map,
                                       NSArray *names,
                                       NSError *error) {

                __strong typeof(weakSelf) controller = weakSelf;

                if (!controller ||
                    generation != controller.areaFetchGeneration)
                    return;

                controller.areasLoader = nil;

                if (error) {
                    controller.requestedAreas = NO;

                    controller.areasStatus =
                        [NSString stringWithFormat:@"WS: %@",
                            error.localizedDescription];

                    NSLog(@"NineHA area registry: %@",
                          error.localizedDescription);
                    return;
                }

                controller.areaByID = map ?: @{};
                controller.configuredAreaNames = names ?: @[];

                controller.areasStatus = [NSString stringWithFormat:
                    @"%lu stanze",
                    (unsigned long)names.count];

                [controller rebuildSections];
            }];

            owner.areasLoader = loader;
            [loader start];
        });
    }];
}

- (void)fetchStates {
    if (!self.requestedAreas) {
        self.requestedAreas = YES;
        [self fetchAreas];
    }

    if (self.loading) return;
    self.loading = YES;
    [self createSession];

    // Il contatore rimane esclusivamente nel menu laterale.
    self.navigationItem.prompt = nil;

    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) {
            [self finishLoad:nil message:
                error.localizedDescription ?: @"Token mancante"];
            return;
        }

        NSURL *url = [NSURL URLWithString:
            [self.auth.serverURL stringByAppendingString:@"/api/states"]];

        NSMutableURLRequest *req =
            [NSMutableURLRequest requestWithURL:url];

        [req setValue:[@"Bearer " stringByAppendingString:token]
  forHTTPHeaderField:@"Authorization"];
        [req setValue:@"application/json"
  forHTTPHeaderField:@"Accept"];

        NSURLSessionDataTask *task =
            [self.session dataTaskWithRequest:req
                            completionHandler:^(NSData *data,
                                                NSURLResponse *response,
                                                NSError *networkError) {
            if (networkError) {
                [self finishLoad:nil
                         message:networkError.localizedDescription];
                return;
            }

            NSInteger code =
                [(NSHTTPURLResponse *)response statusCode];

            if (code != 200) {
                [self finishLoad:nil message:
                    [NSString stringWithFormat:@"HTTP %ld", (long)code]];
                return;
            }

            id json = data.length
                ? [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:nil]
                : nil;

            if (![json isKindOfClass:[NSArray class]]) {
                [self finishLoad:nil message:@"Dati non validi"];
                return;
            }

            [self finishLoad:(NSArray *)json message:nil];
        }];

        [task resume];
    }];
}

- (void)finishLoad:(NSArray *)states
           message:(NSString *)errorMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loading = NO;
        // Nessun indicatore di pull-to-refresh.

        if (states) {
            self.states = states;

            NSMutableDictionary *index =
                [NSMutableDictionary dictionary];
            for (id obj in states) {
                if (![obj isKindOfClass:[NSDictionary class]]) continue;
                NSString *entityID = obj[@"entity_id"];
                if ([entityID isKindOfClass:[NSString class]]) {
                    index[entityID] = obj;
                }
            }
            self.stateByID = index;
            [self rebuildSections];

            self.navigationItem.prompt = nil;
        } else {
            self.navigationItem.prompt =
                errorMessage ?: @"Connessione non riuscita";
        }
    });
}

- (BOOL)isCommand:(NSString *)entityID {
    return [entityID hasPrefix:@"light."] ||
           [entityID hasPrefix:@"switch."] ||
           [entityID hasPrefix:@"input_boolean."];
}

- (NSString *)displayName:(NSDictionary *)entity {
    NSDictionary *attributes = entity[@"attributes"];
    id name = [attributes isKindOfClass:[NSDictionary class]]
        ? attributes[@"friendly_name"] : nil;

    if ([name isKindOfClass:[NSString class]] &&
        [name length]) {
        return name;
    }
    return entity[@"entity_id"] ?: @"Entità";
}


- (void)roomChosen:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!key.length) return;

    self.selectedRoom = key;
    [self rebuildSections];

    [self.tableView setContentOffset:CGPointMake(0, -self.tableView.contentInset.top) animated:NO];
}

- (void)updateRoomSelectorWithNames:(NSArray *)names {
    if (!self.roomsScroll) return;

    for (UIView *view in [self.roomsScroll.subviews copy]) {
        [view removeFromSuperview];
    }

    NSMutableArray *rooms = [NSMutableArray
        arrayWithObject:@"__all__"];
    [rooms addObjectsFromArray:names];

    CGFloat x = 10;

    for (NSString *key in rooms) {
        NSString *title = [key isEqualToString:@"__all__"]
            ? @"Tutte" : key;

        UIFont *font = [UIFont boldSystemFontOfSize:13];

        CGFloat textWidth =
            [title sizeWithAttributes:@{
                NSFontAttributeName: font
            }].width;

        CGFloat width = MIN(
            (CGFloat)210,
            MAX((CGFloat)82, textWidth + 28));

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeCustom];

        button.frame = CGRectMake(x, 8, width, 36);
        button.accessibilityIdentifier = key;
        button.layer.cornerRadius = 18;
        button.clipsToBounds = YES;

        BOOL active =
            [key isEqualToString:self.selectedRoom];

        button.backgroundColor = active
            ? [UIColor colorWithRed:.11
                               green:.43
                                blue:.65
                               alpha:1]
            : [UIColor colorWithWhite:.17 alpha:1];

        button.titleLabel.font = font;

        [button setTitle:title
               forState:UIControlStateNormal];

        [button setTitleColor:[UIColor whiteColor]
                    forState:UIControlStateNormal];

        [button addTarget:self
                   action:@selector(roomChosen:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.roomsScroll addSubview:button];

        x += width + 8;
    }

    self.roomsScroll.contentSize =
        CGSizeMake(x + 10, 54);
}

- (void)rebuildSections {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    BOOL onlyFavorites = self.favorites.count > 0;

    for (id obj in self.states) {
        if (![obj isKindOfClass:[NSDictionary class]]) continue;

        NSDictionary *entity = obj;
        NSString *entityID = entity[@"entity_id"];
        if (![entityID isKindOfClass:[NSString class]]) continue;

        if ([self.hiddenEntities containsObject:entityID]) continue;

        if (onlyFavorites) {
            if (![self.favorites containsObject:entityID]) continue;
        } else if (![self isCommand:entityID] &&
                   ![entityID hasPrefix:@"cover."] &&
                   ![entityID hasPrefix:@"climate."]) {
            continue;
        }

        NSString *area = self.areaByID[entityID];
        if (!area.length) area = @"Senza stanza";

        NSMutableArray *items = groups[area];
        if (!items) {
            items = [NSMutableArray array];
            groups[area] = items;
        }
        [items addObject:entity];
    }

    NSMutableSet *allRooms =
        [NSMutableSet setWithArray:
            self.configuredAreaNames ?: @[]];

    // Conserviamo anche la categoria locale Senza stanza.
    [allRooms addObjectsFromArray:[groups allKeys]];

    NSArray *availableRooms = [[allRooms allObjects]
        sortedArrayUsingSelector:
            @selector(localizedCaseInsensitiveCompare:)];

    // Se una stanza non contiene più tessere visibili,
    // torniamo automaticamente alla vista Tutte.
    if (![self.selectedRoom isEqualToString:@"__all__"] &&
        ![availableRooms containsObject:self.selectedRoom]) {
        self.selectedRoom = @"__all__";
    }

    [self updateRoomSelectorWithNames:availableRooms];

    NSArray *names =
        [self.selectedRoom isEqualToString:@"__all__"]
        ? availableRooms
        : @[self.selectedRoom];

    NSMutableArray *sections = [NSMutableArray array];

    for (NSString *name in names) {
        NSArray *itemsForArea = groups[name];

        if (!itemsForArea.count) {
            continue;
        }

        NSArray *sorted = [itemsForArea
            sortedArrayUsingComparator:
            ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [[self displayName:a]
                    localizedCaseInsensitiveCompare:[self displayName:b]];
            }];

        [sections addObject:@{@"name": name, @"items": sorted}];
    }

    self.sections = sections;

    if (sections.count == 0) {
        UILabel *empty = [[UILabel alloc]
            initWithFrame:CGRectMake(20, 0,
                self.tableView.bounds.size.width - 40, 180)];
        empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        empty.textColor = [UIColor lightGrayColor];
        empty.text = @"Nessuna tessera.\n"
                     "Apri Elenco e aggiungi i tuoi preferiti.";
        self.tableView.backgroundView = empty;
    } else {
        self.tableView.backgroundView = nil;
    }

    [self.tableView reloadData];
}

- (NSInteger)columns {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 3 : 2;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    NSArray *items = self.sections[section][@"items"];
    NSInteger cols = [self columns];
    return (items.count + cols - 1) / cols;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    NSDictionary *group = self.sections[section];
    return [NSString stringWithFormat:@"%@ (%lu)",
        group[@"name"], (unsigned long)[group[@"items"] count]];
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    return 34;
}

- (NSString *)symbolForID:(NSString *)entityID {
    if ([entityID hasPrefix:@"light."]) return @"💡";
    if ([entityID hasPrefix:@"switch."]) return @"🔌";
    if ([entityID hasPrefix:@"input_boolean."]) return @"◉";
    if ([entityID hasPrefix:@"sensor."]) return @"🌡";
    if ([entityID hasPrefix:@"binary_sensor."]) return @"●";
    if ([entityID hasPrefix:@"climate."]) return @"❄";
    if ([entityID hasPrefix:@"cover."]) return @"▤";
    return @"⌂";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *reuseID = @"NineTilesRow";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:reuseID];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleDefault
          reuseIdentifier:reuseID];
    }

    for (UIView *view in [cell.contentView.subviews copy]) {
        [view removeFromSuperview];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor blackColor];

    NSArray *items = self.sections[indexPath.section][@"items"];
    NSInteger columns = [self columns];

    CGFloat gap = 8;
    CGFloat width = tableView.bounds.size.width;
    CGFloat tileWidth = (width - gap * (columns + 1)) / columns;

    for (NSInteger col = 0; col < columns; col++) {
        NSInteger index = indexPath.row * columns + col;
        if (index >= (NSInteger)items.count) break;

        NSDictionary *entity = items[index];
        NSString *entityID = entity[@"entity_id"];
        NSString *state = [entity[@"state"] description];

        BOOL on = [state isEqualToString:@"on"];

        UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
        tile.frame = CGRectMake(
            gap + col * (tileWidth + gap), 4, tileWidth, 124);
        tile.accessibilityIdentifier = entityID;

        BOOL light = [entityID hasPrefix:@"light."];
        BOOL cover = [entityID hasPrefix:@"cover."];
        BOOL climate = [entityID hasPrefix:@"climate."];

        BOOL active = on ||
            (cover && ([state isEqualToString:@"open"] ||
                       [state isEqualToString:@"opening"])) ||
            (climate && ![state isEqualToString:@"off"] &&
             ![state isEqualToString:@"unavailable"] &&
             ![state isEqualToString:@"unknown"]);

        tile.backgroundColor = active
            ? (light
                ? [UIColor colorWithRed:.29 green:.23 blue:.13 alpha:1]
                : [UIColor colorWithRed:.10 green:.25 blue:.33 alpha:1])
            : [UIColor colorWithRed:.13 green:.14 blue:.17 alpha:1];

        tile.layer.borderWidth = 1;
        tile.layer.borderColor =
            [UIColor colorWithWhite:.23 alpha:1].CGColor;

        tile.layer.cornerRadius = 16;
        tile.clipsToBounds = YES;

        UIView *iconCircle = [[UIView alloc]
            initWithFrame:CGRectMake(10, 9, 42, 42)];

        iconCircle.layer.cornerRadius = 21;
        iconCircle.backgroundColor = active
            ? [UIColor colorWithRed:.18 green:.43 blue:.57 alpha:1]
            : [UIColor colorWithWhite:.22 alpha:1];

        if (light && active) {
            iconCircle.backgroundColor =
                [UIColor colorWithRed:.60 green:.43 blue:.15 alpha:1];
        }

        NineGlyphView *icon = [[NineGlyphView alloc]
            initWithFrame:iconCircle.bounds];

        icon.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        icon.entityID = entityID;
        icon.tintColor = light && active
            ? [UIColor colorWithRed:1 green:.83 blue:.43 alpha:1]
            : [UIColor colorWithRed:.77 green:.88 blue:.96 alpha:1];

        [iconCircle addSubview:icon];
        [tile addSubview:iconCircle];

        UILabel *indicator = [[UILabel alloc]
            initWithFrame:CGRectMake(tileWidth-25, 14, 13, 15)];
        indicator.text = @"●";
        indicator.font = [UIFont systemFontOfSize:11];
        indicator.textColor = active
            ? [UIColor colorWithRed:.39 green:.85 blue:.69 alpha:1]
            : [UIColor colorWithWhite:.38 alpha:1];
        [tile addSubview:indicator];

        UILabel *name = [[UILabel alloc]
            initWithFrame:CGRectMake(10, 55, tileWidth - 20, 34)];
        name.text = [self displayName:entity];
        name.font = [UIFont boldSystemFontOfSize:13];
        name.textColor = [UIColor whiteColor];
        name.numberOfLines = 2;
        [tile addSubview:name];

        NSDictionary *attrs = entity[@"attributes"];
        NSString *unit = [attrs isKindOfClass:[NSDictionary class]]
            ? attrs[@"unit_of_measurement"] : nil;

        if (![unit isKindOfClass:[NSString class]]) unit = @"";

        UILabel *value = [[UILabel alloc]
            initWithFrame:CGRectMake(10, 100, tileWidth - 20, 18)];
        NSString *displayState = state ?: @"N/D";
        if ([state isEqualToString:@"on"]) {
            displayState = [entityID hasPrefix:@"light."]
                ? @"Accesa" : @"Attivo";
        } else if ([state isEqualToString:@"off"]) {
            displayState = [entityID hasPrefix:@"light."]
                ? @"Spenta" : @"Disattivo";
        }

        if ([entityID hasPrefix:@"cover."]) {
            NSNumber *position = [attrs isKindOfClass:[NSDictionary class]]
                ? attrs[@"current_position"] : nil;

            if (![position isKindOfClass:[NSNumber class]]) {
                position = [attrs isKindOfClass:[NSDictionary class]]
                    ? attrs[@"current_cover_position"] : nil;
            }

            if ([position isKindOfClass:[NSNumber class]]) {
                displayState = [NSString stringWithFormat:
                    @"Posizione: %ld%%", (long)position.integerValue];
            }
        }

        if ([entityID hasPrefix:@"climate."] &&
            [attrs isKindOfClass:[NSDictionary class]]) {
            NSNumber *current = attrs[@"current_temperature"];
            NSNumber *target = attrs[@"temperature"];

            if ([current isKindOfClass:[NSNumber class]] &&
                [target isKindOfClass:[NSNumber class]]) {
                displayState = [NSString stringWithFormat:
                    @"%.1f° → %.1f°",
                    current.doubleValue, target.doubleValue];
            } else if ([current isKindOfClass:[NSNumber class]]) {
                displayState = [NSString stringWithFormat:
                    @"%.1f°", current.doubleValue];
            }
        }

        value.text = unit.length
            ? [NSString stringWithFormat:@"%@ %@", displayState, unit]
            : displayState;

        tile.accessibilityLabel = [NSString stringWithFormat:
            @"%@, %@", [self displayName:entity], displayState];
        tile.accessibilityHint = [self isCommand:entityID]
            ? @"Tocca per cambiare stato, tieni premuto per opzioni"
            : @"Tocca per dettagli, tieni premuto per opzioni";
        value.font = [UIFont systemFontOfSize:11];
        value.textColor = [UIColor lightGrayColor];
        [tile addSubview:value];

        UILongPressGestureRecognizer *press =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(tileLongPressed:)];
        press.minimumPressDuration = 0.55;
        press.cancelsTouchesInView = YES;
        [tile addGestureRecognizer:press];

        [tile addTarget:self
                 action:@selector(tileTapped:)
       forControlEvents:UIControlEventTouchUpInside];

        [cell.contentView addSubview:tile];
    }

    return cell;
}

- (BOOL)supportsBrightness:(NSDictionary *)entity {
    if (![entity[@"entity_id"] hasPrefix:@"light."]) return NO;

    NSDictionary *attrs = entity[@"attributes"];
    if (![attrs isKindOfClass:[NSDictionary class]]) return NO;

    if ([attrs[@"brightness"] isKindOfClass:[NSNumber class]]) {
        return YES;
    }

    NSArray *modes = attrs[@"supported_color_modes"];
    if (![modes isKindOfClass:[NSArray class]]) return NO;

    NSSet *supported = [NSSet setWithArray:@[
        @"brightness", @"color_temp", @"hs",
        @"xy", @"rgb", @"rgbw", @"rgbww"
    ]];

    for (NSString *mode in modes) {
        if ([supported containsObject:mode]) return YES;
    }

    return NO;
}

- (void)saveFavorites {
    [[NSUserDefaults standardUserDefaults]
        setObject:[self.favorites allObjects]
          forKey:@"NineHA.Favorites"];
}


- (void)showStateForEntity:(NSDictionary *)entity {
    NSString *entityID = entity[@"entity_id"];
    NSString *state = [entity[@"state"] description] ?: @"N/D";
    NSDictionary *attrs = entity[@"attributes"];

    NSString *unit = @"";
    if ([attrs isKindOfClass:[NSDictionary class]]) {
        id value = attrs[@"unit_of_measurement"];
        if ([value isKindOfClass:[NSString class]]) {
            unit = value;
        }
    }

    NSString *reading = unit.length
        ? [NSString stringWithFormat:@"%@ %@", state, unit]
        : state;

    NSString *message = [NSString stringWithFormat:
        @"Stato: %@\n\nEntità: %@\nUltima modifica: %@",
        reading,
        entityID ?: @"N/D",
        entity[@"last_changed"] ?: @"N/D"];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[self displayName:entity]
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction
        actionWithTitle:@"Chiudi"
                  style:UIAlertActionStyleDefault
                handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)brightnessChanged {
    NSInteger percent = (NSInteger)lroundf(
        self.brightnessSlider.value);

    self.brightnessLabel.text = [NSString stringWithFormat:
        @"%ld%%", (long)percent];
}

- (void)brightnessCancel {
    [self.brightnessOverlay removeFromSuperview];
    self.brightnessOverlay = nil;
    self.brightnessSlider = nil;
    self.brightnessLabel = nil;
    self.brightnessEntityID = nil;
}

- (void)brightnessApply {
    NSString *entityID = [self.brightnessEntityID copy];
    NSInteger percent = self.brightnessSlider
        ? (NSInteger)lroundf(self.brightnessSlider.value) : 50;

    percent = MAX(1, MIN(100, percent));
    [self brightnessCancel];

    if (![entityID hasPrefix:@"light."]) return;

    [self sendService:@"turn_on"
               domain:@"light"
             entityID:entityID
                extra:@{@"brightness_pct": @(percent)}];
}

- (void)showBrightnessForEntity:(NSDictionary *)entity {
    if (![self supportsBrightness:entity]) return;

    UIView *host = self.navigationController.view;
    if (!host) return;

    [self brightnessCancel];
    self.brightnessEntityID = [entity[@"entity_id"] copy];

    NSDictionary *attrs = entity[@"attributes"];
    NSNumber *current = [attrs isKindOfClass:[NSDictionary class]]
        ? attrs[@"brightness"] : nil;

    NSInteger percent = [current isKindOfClass:[NSNumber class]]
        ? (NSInteger)lroundf(current.floatValue * 100.0f / 255.0f)
        : 50;

    percent = MAX(1, MIN(100, percent));

    CGFloat width = host.bounds.size.width;
    CGFloat height = host.bounds.size.height;
    CGFloat panelWidth = MIN((CGFloat)400, width - 24.0f);
    CGFloat panelHeight = 236.0f;

    UIView *overlay = [[UIView alloc] initWithFrame:host.bounds];
    overlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor =
        [UIColor colorWithWhite:0 alpha:0.82f];

    UIView *panel = [[UIView alloc]
        initWithFrame:CGRectMake((width-panelWidth)/2.0f,
                                 (height-panelHeight)/2.0f,
                                 panelWidth, panelHeight)];
    panel.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    panel.backgroundColor =
        [UIColor colorWithRed:.13f green:.15f blue:.18f alpha:1];
    panel.layer.cornerRadius = 16;
    panel.clipsToBounds = YES;
    [overlay addSubview:panel];

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(16, 12, panelWidth-32, 46)];
    name.text = [self displayName:entity];
    name.numberOfLines = 2;
    name.textAlignment = NSTextAlignmentCenter;
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont boldSystemFontOfSize:17];
    [panel addSubview:name];

    self.brightnessLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(16, 62, panelWidth-32, 36)];
    self.brightnessLabel.textColor = [UIColor whiteColor];
    self.brightnessLabel.textAlignment = NSTextAlignmentCenter;
    self.brightnessLabel.font = [UIFont systemFontOfSize:29];
    [panel addSubview:self.brightnessLabel];

    self.brightnessSlider = [[UISlider alloc]
        initWithFrame:CGRectMake(22, 106, panelWidth-44, 40)];
    self.brightnessSlider.minimumValue = 1;
    self.brightnessSlider.maximumValue = 100;
    self.brightnessSlider.value = percent;
    self.brightnessSlider.minimumTrackTintColor =
        [UIColor colorWithRed:.18f green:.69f blue:.96f alpha:1];
    [self.brightnessSlider addTarget:self
                              action:@selector(brightnessChanged)
                    forControlEvents:UIControlEventValueChanged];
    [panel addSubview:self.brightnessSlider];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake(14, 168, (panelWidth-42)/2, 46);
    [cancel setTitle:@"Annulla" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor whiteColor]
                forState:UIControlStateNormal];
    cancel.backgroundColor = [UIColor colorWithWhite:.23 alpha:1];
    cancel.layer.cornerRadius = 9;
    [cancel addTarget:self
               action:@selector(brightnessCancel)
     forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:cancel];

    UIButton *apply = [UIButton buttonWithType:UIButtonTypeSystem];
    apply.frame = CGRectMake((panelWidth/2)+7, 168,
                             (panelWidth-42)/2, 46);
    [apply setTitle:@"Applica" forState:UIControlStateNormal];
    [apply setTitleColor:[UIColor whiteColor]
               forState:UIControlStateNormal];
    apply.backgroundColor =
        [UIColor colorWithRed:.10 green:.49 blue:.76 alpha:1];
    apply.layer.cornerRadius = 9;
    [apply addTarget:self
              action:@selector(brightnessApply)
    forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:apply];

    self.brightnessOverlay = overlay;
    [self brightnessChanged];
    [host addSubview:overlay];
}


- (void)temperatureChanged {
    self.temperatureValue.text = [NSString stringWithFormat:
        @"%.1f %@", self.temperatureStepper.value,
        self.temperatureUnit ?: @"°"];
}

- (void)temperatureCancel {
    [self.temperatureOverlay removeFromSuperview];
    self.temperatureOverlay = nil;
    self.temperatureStepper = nil;
    self.temperatureValue = nil;
    self.temperatureEntityID = nil;
    self.temperatureUnit = nil;
}

- (void)temperatureApply {
    NSString *entityID = [self.temperatureEntityID copy];
    double value = self.temperatureStepper.value;

    [self temperatureCancel];

    if (![entityID hasPrefix:@"climate."]) return;

    [self sendService:@"set_temperature"
               domain:@"climate"
             entityID:entityID
                extra:@{@"temperature": @(value)}];
}

- (void)showTemperatureForEntity:(NSDictionary *)entity {
    NSDictionary *attrs = entity[@"attributes"];
    if (![attrs isKindOfClass:[NSDictionary class]]) return;

    NSInteger features = [attrs[@"supported_features"] integerValue];
    NSNumber *target = attrs[@"temperature"];

    if (!(features & 1) ||
        ![target isKindOfClass:[NSNumber class]]) {
        [self showError:@"Temperatura regolabile non disponibile."];
        return;
    }

    double minimum = [attrs[@"min_temp"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"min_temp"] doubleValue] : 7.0;
    double maximum = [attrs[@"max_temp"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"max_temp"] doubleValue] : 35.0;
    double step = [attrs[@"target_temp_step"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"target_temp_step"] doubleValue] : 0.5;

    if (!isfinite(minimum) || !isfinite(maximum) ||
        !isfinite(step) || maximum <= minimum ||
        step <= 0 || step > maximum - minimum) {
        [self showError:@"Limiti temperatura non validi."];
        return;
    }

    UIView *host = self.navigationController.view;
    if (!host) return;

    [self temperatureCancel];

    self.temperatureEntityID = [entity[@"entity_id"] copy];

    NSString *unit = attrs[@"temperature_unit"];
    self.temperatureUnit =
        [unit isKindOfClass:[NSString class]] ? unit : @"°";

    CGFloat width = host.bounds.size.width;
    CGFloat height = host.bounds.size.height;
    CGFloat panelWidth = MIN((CGFloat)390, width - 24);

    UIView *overlay = [[UIView alloc] initWithFrame:host.bounds];
    overlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor =
        [UIColor colorWithWhite:0 alpha:.82];

    UIView *panel = [[UIView alloc]
        initWithFrame:CGRectMake((width-panelWidth)/2,
                                 (height-246)/2,
                                 panelWidth, 246)];
    panel.backgroundColor =
        [UIColor colorWithRed:.13 green:.15 blue:.18 alpha:1];
    panel.layer.cornerRadius = 16;
    panel.clipsToBounds = YES;

    [overlay addSubview:panel];

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(12, 14, panelWidth-24, 46)];
    name.text = [self displayName:entity];
    name.textColor = [UIColor whiteColor];
    name.numberOfLines = 2;
    name.textAlignment = NSTextAlignmentCenter;
    name.font = [UIFont boldSystemFontOfSize:18];
    [panel addSubview:name];

    UILabel *temperature = [[UILabel alloc]
        initWithFrame:CGRectMake(12, 66, panelWidth-24, 44)];
    temperature.textColor = [UIColor whiteColor];
    temperature.font = [UIFont systemFontOfSize:30];
    temperature.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:temperature];

    UIStepper *stepper = [[UIStepper alloc]
        initWithFrame:CGRectZero];
    stepper.minimumValue = minimum;
    stepper.maximumValue = maximum;
    stepper.stepValue = step;
    stepper.value = MAX(minimum, MIN(maximum, target.doubleValue));
    stepper.tintColor =
        [UIColor colorWithRed:.28 green:.72 blue:.93 alpha:1];

    CGSize stepSize = stepper.bounds.size;
    stepper.frame = CGRectMake((panelWidth-stepSize.width)/2,
                              125, stepSize.width, stepSize.height);

    [stepper addTarget:self
                action:@selector(temperatureChanged)
      forControlEvents:UIControlEventValueChanged];

    [panel addSubview:stepper];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake(12, 187, (panelWidth-36)/2, 44);
    [cancel setTitle:@"Annulla" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor whiteColor]
                forState:UIControlStateNormal];
    cancel.backgroundColor = [UIColor darkGrayColor];
    cancel.layer.cornerRadius = 9;
    [cancel addTarget:self
               action:@selector(temperatureCancel)
     forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:cancel];

    UIButton *apply = [UIButton buttonWithType:UIButtonTypeSystem];
    apply.frame = CGRectMake(panelWidth/2+6, 187,
                             (panelWidth-36)/2, 44);
    [apply setTitle:@"Applica" forState:UIControlStateNormal];
    [apply setTitleColor:[UIColor whiteColor]
               forState:UIControlStateNormal];
    apply.backgroundColor =
        [UIColor colorWithRed:.10 green:.48 blue:.75 alpha:1];
    apply.layer.cornerRadius = 9;
    [apply addTarget:self
              action:@selector(temperatureApply)
    forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:apply];

    self.temperatureOverlay = overlay;
    self.temperatureStepper = stepper;
    self.temperatureValue = temperature;

    [self temperatureChanged];
    [host addSubview:overlay];
}

- (void)tileTapped:(UIButton *)button {
    NSString *entityID = button.accessibilityIdentifier;
    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return;

    NSString *domain =
        [[entityID componentsSeparatedByString:@"."] firstObject];
    NSString *state = [entity[@"state"] description];

    BOOL available =
        ![state isEqualToString:@"unknown"] &&
        ![state isEqualToString:@"unavailable"];

    // Tocco semplice: comando immediato soltanto per i domini
    // esplicitamente autorizzati.
    if ([self isCommand:entityID] && available) {
        NSString *service =
            [state isEqualToString:@"on"] ? @"turn_off" : @"turn_on";

        [self sendService:service
                   domain:domain
                 entityID:entityID
                    extra:@{}];
        return;
    }

    // Sensori e tutte le altre entità: sola lettura.
    [self showStateForEntity:entity];
}

- (void)tileLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UIButton *button = (UIButton *)gesture.view;
    NSString *entityID = button.accessibilityIdentifier;
    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return;

    NSString *state = [entity[@"state"] description];
    NSString *domain =
        [[entityID componentsSeparatedByString:@"."] firstObject];

    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:[self displayName:entity]
                         message:[NSString stringWithFormat:
                            @"%@\nStato: %@", entityID, state ?: @"N/D"]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    if ([self isCommand:entityID] &&
        ![state isEqualToString:@"unavailable"] &&
        ![state isEqualToString:@"unknown"]) {

        NSString *service =
            [state isEqualToString:@"on"] ? @"turn_off" : @"turn_on";

        [menu addAction:[UIAlertAction
            actionWithTitle:
                [service isEqualToString:@"turn_off"] ? @"Spegni" : @"Accendi"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
            [self sendService:service
                       domain:domain
                     entityID:entityID
                        extra:@{}];
        }]];
    }

    if ([self supportsBrightness:entity] &&
        ![state isEqualToString:@"unavailable"] &&
        ![state isEqualToString:@"unknown"]) {

        [menu addAction:[UIAlertAction
            actionWithTitle:@"Regola luminosità"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
            // Nessun push di UIViewController durante la
            // chiusura dell'Action Sheet: pannello nello stesso host.
            [self showBrightnessForEntity:entity];
        }]];
    }


    NSDictionary *attrs = entity[@"attributes"];
    if (![attrs isKindOfClass:[NSDictionary class]]) attrs = @{};

    BOOL usable = ![state isEqualToString:@"unknown"] &&
                  ![state isEqualToString:@"unavailable"];

    if ([entityID hasPrefix:@"cover."] && usable) {
        NSString *deviceClass = attrs[@"device_class"];

        // Escludiamo cancelli, garage, porte e finestre:
        // niente comandi per aperture di sicurezza in questa release.
        NSSet *safeClasses = [NSSet setWithArray:@[
            @"blind", @"curtain", @"shade", @"shutter", @"awning"
        ]];

        if ([safeClasses containsObject:deviceClass]) {
            NSInteger features =
                [attrs[@"supported_features"] integerValue];

            NSArray *commands = @[
                @{@"title": @"Apri", @"service": @"open_cover",
                  @"feature": @1},
                @{@"title": @"Chiudi", @"service": @"close_cover",
                  @"feature": @2},
                @{@"title": @"Ferma", @"service": @"stop_cover",
                  @"feature": @8}
            ];

            for (NSDictionary *command in commands) {
                NSInteger flag = [command[@"feature"] integerValue];
                if (!(features & flag)) continue;

                NSString *service = command[@"service"];
                NSString *title = command[@"title"];

                [menu addAction:[UIAlertAction
                    actionWithTitle:title
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                    [self sendService:service
                               domain:@"cover"
                             entityID:entityID
                                extra:@{}];
                }]];
            }
        }
    }

    if ([entityID hasPrefix:@"climate."] && usable) {
        NSInteger features =
            [attrs[@"supported_features"] integerValue];

        if ((features & 1) &&
            [attrs[@"temperature"] isKindOfClass:[NSNumber class]]) {

            [menu addAction:[UIAlertAction
                actionWithTitle:@"Imposta temperatura"
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                [self showTemperatureForEntity:entity];
            }]];
        }
    }

    BOOL favorite = [self.favorites containsObject:entityID];

    [menu addAction:[UIAlertAction
        actionWithTitle:favorite
            ? @"Rimuovi dai preferiti"
            : @"★ Aggiungi ai preferiti"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        if (favorite) {
            [self.favorites removeObject:entityID];
        } else {
            [self.favorites addObject:entityID];
        }

        [self saveFavorites];
        [self rebuildSections];
    }]];

    [menu addAction:[UIAlertAction
        actionWithTitle:@"Nascondi dalla Home"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        [self.hiddenEntities addObject:entityID];
        [self.favorites removeObject:entityID];

        [self saveFavorites];
        [[NSUserDefaults standardUserDefaults]
            setObject:[self.hiddenEntities allObjects]
              forKey:@"NineHA.HiddenEntities"];

        [self rebuildSections];
    }]];

    [menu addAction:[UIAlertAction
        actionWithTitle:@"Annulla"
                  style:UIAlertActionStyleCancel
                handler:nil]];

    UIPopoverPresentationController *popover =
        menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = button;
        popover.sourceRect = button.bounds;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

- (void)showError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"NineHA"
                             message:message
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction
            actionWithTitle:@"OK"
                      style:UIAlertActionStyleDefault
                    handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)sendService:(NSString *)service
             domain:(NSString *)domain
           entityID:(NSString *)entityID
              extra:(NSDictionary *)extra {

    if (![entityID hasPrefix:
          [domain stringByAppendingString:@"."]]) return;

    BOOL basic =
        [@[@"light", @"switch", @"input_boolean"]
            containsObject:domain] &&
        [@[@"turn_on", @"turn_off"]
            containsObject:service];

    BOOL cover =
        [domain isEqualToString:@"cover"] &&
        [@[@"open_cover", @"close_cover", @"stop_cover"]
            containsObject:service];

    BOOL climate =
        [domain isEqualToString:@"climate"] &&
        [service isEqualToString:@"set_temperature"];

    if (!(basic || cover || climate)) return;

    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return;

    NSDictionary *attrs = entity[@"attributes"];
    if (![attrs isKindOfClass:[NSDictionary class]]) attrs = @{};

    if (cover) {
        NSSet *safeClasses = [NSSet setWithArray:@[
            @"blind", @"curtain", @"shade", @"shutter", @"awning"
        ]];
        if (![safeClasses containsObject:attrs[@"device_class"]])
            return;

        NSInteger features = [attrs[@"supported_features"] integerValue];
        NSInteger needed =
            [service isEqualToString:@"open_cover"] ? 1 :
            [service isEqualToString:@"close_cover"] ? 2 : 8;

        if (!(features & needed)) return;
    }

    if (climate) {
        NSInteger features = [attrs[@"supported_features"] integerValue];
        NSNumber *temperature = extra[@"temperature"];
        if (!(features & 1) ||
            ![temperature isKindOfClass:[NSNumber class]] ||
            !isfinite(temperature.doubleValue)) return;

        double minimum = [attrs[@"min_temp"] isKindOfClass:[NSNumber class]]
            ? [attrs[@"min_temp"] doubleValue] : 7.0;
        double maximum = [attrs[@"max_temp"] isKindOfClass:[NSNumber class]]
            ? [attrs[@"max_temp"] doubleValue] : 35.0;

        if (temperature.doubleValue < minimum ||
            temperature.doubleValue > maximum) return;
    }

    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) {
            [self showError:error.localizedDescription
                ?: @"Credenziali non disponibili"];
            return;
        }

        NSString *path = [NSString stringWithFormat:
            @"/api/services/%@/%@", domain, service];

        NSURL *url = [NSURL URLWithString:
            [self.auth.serverURL stringByAppendingString:path]];

        NSMutableURLRequest *req =
            [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";

        NSMutableDictionary *payload =
            [@{@"entity_id": entityID} mutableCopy];
        [payload addEntriesFromDictionary:extra];

        req.HTTPBody = [NSJSONSerialization
            dataWithJSONObject:payload options:0 error:nil];

        [req setValue:@"application/json"
  forHTTPHeaderField:@"Content-Type"];
        [req setValue:[@"Bearer " stringByAppendingString:token]
  forHTTPHeaderField:@"Authorization"];

        [self createSession];

        NSURLSessionDataTask *task =
            [self.session dataTaskWithRequest:req
                            completionHandler:^(NSData *data,
                                                NSURLResponse *response,
                                                NSError *networkError) {
            if (networkError) {
                [self showError:networkError.localizedDescription];
                return;
            }

            NSInteger code =
                [(NSHTTPURLResponse *)response statusCode];

            if (code != 200 && code != 201) {
                [self showError:[NSString stringWithFormat:
                    @"Comando non riuscito: HTTP %ld", (long)code]];
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self fetchStates];
            });
        }];

        [task resume];
    }];
}

@end
