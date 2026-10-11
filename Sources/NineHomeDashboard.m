#import "NineHomeDashboard.h"
#import "NineAreasLoader.h"
#import "NineControls.h"
#import "NineCustomDashboards.h"
#import "NineDashboardEditor.h"
#import "NineDemoData.h"
#import "NineDashboard.h"
#import "NineEntity.h"
#import "NineIcons.h"
#import "NineLiveSocket.h"
#import "NineMoreInfoPanel.h"
#import "NineNASAdapter.h"
#import "NineRefreshSettingsController.h"
#import "NineServersController.h"
#import "NineTheme.h"
#import <math.h>

static NSString *const NineHomeTab = @"__home__";
static NSString *const NineLightsBadge = @"__lights_on__";

static CGFloat const NineTileHeight = 56;
static CGFloat const NineTileGap = 8;
static CGFloat const NineTabsHeight = 46;

@interface NineHomeDashboard () <NSURLSessionTaskDelegate,
                                 NineMoreInfoDelegate,
                                 UIScrollViewDelegate>

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, copy) NSString *mode;

// Stato Home Assistant
@property (nonatomic, strong) NSMutableDictionary *stateByID;
@property (nonatomic, strong) NSDictionary *registry;
@property (nonatomic, strong) NSDictionary *areaByID;
@property (nonatomic, strong) NSArray *areaNames;
@property (nonatomic, strong) NSDictionary *areaIcons;
@property (nonatomic, strong) NineNASAdapter *nas;

// Preferenze locali
@property (nonatomic, copy) NSString *selectedTab;
@property (nonatomic, copy) NSString *currentDashboardID;   // nil = panoramica
@property (nonatomic, copy) NSString *locationName;
@property (nonatomic, strong) NSMutableArray *favorites;
@property (nonatomic, strong) NSMutableSet *hiddenEntities;

// Interfaccia
@property (nonatomic, strong) UIScrollView *tabsScroll;
@property (nonatomic, strong) UIScrollView *contentScroll;
@property (nonatomic, strong) UILabel *banner;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableDictionary *tilesByEntity;
@property (nonatomic, strong) NSMutableDictionary *badgesByEntity;
@property (nonatomic, strong) NSSet *watchedIDs;
@property (nonatomic, copy) NSString *layoutSignature;
@property (nonatomic, assign) CGFloat lastLayoutWidth;
@property (nonatomic, strong) NineMoreInfoPanel *moreInfo;
@property (nonatomic, strong) UIControl *drawerShade;
@property (nonatomic, strong) UIView *drawerPanel;
@property (nonatomic, assign) BOOL drawerClosing;
@property (nonatomic, assign) BOOL needsRedraw;

// Rete
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadedOnce;
@property (nonatomic, assign) BOOL requestedAreas;
@property (nonatomic, copy) NSString *areasStatus;
@property (nonatomic, strong) NineAreasLoader *areasLoader;
@property (nonatomic, assign) NSUInteger areaFetchGeneration;

// Live WebSocket
@property (nonatomic, strong) NineLiveSocket *live;
@property (nonatomic, strong) NSTimer *liveRetryTimer;
@property (nonatomic, strong) NSTimer *liveDrawTimer;
@property (nonatomic, strong) NSMutableSet *liveChanged;
@property (nonatomic, assign) BOOL liveConnected;
@property (nonatomic, assign) BOOL liveConnecting;
@property (nonatomic, assign) NSUInteger liveEpoch;
@property (nonatomic, assign) NSInteger liveRetryCount;

#ifdef NINEHA_DEBUG_HOOKS
@property (nonatomic, strong) NSTimer *debugTimer;
#endif

@end

@implementation NineHomeDashboard

- (instancetype)initWithAuth:(NineAuth *)auth mode:(NSString *)mode {
    self = [super initWithNibName:nil bundle:nil];

    if (self) {
        _auth = auth;
        _mode = [mode copy];
        _stateByID = [NSMutableDictionary dictionary];
        _registry = @{};
        _areaByID = @{};
        _areaNames = @[];
        _areaIcons = @{};
        _nas = [[NineNASAdapter alloc] init];
        _selectedTab = NineHomeTab;
        _tilesByEntity = [NSMutableDictionary dictionary];
        _badgesByEntity = [NSMutableDictionary dictionary];
        _favorites = [NSMutableArray array];
        _hiddenEntities = [NSMutableSet set];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Ciclo di vita

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Home";
    self.view.backgroundColor = NTBackground();
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.navigationItem.leftBarButtonItem =
        NineIconBarItem(@"menu", self, @selector(openMenu));
    self.navigationItem.leftBarButtonItem.accessibilityLabel = @"Menu";

    self.currentDashboardID = [NineCustomDashboards
        startDashboardIDForServer:self.auth.serverURL];
    [self updateNavigationItems];

    self.tabsScroll = [[UIScrollView alloc] init];
    self.tabsScroll.backgroundColor = NTHeader();
    self.tabsScroll.showsHorizontalScrollIndicator = NO;
    self.tabsScroll.alwaysBounceHorizontal = YES;
    self.tabsScroll.scrollsToTop = NO;
    [self.view addSubview:self.tabsScroll];

    self.contentScroll = [[UIScrollView alloc] init];
    self.contentScroll.backgroundColor = NTBackground();
    self.contentScroll.alwaysBounceVertical = YES;
    self.contentScroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.contentScroll.delegate = self;
    [self.view addSubview:self.contentScroll];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    UIScreenEdgePanGestureRecognizer *edge =
        [[UIScreenEdgePanGestureRecognizer alloc]
            initWithTarget:self action:@selector(drawerEdgePan:)];
    edge.edges = UIRectEdgeLeft;
    [self.view addGestureRecognizer:edge];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(refreshSettingsChanged)
               name:NineRefreshSettingsChangedNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(customDashboardsChanged)
               name:NineCustomDashboardsChangedNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(applicationDidBecomeActive)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NTStyleNavigationBar(self.navigationController.navigationBar);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSMutableArray *favorites = [NSMutableArray array];
    for (id item in [defaults arrayForKey:@"NineHA.Favorites"] ?: @[]) {
        if ([item isKindOfClass:[NSString class]] &&
            ![favorites containsObject:item]) {
            [favorites addObject:item];
        }
    }
    self.favorites = favorites;

    self.hiddenEntities = [NSMutableSet setWithArray:
        [defaults arrayForKey:@"NineHA.HiddenEntities"] ?: @[]];

    [self rebuildIfNeeded:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self refreshAll];
    [self configureRefreshTimer];
    [self connectLive];

#ifdef NINEHA_DEBUG_HOOKS
    [self.debugTimer invalidate];
    self.debugTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                       target:self
                                                     selector:@selector(debugPoll)
                                                     userInfo:nil
                                                      repeats:YES];
#endif
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.timer invalidate];
    self.timer = nil;
    [self stopLive];

#ifdef NINEHA_DEBUG_HOOKS
    // Il polling resta attivo anche fuori schermo per poter tornare.
#endif

    [self.areasLoader cancel];
    self.areasLoader = nil;
    self.areaFetchGeneration++;
    self.requestedAreas = self.registry.count > 0;

    [self closeDrawerImmediately];
    [self.moreInfo removeFromSuperview];
    self.moreInfo = nil;

    [self.session invalidateAndCancel];
    self.session = nil;
    self.loading = NO;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;

    // Le dashboard personalizzate non hanno schede per stanza.
    CGFloat tabs = self.currentDashboardID ? 0 : NineTabsHeight;
    self.tabsScroll.hidden = tabs == 0;
    self.tabsScroll.frame = CGRectMake(0, 0, bounds.size.width, tabs);
    self.contentScroll.frame = CGRectMake(0, tabs,
        bounds.size.width, bounds.size.height - tabs);
    self.spinner.center = CGPointMake(bounds.size.width / 2,
                                      bounds.size.height / 2);

    if (fabs(self.lastLayoutWidth - bounds.size.width) > 0.5) {
        [self rebuildIfNeeded:YES];
    }
}

#pragma mark - Dashboard personalizzate

- (NSDictionary *)currentDashboard {
    return [NineCustomDashboards dashboardWithID:self.currentDashboardID
                                          server:self.auth.serverURL];
}

- (void)updateNavigationItems {
    NSDictionary *custom = [self currentDashboard];
    self.title = custom ? custom[@"name"] : (self.locationName ?: @"Home");

    UIBarButtonItem *search =
        NineIconBarItem(@"magnify", self, @selector(openList));
    search.accessibilityLabel = @"Cerca entità";

    UIBarButtonItem *refresh =
        NineIconBarItem(@"refresh", self, @selector(manualRefresh));
    refresh.accessibilityLabel = @"Aggiorna";

    if (custom) {
        UIBarButtonItem *edit =
            NineIconBarItem(@"pencil", self, @selector(editCurrentDashboard));
        edit.accessibilityLabel = @"Modifica dashboard";
        self.navigationItem.rightBarButtonItems = @[search, edit, refresh];
    } else {
        self.navigationItem.rightBarButtonItems = @[search, refresh];
    }
}

- (void)customDashboardsChanged {
    if (self.currentDashboardID && ![self currentDashboard]) {
        self.currentDashboardID = nil;
    }
    [self updateNavigationItems];
    if (self.isViewLoaded) {
        [self.view setNeedsLayout];
        [self rebuildIfNeeded:YES];
    }
}

- (void)showDashboard:(NSString *)identifier {
    self.currentDashboardID = identifier;
    if (!identifier) self.selectedTab = NineHomeTab;
    [self updateNavigationItems];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self rebuildIfNeeded:YES];
    [self.contentScroll setContentOffset:CGPointZero animated:NO];
}

- (void)editCurrentDashboard {
    if (!self.currentDashboardID) return;
    NineDashboardEditor *editor = [[NineDashboardEditor alloc]
        initWithServerURL:self.auth.serverURL
              dashboardID:self.currentDashboardID
                   states:self.stateByID
                 registry:self.registry];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)createDashboardAddingEntity:(NSString *)entityID {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Nuova dashboard"
                         message:@"Scegli un nome, poi aggiungi le entità."
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Es. Soggiorno sera";
        field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Crea"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *identifier = [NineCustomDashboards
            createDashboardNamed:alert.textFields.firstObject.text
                          server:self.auth.serverURL];

        if (entityID) {
            [NineCustomDashboards addEntity:entityID
                                toDashboard:identifier
                                     server:self.auth.serverURL];
            [self showDashboard:identifier];
        } else {
            [self showDashboard:identifier];
            [self editCurrentDashboard];
        }
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chooseDashboardForEntity:(NSString *)entityID source:(UIView *)source {
    NSArray *dashboards = [NineCustomDashboards
        dashboardsForServer:self.auth.serverURL];

    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:@"Aggiungi a dashboard"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *dashboard in dashboards) {
        NSString *identifier = dashboard[@"id"];
        [menu addAction:[UIAlertAction actionWithTitle:dashboard[@"name"]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *a) {
            [NineCustomDashboards addEntity:entityID
                                toDashboard:identifier
                                     server:self.auth.serverURL];
        }]];
    }

    [menu addAction:[UIAlertAction actionWithTitle:@"Nuova dashboard…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        [self createDashboardAddingEntity:entityID];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    menu.popoverPresentationController.sourceView = source;
    menu.popoverPresentationController.sourceRect = source.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)removeFromCurrentDashboard:(NSString *)entityID {
    NSMutableDictionary *dashboard = [[self currentDashboard] mutableCopy];
    if (!dashboard) return;

    NSMutableArray *sections = [NSMutableArray array];
    for (NSDictionary *section in dashboard[@"sections"]) {
        NSMutableDictionary *copy = [section mutableCopy];
        NSMutableArray *items = [copy[@"items"] mutableCopy];
        [items removeObject:entityID];
        copy[@"items"] = items;
        [sections addObject:copy];
    }
    dashboard[@"sections"] = sections;
    [NineCustomDashboards saveDashboard:dashboard server:self.auth.serverURL];
}

- (void)applicationDidBecomeActive {
    if (!self.view.window) return;

    // Al ritorno in primo piano recuperiamo lo stato completo.
    [self fetchStates];
    if (!self.liveConnected) [self connectLive];
}

#pragma mark - Token e sessione

- (void)withToken:(NineAuthCompletion)completion {
    [self.auth useTokenForMode:self.mode completion:completion];
}

- (void)createSession {
    if (self.session) return;

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 20;
    config.timeoutIntervalForResource = 30;

    self.session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:nil];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    // Nessun redirect: il token non deve uscire dal server scelto.
    completionHandler(nil);
}

- (NSMutableURLRequest *)requestForPath:(NSString *)path token:(NSString *)token {
    NSURL *url = [NSURL URLWithString:
        [self.auth.serverURL stringByAppendingString:path]];
    if (!url) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 20;
    [request setValue:[@"Bearer " stringByAppendingString:token]
   forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    return request;
}

#pragma mark - Caricamento dati

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
#ifdef NINEHA_DEMO
    self.locationName = [NineDemoData locationName];
    [self updateNavigationItems];
    return;
#endif
    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *error) {
        NineHomeDashboard *owner = weakSelf;
        if (!owner || error || !token.length) return;

        NSMutableURLRequest *request =
            [owner requestForPath:@"/api/config" token:token];
        if (!request) return;

        [owner createSession];

        [[owner.session dataTaskWithRequest:request
                          completionHandler:^(NSData *data,
                                              NSURLResponse *response,
                                              NSError *networkError) {
            if (networkError || !data.length ||
                [(NSHTTPURLResponse *)response statusCode] != 200) return;

            id json = [NSJSONSerialization JSONObjectWithData:data
                                                      options:0
                                                        error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) return;

            NSString *name = json[@"location_name"];
            if (![name isKindOfClass:[NSString class]]) return;

            name = [name stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!name.length) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.locationName = name;
                [weakSelf updateNavigationItems];
            });
        }] resume];
    }];
}

- (void)fetchAreas {
#ifdef NINEHA_DEMO
    self.areaByID = [NineDemoData entityAreas];
    self.areaNames = [NineDemoData areaNames];
    self.areaIcons = [NineDemoData areaIcons];
    self.registry = [NineDemoData registry];
    self.areasStatus = [NSString stringWithFormat:@"%lu stanze",
        (unsigned long)self.areaNames.count];
    [self rebuildIfNeeded:NO];
    return;
#endif
    NSUInteger generation = ++self.areaFetchGeneration;

    [self.areasLoader cancel];
    self.areasLoader = nil;
    self.areasStatus = @"stanze in caricamento";

    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *authError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NineHomeDashboard *owner = weakSelf;

            if (!owner || generation != owner.areaFetchGeneration) return;

            if (authError || !token.length) {
                owner.requestedAreas = NO;
                owner.areasStatus = @"token non disponibile";
                return;
            }

            __block NineAreasLoader *loader = nil;

            loader = [[NineAreasLoader alloc]
                initWithServerURL:owner.auth.serverURL
                            token:token
                       completion:^(NSDictionary *map,
                                    NSArray *names,
                                    NSError *error) {

                NineHomeDashboard *controller = weakSelf;
                if (!controller ||
                    generation != controller.areaFetchGeneration) return;

                controller.areasLoader = nil;

                if (error) {
                    controller.requestedAreas = NO;
                    controller.areasStatus = [NSString stringWithFormat:
                        @"WS: %@", error.localizedDescription];
                    NSLog(@"NineHA registri: %@", error.localizedDescription);
                    return;
                }

                controller.areaByID = map ?: @{};
                controller.areaNames = names ?: @[];
                controller.registry = loader.entityRegistry ?: @{};
                controller.areaIcons = loader.areaIcons ?: @{};
                controller.areasStatus = [NSString stringWithFormat:
                    @"%lu stanze", (unsigned long)names.count];

                [controller rebuildIfNeeded:NO];
                loader = nil;
            }];

            owner.areasLoader = loader;
            [loader start];
        });
    }];
}

- (void)fetchStates {
#ifdef NINEHA_DEMO
    if (!self.loadedOnce) {
        self.loading = YES;
        [self finishLoad:[NineDemoData states] message:nil];
    }
    return;
#endif
    if (self.loading) return;
    self.loading = YES;
    [self createSession];

    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *error) {
        NineHomeDashboard *owner = weakSelf;
        if (!owner) return;

        if (error || !token.length) {
            [owner finishLoad:nil message:
                error.localizedDescription ?: @"Token mancante"];
            return;
        }

        NSMutableURLRequest *request =
            [owner requestForPath:@"/api/states" token:token];
        if (!request) {
            [owner finishLoad:nil message:@"Indirizzo server non valido"];
            return;
        }

        [owner createSession];

        [[owner.session dataTaskWithRequest:request
                          completionHandler:^(NSData *data,
                                              NSURLResponse *response,
                                              NSError *networkError) {
            NineHomeDashboard *current = weakSelf;
            if (!current) return;

            if (networkError) {
                [current finishLoad:nil
                            message:networkError.localizedDescription];
                return;
            }

            NSInteger code = [(NSHTTPURLResponse *)response statusCode];
            if (code != 200) {
                [current finishLoad:nil message:
                    [NSString stringWithFormat:@"HTTP %ld", (long)code]];
                return;
            }

            id json = data.length
                ? [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:nil]
                : nil;

            if (![json isKindOfClass:[NSArray class]]) {
                [current finishLoad:nil message:@"Risposta non valida"];
                return;
            }

            [current finishLoad:json message:nil];
        }] resume];
    }];
}

- (void)finishLoad:(NSArray *)states message:(NSString *)errorMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loading = NO;

        if (!states) {
            [self.spinner stopAnimating];
            [self showBanner:[NSString stringWithFormat:
                @"Connessione non riuscita: %@",
                errorMessage ?: @"errore sconosciuto"]];
            return;
        }

        NSMutableDictionary *index =
            [NSMutableDictionary dictionaryWithCapacity:states.count];

        for (id item in states) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSString *entityID = item[@"entity_id"];
            if ([entityID isKindOfClass:[NSString class]]) {
                index[entityID] = item;
            }
        }

        self.stateByID = index;
        self.loadedOnce = YES;
        [self.spinner stopAnimating];
        [self showBanner:nil];

        [self rebuildIfNeeded:NO];
    });
}

#pragma mark - Aggiornamento periodico e live

- (BOOL)wantsLive {
    return [NineRefreshSettingsController
        entityIntervalForServerURL:self.auth.serverURL] == 0;
}

- (void)refreshSettingsChanged {
    if (!self.view.window) return;

    [self configureRefreshTimer];

    if ([self wantsLive]) {
        [self connectLive];
    } else {
        [self stopLive];
        [self configureRefreshTimer];
    }
}

- (void)configureRefreshTimer {
    [self.timer invalidate];
    self.timer = nil;

    NSInteger seconds = [NineRefreshSettingsController
        entityIntervalForServerURL:self.auth.serverURL];

    if (seconds == 0) {
        if (self.liveConnected) return;
        seconds = 45;
    }

    self.timer = [NSTimer scheduledTimerWithTimeInterval:seconds
                                                  target:self
                                                selector:@selector(fetchStates)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stopLive {
    self.liveEpoch++;

    [self.liveRetryTimer invalidate];
    self.liveRetryTimer = nil;

    [self.liveDrawTimer invalidate];
    self.liveDrawTimer = nil;

    [self.live stop];
    self.live = nil;

    self.liveChanged = nil;
    self.liveConnecting = NO;
    self.liveConnected = NO;
    self.liveRetryCount = 0;
}

- (void)scheduleLiveRetry {
    if (!self.view.window || ![self wantsLive] || self.liveRetryTimer)
        return;

    self.liveRetryCount = MIN(self.liveRetryCount + 1, 5);
    NSTimeInterval delay =
        MIN(60.0, 5.0 * (1 << (self.liveRetryCount - 1)));

    self.liveRetryTimer = [NSTimer
        scheduledTimerWithTimeInterval:delay
                                target:self
                              selector:@selector(liveRetryFired)
                              userInfo:nil
                               repeats:NO];
}

- (void)liveRetryFired {
    self.liveRetryTimer = nil;
    [self connectLive];
}

- (void)connectLive {
#ifdef NINEHA_DEMO
    self.liveConnected = YES;
    return;
#endif
    if (![self wantsLive] || !self.view.window ||
        self.live || self.liveConnecting) return;

    self.liveConnecting = YES;
    NSUInteger epoch = ++self.liveEpoch;
    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NineHomeDashboard *owner = weakSelf;

            if (!owner || owner.liveEpoch != epoch ||
                !owner.view.window || ![owner wantsLive]) return;

            if (error || !token.length) {
                owner.liveConnecting = NO;
                [owner scheduleLiveRetry];
                return;
            }

            owner.live = [[NineLiveSocket alloc]
                initWithServerURL:owner.auth.serverURL
                            token:token
                          onState:^(NSString *entityID,
                                    NSDictionary *newState) {
                NineHomeDashboard *current = weakSelf;
                if (current && current.liveEpoch == epoch) {
                    [current receiveLiveEntity:entityID state:newState];
                }
            } onStatus:^(BOOL ready) {
                NineHomeDashboard *current = weakSelf;
                if (current && current.liveEpoch == epoch) {
                    [current liveStatusChanged:ready];
                }
            }];

            [owner.live start];
        });
    }];
}

- (void)liveStatusChanged:(BOOL)ready {
    self.liveConnecting = NO;
    self.liveConnected = ready;

    if (ready) {
        self.liveRetryCount = 0;
        // Recuperiamo eventuali eventi persi durante la connessione.
        [self fetchStates];
    } else {
        [self.live stop];
        self.live = nil;
        [self scheduleLiveRetry];
    }

    [self configureRefreshTimer];
}

- (void)receiveLiveEntity:(NSString *)entityID state:(NSDictionary *)newState {
    if (!entityID.length) return;

    // Lo stato viene sempre aggiornato, anche per entità non
    // visibili: i sensori NAS determinano lo stato del tile.
    if (newState) {
        self.stateByID[entityID] = newState;
    } else {
        [self.stateByID removeObjectForKey:entityID];
    }

    if (![self.watchedIDs containsObject:entityID] &&
        ![entityID hasPrefix:@"light."]) return;

    if (!self.liveChanged) self.liveChanged = [NSMutableSet set];
    [self.liveChanged addObject:entityID];

    // Accorpiamo aggiornamenti ravvicinati.
    if (!self.liveDrawTimer) {
        self.liveDrawTimer = [NSTimer
            scheduledTimerWithTimeInterval:.25
                                    target:self
                                  selector:@selector(flushLiveChanges)
                                  userInfo:nil
                                   repeats:NO];
    }
}

- (void)flushLiveChanges {
    self.liveDrawTimer = nil;

    NSSet *changed = [self.liveChanged copy];
    [self.liveChanged removeAllObjects];

    if (!changed.count || !self.view.window) return;

    [self updateDisplayedEntities:changed];
}

#pragma mark - Modello della dashboard

- (NSDictionary *)registryFor:(NSString *)entityID {
    NSDictionary *info = self.registry[entityID];
    return [info isKindOfClass:[NSDictionary class]] ? info : nil;
}

- (NSString *)areaFor:(NSString *)entityID {
    NSString *area = self.areaByID[entityID];

    // Lo switch NAS senza stanza segue il sensore di stato.
    if (!area && [NineNASAdapter isNASEntity:entityID]) {
        NSArray *dependencies = [NineNASAdapter dependencies];
        for (NSString *dependency in dependencies) {
            area = self.areaByID[dependency];
            if (area) break;
        }
    }

    return [area isKindOfClass:[NSString class]] ? area : nil;
}

// Nella panoramica mostriamo solo i sensori "ambientali" e di
// sicurezza; la scheda della stanza li elenca tutti.
- (BOOL)isSummarySensor:(NSString *)entityID {
    NSString *domain = NEDomain(entityID);
    NSString *dc = NEDeviceClass(self.stateByID[entityID]);

    if ([domain isEqualToString:@"sensor"]) {
        return [@[@"temperature", @"humidity", @"illuminance",
                  @"carbon_dioxide", @"pm25", @"pm10", @"aqi",
                  @"moisture", @"battery"] containsObject:dc];
    }

    // Pulsanti mai premuti o non disponibili (reset, manutenzione...).
    if ([domain isEqualToString:@"button"]) {
        return !NEIsUnavailable(self.stateByID[entityID]);
    }

    if ([domain isEqualToString:@"binary_sensor"]) {
        return [@[@"motion", @"occupancy", @"presence", @"door",
                  @"window", @"garage_door", @"opening", @"moisture",
                  @"smoke", @"gas", @"carbon_monoxide", @"safety"]
            containsObject:dc];
    }

    return YES;
}

- (BOOL)shouldShowEntity:(NSString *)entityID inArea:(BOOL)inArea {
    if ([self.hiddenEntities containsObject:entityID]) return NO;
    if ([NineNASAdapter isNASEntity:entityID]) return YES;
    if ([[NineNASAdapter dependencies] containsObject:entityID]) return NO;

    NSDictionary *info = [self registryFor:entityID];
    if ([info[@"hidden"] boolValue] || info[@"category"]) return NO;

    NSString *domain = NEDomain(entityID);

    static NSSet *areaDomains, *looseDomains;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        looseDomains = [NSSet setWithArray:@[
            @"light", @"switch", @"fan", @"cover", @"climate",
            @"media_player", @"vacuum", @"lock", @"humidifier",
            @"water_heater", @"input_boolean"
        ]];
        NSMutableSet *all = [looseDomains mutableCopy];
        [all addObjectsFromArray:@[@"sensor", @"binary_sensor",
                                   @"scene", @"script", @"button"]];
        areaDomains = all;
    });

    return [(inArea ? areaDomains : looseDomains) containsObject:domain];
}

- (NSArray *)sortedEntityIDs:(NSArray *)ids {
    return [ids sortedArrayUsingComparator:^NSComparisonResult(NSString *a,
                                                                NSString *b) {
        NSInteger da = NEDomainOrder(NEDomain(a));
        NSInteger db = NEDomainOrder(NEDomain(b));
        if ([NineNASAdapter isNASEntity:a]) da = -1;
        if ([NineNASAdapter isNASEntity:b]) db = -1;
        if (da != db) return da < db ? NSOrderedAscending : NSOrderedDescending;

        // Sensori dello stesso tipo raggruppati (temperature, umidità...).
        NSString *ca = NEDeviceClass(self.stateByID[a]);
        NSString *cb = NEDeviceClass(self.stateByID[b]);
        if (![ca isEqualToString:cb]) {
            if (!ca.length) return NSOrderedDescending;
            if (!cb.length) return NSOrderedAscending;
            return [ca compare:cb];
        }

        return [NEName(self.stateByID[a], [self registryFor:a])
            localizedCaseInsensitiveCompare:
                NEName(self.stateByID[b], [self registryFor:b])];
    }];
}

// Raggruppa per dominio, per le viste senza stanza e per le stanze.
- (NSArray *)domainSectionsFor:(NSArray *)ids iconless:(BOOL)iconless {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];

    for (NSString *entityID in ids) {
        NSString *domain = [NineNASAdapter isNASEntity:entityID]
            ? @"switch" : NEDomain(entityID);
        if (!groups[domain]) groups[domain] = [NSMutableArray array];
        [groups[domain] addObject:entityID];
    }

    NSArray *domains = [[groups allKeys]
        sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSInteger oa = NEDomainOrder(a), ob = NEDomainOrder(b);
            if (oa != ob) return oa < ob ? NSOrderedAscending : NSOrderedDescending;
            return [a compare:b];
        }];

    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *domain in domains) {
        [sections addObject:@{
            @"title": NEDomainTitle(domain),
            @"items": [self sortedEntityIDs:groups[domain]]
        }];
    }
    return sections;
}

- (NSDictionary *)buildModel {
    NSDictionary *custom = [self currentDashboard];
    if (custom) {
        NSMutableArray *sections = [NSMutableArray array];
        for (NSDictionary *section in custom[@"sections"]) {
            NSMutableArray *items = [NSMutableArray array];
            for (NSString *entityID in section[@"items"]) {
                if (![self.hiddenEntities containsObject:entityID])
                    [items addObject:entityID];
            }
            if (!items.count) continue;
            [sections addObject:@{@"title": section[@"title"] ?: @"",
                                  @"items": items}];
        }
        return @{@"areas": @[], @"sections": sections, @"badges": @[]};
    }

    BOOL overview = [self.selectedTab isEqualToString:NineHomeTab];
    NSMutableDictionary *byArea = [NSMutableDictionary dictionary];
    NSMutableArray *loose = [NSMutableArray array];

    for (NSString *entityID in self.stateByID) {
        NSString *area = [self areaFor:entityID];

        if (area.length) {
            if (![self shouldShowEntity:entityID inArea:YES]) continue;
            if (overview && ![self isSummarySensor:entityID]) continue;
            if (!byArea[area]) byArea[area] = [NSMutableArray array];
            [byArea[area] addObject:entityID];
        } else if ([self shouldShowEntity:entityID inArea:NO]) {
            [loose addObject:entityID];
        }
    }

    // Le schede elencano ogni stanza con almeno un'entità visibile.
    NSMutableSet *populated = [NSMutableSet set];
    for (NSString *entityID in self.stateByID) {
        NSString *area = [self areaFor:entityID];
        if (area.length && ![populated containsObject:area] &&
            [self shouldShowEntity:entityID inArea:YES]) {
            [populated addObject:area];
        }
    }

    NSMutableArray *areas = [NSMutableArray array];
    for (NSString *name in self.areaNames) {
        if ([populated containsObject:name]) [areas addObject:name];
    }

    // Una stanza selezionata ma ormai vuota riporta alla panoramica.
    if (![self.selectedTab isEqualToString:NineHomeTab] &&
        ![areas containsObject:self.selectedTab]) {
        self.selectedTab = NineHomeTab;
    }

    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *badges = [NSMutableArray array];

    if ([self.selectedTab isEqualToString:NineHomeTab]) {
        // Badge: meteo, persone, luci accese.
        NSMutableArray *weather = [NSMutableArray array];
        NSMutableArray *people = [NSMutableArray array];

        for (NSString *entityID in self.stateByID) {
            if ([self.hiddenEntities containsObject:entityID]) continue;
            NSDictionary *info = [self registryFor:entityID];
            if ([info[@"hidden"] boolValue]) continue;

            if ([entityID hasPrefix:@"weather."]) [weather addObject:entityID];

            // Persone senza tracker (utenti di servizio) restano fuori.
            if ([entityID hasPrefix:@"person."] &&
                !NEIsUnavailable(self.stateByID[entityID])) {
                [people addObject:entityID];
            }
        }

        [badges addObjectsFromArray:
            [[weather sortedArrayUsingSelector:@selector(compare:)]
                subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)1, weather.count))]];
        [badges addObjectsFromArray:
            [people sortedArrayUsingSelector:@selector(compare:)]];
        [badges addObject:NineLightsBadge];

        NSMutableArray *favorites = [NSMutableArray array];
        for (NSString *entityID in self.favorites) {
            if (self.stateByID[entityID] &&
                ![self.hiddenEntities containsObject:entityID]) {
                [favorites addObject:entityID];
            }
        }

        if (favorites.count) {
            [sections addObject:@{
                @"title": @"Preferiti",
                @"icon": @"star",
                @"items": favorites
            }];
        }

        for (NSString *area in areas) {
            if (![byArea[area] count]) continue;
            [sections addObject:@{
                @"title": area,
                @"icon": self.areaIcons[area] ?: @"",
                @"area": area,
                @"items": [self sortedEntityIDs:byArea[area]]
            }];
        }

        if (loose.count) {
            for (NSDictionary *section in
                    [self domainSectionsFor:loose iconless:YES]) {
                NSMutableDictionary *copy = [section mutableCopy];
                copy[@"subtitle"] = @"Senza stanza";
                [sections addObject:copy];
            }
        }
    } else {
        [sections addObjectsFromArray:
            [self domainSectionsFor:byArea[self.selectedTab] ?: @[]
                           iconless:YES]];
    }

    return @{@"areas": areas, @"sections": sections, @"badges": badges};
}

#pragma mark - Disegno

- (void)rebuildIfNeeded:(BOOL)force {
    if (!self.isViewLoaded) return;

    [self.nas updateWithStates:self.stateByID];

    NSDictionary *model = [self buildModel];

    NSMutableString *signature = [NSMutableString string];
    [signature appendString:self.selectedTab];
    [signature appendFormat:@"|%@", self.currentDashboardID ?: @"-"];
    for (NSDictionary *section in model[@"sections"]) {
        [signature appendFormat:@"|%@:", section[@"title"]];
        [signature appendString:[section[@"items"] componentsJoinedByString:@","]];
    }
    [signature appendFormat:@"|%@", [model[@"badges"] componentsJoinedByString:@","]];
    [signature appendFormat:@"|%@", [model[@"areas"] componentsJoinedByString:@","]];

    CGFloat width = self.view.bounds.size.width;

    if (!force && [signature isEqualToString:self.layoutSignature] &&
        fabs(width - self.lastLayoutWidth) < 0.5) {
        // Struttura invariata: aggiorniamo solo i contenuti.
        [self updateDisplayedEntities:nil];
        return;
    }

    self.layoutSignature = signature;
    self.lastLayoutWidth = width;

    [self layoutTabs:model[@"areas"]];
    [self layoutContent:model];
}

- (void)layoutTabs:(NSArray *)areas {
    for (UIView *view in [self.tabsScroll.subviews copy]) {
        [view removeFromSuperview];
    }

    NSMutableArray *keys = [NSMutableArray arrayWithObject:NineHomeTab];
    [keys addObjectsFromArray:areas];

    CGFloat x = 8;
    UIView *selectedView = nil;

    for (NSString *key in keys) {
        BOOL home = [key isEqualToString:NineHomeTab];
        BOOL selected = [key isEqualToString:self.selectedTab];
        NSString *title = home ? @"Panoramica" : key;

        UIFont *font = NTMediumFont(14);
        CGFloat textWidth = ceilf([title sizeWithAttributes:
            @{NSFontAttributeName: font}].width);
        CGFloat width = MAX((CGFloat)64, textWidth + 32);

        UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
        tab.frame = CGRectMake(x, 0, width, NineTabsHeight);
        tab.titleLabel.font = font;
        tab.accessibilityIdentifier = key;
        [tab setTitle:title forState:UIControlStateNormal];
        [tab setTitleColor:selected ? NTText() : NTSecondaryText()
                  forState:UIControlStateNormal];
        [tab addTarget:self
                action:@selector(tabTapped:)
      forControlEvents:UIControlEventTouchUpInside];

        if (selected) {
            UIView *indicator = [[UIView alloc] initWithFrame:
                CGRectMake(12, NineTabsHeight - 3, width - 24, 3)];
            indicator.backgroundColor = NTPrimary();
            indicator.layer.cornerRadius = 1.5f;
            indicator.userInteractionEnabled = NO;
            [tab addSubview:indicator];
            selectedView = tab;
        }

        [self.tabsScroll addSubview:tab];
        x += width;
    }

    UIView *line = [[UIView alloc] initWithFrame:
        CGRectMake(0, NineTabsHeight - 0.5f, MAX(x + 8,
            self.tabsScroll.bounds.size.width), 0.5f)];
    line.backgroundColor = NTBorder();
    [self.tabsScroll insertSubview:line atIndex:0];

    self.tabsScroll.contentSize = CGSizeMake(x + 8, NineTabsHeight);

    if (selectedView) {
        [self.tabsScroll scrollRectToVisible:
            CGRectInset(selectedView.frame, -40, 0) animated:NO];
    }
}

- (void)tabTapped:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!key.length || [key isEqualToString:self.selectedTab]) return;
    [self selectTab:key];
}

- (void)selectTab:(NSString *)key {
    self.selectedTab = key;
    [self rebuildIfNeeded:YES];
    [self.contentScroll setContentOffset:CGPointZero animated:NO];
}

- (void)sectionHeaderTapped:(UIButton *)sender {
    NSString *area = sender.accessibilityIdentifier;
    if (area.length) [self selectTab:area];
}

- (void)showBanner:(NSString *)message {
    if (!message.length) {
        if (self.banner) {
            [self.banner removeFromSuperview];
            self.banner = nil;
            [self rebuildIfNeeded:YES];
        }
        return;
    }

    if (!self.banner) {
        self.banner = [[UILabel alloc] init];
        self.banner.numberOfLines = 2;
        self.banner.textAlignment = NSTextAlignmentCenter;
        self.banner.font = NTMediumFont(13);
        self.banner.textColor = [UIColor whiteColor];
        self.banner.backgroundColor = NTHex(0xDB4437, .85f);
        self.banner.layer.cornerRadius = 10;
        self.banner.clipsToBounds = YES;
        self.banner.text = message;
        [self rebuildIfNeeded:YES];
    } else {
        self.banner.text = message;
    }
}

- (void)layoutContent:(NSDictionary *)model {
    for (UIView *view in [self.contentScroll.subviews copy]) {
        if (![view isKindOfClass:[UIImageView class]]) [view removeFromSuperview];
    }
    [self.tilesByEntity removeAllObjects];
    [self.badgesByEntity removeAllObjects];

    CGFloat width = self.view.bounds.size.width;
    BOOL wide = width >= 700;
    CGFloat margin = wide ? 16 : 10;
    CGFloat columnGap = wide ? 16 : 10;
    CGFloat y = margin;

    NSMutableSet *watched = [NSMutableSet set];
    [watched addObjectsFromArray:[NineNASAdapter dependencies]];

    if (self.banner) {
        self.banner.frame = CGRectMake(margin, y, width - margin * 2, 40);
        [self.contentScroll addSubview:self.banner];
        y += 52;
    }

    // Badge centrati su più righe.
    NSArray *badgeIDs = model[@"badges"];
    if (badgeIDs.count && self.loadedOnce) {
        NSMutableArray *rows = [NSMutableArray array];
        NSMutableArray *row = [NSMutableArray array];
        CGFloat rowWidth = 0;

        for (NSString *entityID in badgeIDs) {
            NineBadgeView *badge = [[NineBadgeView alloc]
                initWithFrame:CGRectMake(0, 0, 100, 36)];
            badge.entityID = entityID;
            [badge addTarget:self
                      action:@selector(badgeTapped:)
            forControlEvents:UIControlEventTouchUpInside];

            if (![self configureBadge:badge]) continue;

            self.badgesByEntity[entityID] = badge;
            [watched addObject:entityID];

            CGFloat needed = badge.frame.size.width + (row.count ? 8 : 0);
            if (row.count && rowWidth + needed > width - margin * 2) {
                [rows addObject:@[row, @(rowWidth)]];
                row = [NSMutableArray array];
                rowWidth = 0;
                needed = badge.frame.size.width;
            }
            [row addObject:badge];
            rowWidth += needed;
        }
        if (row.count) [rows addObject:@[row, @(rowWidth)]];

        for (NSArray *line in rows) {
            CGFloat x = floorf((width - [line[1] floatValue]) / 2);
            for (NineBadgeView *badge in line[0]) {
                CGRect frame = badge.frame;
                frame.origin = CGPointMake(x, y);
                badge.frame = frame;
                [self.contentScroll addSubview:badge];
                x += frame.size.width + 8;
            }
            y += 44;
        }
        if (rows.count) y += 8;
    }

    // Sezioni in colonne, posizionate nella colonna più corta.
    // Colonne di almeno 420 pt; tile larghi abbastanza per i nomi.
    CGFloat usable = width - margin * 2;
    NSInteger columns = MAX(1, MIN(3,
        (NSInteger)floorf((usable + columnGap) / (420 + columnGap))));

    // Poche sezioni: meglio colonne larghe che spazio vuoto.
    NSInteger sectionCount = 0;
    for (NSDictionary *section in model[@"sections"]) {
        if ([section[@"items"] count]) sectionCount++;
    }
    columns = MAX(1, MIN(columns, sectionCount));
    CGFloat columnWidth = floorf((usable -
        columnGap * (columns - 1)) / columns);
    CGFloat minimumTile = wide ? 200 : 140;
    NSInteger perRow = MAX(1, MIN(4,
        (NSInteger)floorf((columnWidth + NineTileGap) /
                          (minimumTile + NineTileGap))));
    CGFloat tileWidth = floorf((columnWidth - NineTileGap * (perRow - 1)) / perRow);

    NSMutableArray *heights = [NSMutableArray array];
    for (NSInteger i = 0; i < columns; i++) [heights addObject:@(y)];

    for (NSDictionary *section in model[@"sections"]) {
        NSArray *items = section[@"items"];
        if (!items.count) continue;

        NSInteger column = 0;
        for (NSInteger i = 1; i < columns; i++) {
            if ([heights[i] floatValue] < [heights[column] floatValue] - 1)
                column = i;
        }

        CGFloat x = margin + column * (columnWidth + columnGap);
        CGFloat top = [heights[column] floatValue];

        UIView *header = [self headerForSection:section width:columnWidth];
        header.frame = CGRectMake(x, top, columnWidth, header.frame.size.height);
        [self.contentScroll addSubview:header];
        top += header.frame.size.height;

        for (NSUInteger i = 0; i < items.count; i++) {
            NSString *entityID = items[i];
            NSInteger r = i / perRow, c = i % perRow;

            NineTileView *tile = [[NineTileView alloc] initWithFrame:
                CGRectMake(x + c * (tileWidth + NineTileGap),
                           top + r * (NineTileHeight + NineTileGap),
                           tileWidth, NineTileHeight)];
            tile.entityID = entityID;

            [tile addTarget:self
                     action:@selector(tileTapped:)
           forControlEvents:UIControlEventTouchUpInside];

            __weak typeof(self) weakSelf = self;
            tile.onIconTap = ^(NineTileView *view) {
                [weakSelf quickActionForTile:view];
            };

            UILongPressGestureRecognizer *press =
                [[UILongPressGestureRecognizer alloc]
                    initWithTarget:self action:@selector(tileLongPressed:)];
            press.minimumPressDuration = .5;
            [tile addGestureRecognizer:press];

            [self configureTile:tile];
            [self.contentScroll addSubview:tile];

            NSMutableArray *list = self.tilesByEntity[entityID];
            if (!list) {
                list = [NSMutableArray array];
                self.tilesByEntity[entityID] = list;
            }
            [list addObject:tile];
            [watched addObject:entityID];
        }

        NSInteger rowsCount = (items.count + perRow - 1) / perRow;
        top += rowsCount * (NineTileHeight + NineTileGap) - NineTileGap;
        heights[column] = @(top + 20);
    }

    CGFloat contentHeight = y;
    for (NSNumber *height in heights) {
        contentHeight = MAX(contentHeight, height.floatValue);
    }

    if (self.loadedOnce && ![model[@"sections"] count]) {
        UILabel *empty = [[UILabel alloc] initWithFrame:
            CGRectMake(20, y + 40, width - 40, 80)];
        empty.numberOfLines = 0;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = NTSecondaryText();
        empty.font = NTFont(15);
        empty.text = self.currentDashboardID
            ? @"Dashboard vuota.\nTocca la matita in alto per aggiungere entità."
            : @"Nessuna entità da mostrare.\n"
               "Usa la ricerca per aggiungere preferiti.";
        [self.contentScroll addSubview:empty];
        contentHeight = y + 140;
    }

    self.watchedIDs = watched;
    self.contentScroll.contentSize =
        CGSizeMake(width, MAX(contentHeight + margin,
                              self.contentScroll.bounds.size.height + 1));
}

- (UIView *)headerForSection:(NSDictionary *)section width:(CGFloat)width {
    NSString *area = section[@"area"];
    NSString *icon = section[@"icon"];
    NSString *subtitle = section[@"subtitle"];

    UIButton *header = [UIButton buttonWithType:UIButtonTypeCustom];
    header.frame = CGRectMake(0, 0, width, subtitle.length ? 50
        : ([section[@"title"] length] ? 40 : 4));
    header.accessibilityIdentifier = area;
    header.accessibilityLabel = section[@"title"];
    header.userInteractionEnabled = area.length > 0;
    [header addTarget:self
               action:@selector(sectionHeaderTapped:)
     forControlEvents:UIControlEventTouchUpInside];

    CGFloat x = 2;

    if (icon.length && NineIconGlyph(icon)) {
        NineIconView *glyph = [[NineIconView alloc]
            initWithFrame:CGRectMake(0, 6, 24, 24) iconSize:20];
        glyph.iconName = icon;
        glyph.textColor = [icon isEqualToString:@"star"]
            ? NTHex(0xFFC107, 1) : NTSecondaryText();
        [header addSubview:glyph];
        x = 30;
    }

    UILabel *title = [[UILabel alloc]
        initWithFrame:CGRectMake(x, 6, width - x - 30, 24)];
    title.text = section[@"title"];
    title.font = NTMediumFont(17);
    title.textColor = NTText();
    [header addSubview:title];

    if (subtitle.length) {
        UILabel *sub = [[UILabel alloc]
            initWithFrame:CGRectMake(x, 28, width - x - 30, 16)];
        sub.text = subtitle;
        sub.font = NTFont(12);
        sub.textColor = NTSecondaryText();
        [header addSubview:sub];
    }

    if (area.length) {
        NineIconView *chevron = [[NineIconView alloc]
            initWithFrame:CGRectMake(width - 26, 6, 24, 24) iconSize:20];
        chevron.iconName = @"chevron-right";
        chevron.textColor = NTSecondaryText();
        [header addSubview:chevron];
    }

    return header;
}

- (void)configureTile:(NineTileView *)tile {
    NSString *entityID = tile.entityID;
    NSDictionary *entity = self.stateByID[entityID];
    NSDictionary *info = [self registryFor:entityID];

    if ([NineNASAdapter isNASEntity:entityID]) {
        [tile setName:[NineNASAdapter configuredTitle]
                      ?: (entity ? NEName(entity, info) : @"NAS")
                state:[self.nas statusText]
                 icon:[self.nas iconName]
                color:[self.nas color]
               active:self.nas.poweredOn
          unavailable:self.nas.level == NineNASLevelUnknown];
        tile.iconTapEnabled = [NineNASAdapter gracefulService] != nil;
        return;
    }

    if (!entity) {
        [tile setName:entityID state:@"Non disponibile"
                 icon:@"help-circle-outline" color:NTDisabledText()
               active:NO unavailable:YES];
        tile.iconTapEnabled = NO;
        return;
    }

    BOOL unavailable = NEIsUnavailable(entity);

    [tile setName:NEName(entity, info)
            state:NEStateText(entity, info)
             icon:NEIconName(entity, info)
            color:NEIconColor(entity)
           active:NEIsActive(entity)
      unavailable:unavailable];

    NSString *domain = NEDomain(entityID);
    tile.iconTapEnabled = !unavailable &&
        (NEIsToggleable(entity) ||
         [@[@"scene", @"script", @"button"] containsObject:domain]);
}

- (BOOL)configureBadge:(NineBadgeView *)badge {
    NSString *entityID = badge.entityID;

    if ([entityID isEqualToString:NineLightsBadge]) {
        NSInteger count = 0;
        for (NSString *key in self.stateByID) {
            if (![key hasPrefix:@"light."]) continue;
            NSDictionary *info = [self registryFor:key];
            if ([info[@"hidden"] boolValue] || info[@"category"]) continue;
            if ([NEStateValue(self.stateByID[key]) isEqualToString:@"on"]) count++;
        }

        [badge setIcon:count ? @"lightbulb-group" : @"lightbulb-group-off"
                 color:count ? NTHex(0xFFC107, 1) : NTInactive()
                 title:@"Luci"
                 value:count == 0 ? @"Tutte spente"
                     : (count == 1 ? @"1 accesa"
                        : [NSString stringWithFormat:@"%ld accese", (long)count])];
        return YES;
    }

    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return NO;
    NSDictionary *info = [self registryFor:entityID];

    if ([entityID hasPrefix:@"weather."]) {
        NSDictionary *attrs = NEAttributes(entity);
        NSNumber *temperature = attrs[@"temperature"];
        NSString *unit = [attrs[@"temperature_unit"] isKindOfClass:[NSString class]]
            ? attrs[@"temperature_unit"] : @"°";
        NSString *value = [temperature isKindOfClass:[NSNumber class]]
            ? [NSString stringWithFormat:@"%@ %@",
                NEFormatNumber(temperature.doubleValue, 1), unit]
            : NEWeatherConditionText(NEStateValue(entity));

        [badge setIcon:NEWeatherIcon(NEStateValue(entity))
                 color:NTPrimary()
                 title:NEWeatherConditionText(NEStateValue(entity))
                 value:value];
        return YES;
    }

    [badge setIcon:NEIconName(entity, info)
             color:NEIconColor(entity)
             title:NEName(entity, info)
             value:NEStateText(entity, info)];
    return YES;
}

// Aggiorna i contenuti senza ricostruire la vista. Con nil
// aggiorna tutto; altrimenti solo le entità indicate.
- (void)updateDisplayedEntities:(NSSet *)changed {
    BOOL nasChanged = !changed;

    for (NSString *dependency in [NineNASAdapter dependencies]) {
        if ([changed containsObject:dependency]) nasChanged = YES;
    }

    if (nasChanged) [self.nas updateWithStates:self.stateByID];

    // Un'entità nuova o rimossa richiede la ricostruzione.
    if (changed) {
        for (NSString *entityID in changed) {
            if (!self.stateByID[entityID] && self.tilesByEntity[entityID]) {
                [self rebuildIfNeeded:YES];
                return;
            }
        }
    }

    for (NSString *entityID in self.tilesByEntity) {
        BOOL nasTile = [NineNASAdapter isNASEntity:entityID];
        if (changed && ![changed containsObject:entityID] &&
            !(nasTile && nasChanged)) continue;

        for (NineTileView *tile in self.tilesByEntity[entityID]) {
            [self configureTile:tile];
        }
    }

    BOOL lightsChanged = !changed;
    for (NSString *entityID in changed) {
        if ([entityID hasPrefix:@"light."]) lightsChanged = YES;
    }

    for (NSString *entityID in self.badgesByEntity) {
        BOOL lights = [entityID isEqualToString:NineLightsBadge];
        if (changed && ![changed containsObject:entityID] &&
            !(lights && lightsChanged)) continue;

        NineBadgeView *badge = self.badgesByEntity[entityID];
        CGFloat oldWidth = badge.frame.size.width;
        [self configureBadge:badge];

        // La larghezza cambia: riallineiamo l'intera riga.
        if (fabs(badge.frame.size.width - oldWidth) > 0.5) {
            [self rebuildIfNeeded:YES];
            return;
        }
    }

    if (self.moreInfo) {
        NSString *entityID = self.moreInfo.entityID;
        if (!changed || [changed containsObject:entityID]) {
            [self.moreInfo updateEntity:self.stateByID[entityID]];
        }
        NSArray *relatedIDs = [self.moreInfo.related allValues];
        BOOL relatedChanged = !changed;
        for (NSString *other in relatedIDs) {
            if ([changed containsObject:other]) relatedChanged = YES;
        }
        if (relatedChanged && relatedIDs.count) {
            [self.moreInfo updateRelatedStates:
                [self statesForRelated:self.moreInfo.related]];
        }
        if (nasChanged) [self.moreInfo refreshNAS];
    }
}

#pragma mark - Interazioni

- (void)tileTapped:(NineTileView *)tile {
    [self showMoreInfo:tile.entityID];
}

- (void)badgeTapped:(NineBadgeView *)badge {
    if ([badge.entityID isEqualToString:NineLightsBadge]) {
        [self showLightsMenuFrom:badge];
        return;
    }
    [self showMoreInfo:badge.entityID];
}

- (void)showLightsMenuFrom:(UIView *)source {
    NSMutableArray *on = [NSMutableArray array];
    for (NSString *key in self.stateByID) {
        if ([key hasPrefix:@"light."] &&
            [NEStateValue(self.stateByID[key]) isEqualToString:@"on"]) {
            NSDictionary *info = [self registryFor:key];
            if ([info[@"hidden"] boolValue] || info[@"category"]) continue;
            [on addObject:key];
        }
    }
    if (!on.count) return;

    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:@"Luci accese"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *key in [self sortedEntityIDs:on]) {
        NSString *name = NEName(self.stateByID[key], [self registryFor:key]);
        [menu addAction:[UIAlertAction
            actionWithTitle:[@"Spegni " stringByAppendingString:name]
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
            [self callService:@"turn_off" domain:@"light"
                     entityID:key data:@{} confirmed:YES];
        }]];
    }

    [menu addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    menu.popoverPresentationController.sourceView = source;
    menu.popoverPresentationController.sourceRect = source.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)quickActionForTile:(NineTileView *)tile {
    NSString *entityID = tile.entityID;

    if ([NineNASAdapter isNASEntity:entityID]) {
        [self requestNASPowerForce:NO];
        return;
    }

    NSDictionary *entity = self.stateByID[entityID];
    if (!entity || NEIsUnavailable(entity)) return;

    NSString *domain = NEDomain(entityID);

    if (NEIsToggleable(entity)) {
        NSString *service = NEIsActive(entity) ? @"turn_off" : @"turn_on";

        // Risposta immediata: lo stato reale arriva dal WebSocket.
        NSMutableDictionary *optimistic = [entity mutableCopy];
        optimistic[@"state"] = NEIsActive(entity) ? @"off" : @"on";
        [tile setName:tile.nameLabel.text
                state:NEStateText(optimistic, [self registryFor:entityID])
                 icon:NEIconName(optimistic, [self registryFor:entityID])
                color:NEIconColor(optimistic)
               active:NEIsActive(optimistic)
          unavailable:NO];

        [self callService:service domain:domain entityID:entityID
                     data:@{} confirmed:NO];
        return;
    }

    if ([domain isEqualToString:@"scene"]) {
        [self callService:@"turn_on" domain:domain entityID:entityID
                     data:@{} confirmed:NO];
    } else if ([domain isEqualToString:@"script"]) {
        [self callService:@"turn_on" domain:domain entityID:entityID
                     data:@{} confirmed:NO];
    } else if ([domain isEqualToString:@"button"]) {
        [self callService:@"press" domain:domain entityID:entityID
                     data:@{} confirmed:NO];
    } else {
        [self showMoreInfo:entityID];
    }
}

- (void)tileLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    [self showMenuForTile:(NineTileView *)gesture.view];
}

- (void)showMenuForTile:(NineTileView *)tile {
    NSString *entityID = tile.entityID;
    NSString *name = tile.nameLabel.text ?: entityID;

    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:name
                         message:entityID
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [menu addAction:[UIAlertAction actionWithTitle:@"Dettagli"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        [self showMoreInfo:entityID];
    }]];

    if ([NineNASAdapter isNASEntity:entityID] &&
        [NineNASAdapter forceService] &&
        self.nas.level != NineNASLevelOff) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Arresto forzato VM"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *a) {
            [self requestNASPowerForce:YES];
        }]];
    }

    BOOL favorite = [self.favorites containsObject:entityID];

    [menu addAction:[UIAlertAction
        actionWithTitle:favorite ? @"Rimuovi dai preferiti"
                                 : @"Aggiungi ai preferiti"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
        if (favorite) {
            [self.favorites removeObject:entityID];
        } else {
            [self.favorites addObject:entityID];
        }
        [self saveFavorites];
        [self rebuildIfNeeded:YES];
    }]];

    if (self.currentDashboardID) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Rimuovi da questa dashboard"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *a) {
            [self removeFromCurrentDashboard:entityID];
        }]];
    } else {
        [menu addAction:[UIAlertAction actionWithTitle:@"Aggiungi a dashboard…"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *a) {
            [self chooseDashboardForEntity:entityID source:tile];
        }]];
    }

    if (!self.currentDashboardID) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Nascondi dalla Home"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *a) {
            [self.hiddenEntities addObject:entityID];
            [self.favorites removeObject:entityID];
            [self saveFavorites];
            [[NSUserDefaults standardUserDefaults]
                setObject:[self.hiddenEntities allObjects]
                   forKey:@"NineHA.HiddenEntities"];
            [self rebuildIfNeeded:YES];
        }]];
    }

    [menu addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    menu.popoverPresentationController.sourceView = tile;
    menu.popoverPresentationController.sourceRect = tile.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)saveFavorites {
    [[NSUserDefaults standardUserDefaults]
        setObject:[self.favorites copy] forKey:@"NineHA.Favorites"];
}

- (void)showMoreInfo:(NSString *)entityID {
    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return;

    UIView *host = self.navigationController.view ?: self.view;

    [self.moreInfo removeFromSuperview];

    NSDictionary *related = [self relatedEntitiesFor:entityID];

    NineMoreInfoPanel *panel = [[NineMoreInfoPanel alloc]
        initWithEntity:entity
              registry:[self registryFor:entityID]
                  area:[self areaFor:entityID]
                   nas:self.nas
               related:related
         relatedStates:[self statesForRelated:related]];
    panel.delegate = self;
    self.moreInfo = panel;

    // Gli aggiornamenti live delle entità collegate devono arrivare.
    NSMutableSet *watched = [self.watchedIDs mutableCopy] ?: [NSMutableSet set];
    [watched addObjectsFromArray:[related allValues]];
    self.watchedIDs = watched;

    [panel showInView:host];
}

// Telecomando e batteria appartenenti allo stesso dispositivo.
- (NSDictionary *)relatedEntitiesFor:(NSString *)entityID {
    NSMutableDictionary *related = [NSMutableDictionary dictionary];
    NSString *domain = NEDomain(entityID);
    NSString *device = [self registryFor:entityID][@"device"];
    NSString *object = [entityID substringFromIndex:domain.length + 1];

    if ([domain isEqualToString:@"media_player"]) {
        NSString *sameName = [@"remote." stringByAppendingString:object];
        if (self.stateByID[sameName]) related[@"remote"] = sameName;
    }

    if (device.length) {
        for (NSString *other in self.stateByID) {
            if ([other isEqualToString:entityID]) continue;
            if (![[self registryFor:other][@"device"] isEqualToString:device])
                continue;

            if ([domain isEqualToString:@"media_player"] && !related[@"remote"] &&
                [other hasPrefix:@"remote."]) {
                related[@"remote"] = other;
            }
            if ([domain isEqualToString:@"vacuum"] && !related[@"battery"] &&
                [other hasPrefix:@"sensor."] &&
                [NEDeviceClass(self.stateByID[other]) isEqualToString:@"battery"]) {
                related[@"battery"] = other;
            }
        }
    }

    return related;
}

- (NSDictionary *)statesForRelated:(NSDictionary *)related {
    NSMutableDictionary *states = [NSMutableDictionary dictionary];
    for (NSString *entityID in [related allValues]) {
        if (self.stateByID[entityID]) states[entityID] = self.stateByID[entityID];
    }
    return states;
}

#pragma mark - NineMoreInfoDelegate

- (void)moreInfo:(NineMoreInfoPanel *)panel
     callService:(NSString *)service
          domain:(NSString *)domain
        entityID:(NSString *)entityID
            data:(NSDictionary *)data {
    [self callService:service domain:domain entityID:entityID
                 data:data confirmed:NO];
}

- (void)moreInfo:(NineMoreInfoPanel *)panel nasPowerForce:(BOOL)force {
    [self requestNASPowerForce:force];
}

- (void)moreInfo:(NineMoreInfoPanel *)panel
      chooseFrom:(NSArray *)options
           title:(NSString *)title
         current:(NSString *)current
          source:(UIView *)source
      completion:(void (^)(NSString *choice))completion {
    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:title
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (id option in options) {
        if (![option isKindOfClass:[NSString class]]) continue;
        BOOL selected = [option isEqual:current];
        [menu addAction:[UIAlertAction
            actionWithTitle:selected ? [@"✓ " stringByAppendingString:option] : option
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *a) {
            completion(option);
        }]];
    }

    [menu addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    menu.popoverPresentationController.sourceView = source;
    menu.popoverPresentationController.sourceRect = source.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)moreInfoDidClose:(NineMoreInfoPanel *)panel {
    if (self.moreInfo == panel) self.moreInfo = nil;
}

#pragma mark - NAS

- (NSString *)nasName {
    NSString *entityID = nil;
    for (NSString *key in self.tilesByEntity) {
        if ([NineNASAdapter isNASEntity:key]) entityID = key;
    }
    NSDictionary *entity = entityID ? self.stateByID[entityID] : nil;
    return [NineNASAdapter configuredTitle]
        ?: (entity ? NEName(entity, [self registryFor:entityID]) : @"NAS");
}

- (void)requestNASPowerForce:(BOOL)force {
    NSArray *service = force ? [NineNASAdapter forceService]
                             : [NineNASAdapter gracefulService];
    if (!service) return;

    BOOL on = self.nas.poweredOn;
    NSString *name = [self nasName];

    NSString *title = force ? @"Arresto forzato"
        : (on ? [@"Spegni " stringByAppendingString:name]
              : [@"Accendi " stringByAppendingString:name]);

    NSString *message = force
        ? @"La VM verrà fermata immediatamente. I dati non salvati "
           "potrebbero andare persi."
        : (on ? @"Il NAS verrà spento in modo sicuro (graceful)."
              : @"Il NAS verrà avviato.");

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [alert addAction:[UIAlertAction
        actionWithTitle:force ? @"Arresta" : (on ? @"Spegni" : @"Accendi")
                  style:force ? UIAlertActionStyleDestructive
                              : UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
        [self postService:service[1] domain:service[0] payload:@{}
               completion:^(BOOL ok) {
            if (!ok) return;
            [self.nas noteRequestedPower:force ? NO : !on];
            [self updateDisplayedEntities:
                [NSSet setWithArray:[NineNASAdapter dependencies]]];
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Servizi

- (BOOL)serviceAllowed:(NSString *)service
                domain:(NSString *)domain
                entity:(NSDictionary *)entity
                  data:(NSDictionary *)data {
    NSDictionary *attrs = NEAttributes(entity);
    NSInteger features = [attrs[@"supported_features"] integerValue];

    if ([@[@"light", @"switch", @"input_boolean", @"fan"] containsObject:domain]) {
        if (![@[@"turn_on", @"turn_off"] containsObject:service]) return NO;
        if (data[@"brightness_pct"]) {
            NSNumber *value = data[@"brightness_pct"];
            return [domain isEqualToString:@"light"] &&
                [value isKindOfClass:[NSNumber class]] &&
                value.integerValue >= 1 && value.integerValue <= 100;
        }
        return data.count == 0;
    }

    if ([domain isEqualToString:@"cover"]) {
        // Niente comandi su cancelli, porte e garage.
        NSSet *safe = [NSSet setWithArray:@[
            @"blind", @"curtain", @"shade", @"shutter", @"awning"]];
        if (![safe containsObject:attrs[@"device_class"]]) return NO;
        NSInteger needed = [service isEqualToString:@"open_cover"] ? 1
            : [service isEqualToString:@"close_cover"] ? 2
            : [service isEqualToString:@"stop_cover"] ? 8 : 0;
        return needed && (features & needed);
    }

    if ([domain isEqualToString:@"climate"]) {
        if (![service isEqualToString:@"set_temperature"] || !(features & 1))
            return NO;
        NSNumber *temperature = data[@"temperature"];
        if (![temperature isKindOfClass:[NSNumber class]] ||
            !isfinite(temperature.doubleValue)) return NO;
        double minimum = [attrs[@"min_temp"] isKindOfClass:[NSNumber class]]
            ? [attrs[@"min_temp"] doubleValue] : 7.0;
        double maximum = [attrs[@"max_temp"] isKindOfClass:[NSNumber class]]
            ? [attrs[@"max_temp"] doubleValue] : 35.0;
        return temperature.doubleValue >= minimum &&
               temperature.doubleValue <= maximum;
    }

    if ([domain isEqualToString:@"media_player"]) {
        if ([service isEqualToString:@"select_source"]) {
            NSArray *sources = attrs[@"source_list"];
            return data.count == 1 && [sources isKindOfClass:[NSArray class]] &&
                [sources containsObject:data[@"source"]];
        }
        if ([service isEqualToString:@"volume_mute"]) {
            return data.count == 1 &&
                [data[@"is_volume_muted"] isKindOfClass:[NSNumber class]];
        }
        return [@[@"turn_on", @"turn_off", @"media_play_pause",
                  @"media_next_track", @"media_previous_track",
                  @"volume_up", @"volume_down"]
            containsObject:service] && data.count == 0;
    }

    if ([domain isEqualToString:@"vacuum"]) {
        if ([service isEqualToString:@"set_fan_speed"]) {
            NSArray *speeds = attrs[@"fan_speed_list"];
            return data.count == 1 && [speeds isKindOfClass:[NSArray class]] &&
                [speeds containsObject:data[@"fan_speed"]];
        }
        return [@[@"start", @"pause", @"stop", @"return_to_base",
                  @"locate", @"clean_spot"] containsObject:service] &&
            data.count == 0;
    }

    if ([domain isEqualToString:@"remote"]) {
        // Solo tasti con nome noto: un testo libero verrebbe eseguito
        // come comando shell ADB dall'integrazione Android TV.
        NSSet *keys = [NSSet setWithArray:@[
            @"UP", @"DOWN", @"LEFT", @"RIGHT", @"CENTER",
            @"DPAD_UP", @"DPAD_DOWN", @"DPAD_LEFT", @"DPAD_RIGHT", @"DPAD_CENTER",
            @"BACK", @"HOME", @"MENU", @"VOLUME_UP", @"VOLUME_DOWN"]];
        return [service isEqualToString:@"send_command"] && data.count == 1 &&
            [keys containsObject:data[@"command"]];
    }

    if ([domain isEqualToString:@"scene"] || [domain isEqualToString:@"script"])
        return [service isEqualToString:@"turn_on"] && data.count == 0;

    if ([domain isEqualToString:@"button"] || [domain isEqualToString:@"input_button"])
        return [service isEqualToString:@"press"] && data.count == 0;

    return NO;
}

- (void)callService:(NSString *)service
             domain:(NSString *)domain
           entityID:(NSString *)entityID
               data:(NSDictionary *)data
          confirmed:(BOOL)confirmed {

    if (![NEDomain(entityID) isEqualToString:domain]) return;

    NSDictionary *entity = self.stateByID[entityID];
    if (!entity) return;

    if (![self serviceAllowed:service domain:domain entity:entity data:data]) {
        [self showError:[NSString stringWithFormat:
            @"Comando non consentito: %@.%@", domain, service]];
        return;
    }

    // Script e pulsanti possono avere effetti esterni: conferma.
    BOOL sensitive = [domain isEqualToString:@"script"] ||
                     [domain isEqualToString:@"button"] ||
                     [domain isEqualToString:@"input_button"];

    if (sensitive && !confirmed) {
        NSString *name = NEName(entity, [self registryFor:entityID]);
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Conferma azione"
                             message:[NSString stringWithFormat:
                                 @"Eseguire \"%@\"?", name]
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Esegui"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [self callService:service domain:domain entityID:entityID
                         data:data confirmed:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSMutableDictionary *payload = [@{@"entity_id": entityID} mutableCopy];
    [payload addEntriesFromDictionary:data ?: @{}];

    [self postService:service domain:domain payload:payload completion:nil];
}

- (void)postService:(NSString *)service
             domain:(NSString *)domain
            payload:(NSDictionary *)payload
         completion:(void (^)(BOOL ok))completion {
#ifdef NINEHA_DEMO
    if (completion) completion(YES);
    return;
#endif

    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *error) {
        NineHomeDashboard *owner = weakSelf;
        if (!owner) return;

        if (error || !token.length) {
            [owner showError:error.localizedDescription
                ?: @"Credenziali non disponibili"];
            return;
        }

        NSString *path = [NSString stringWithFormat:
            @"/api/services/%@/%@", domain, service];
        NSMutableURLRequest *request = [owner requestForPath:path token:token];
        if (!request) return;

        request.HTTPMethod = @"POST";
        request.HTTPBody = [NSJSONSerialization
            dataWithJSONObject:payload ?: @{} options:0 error:nil];
        [request setValue:@"application/json"
       forHTTPHeaderField:@"Content-Type"];

        [owner createSession];

        [[owner.session dataTaskWithRequest:request
                          completionHandler:^(NSData *data,
                                              NSURLResponse *response,
                                              NSError *networkError) {
            NSInteger code = [(NSHTTPURLResponse *)response statusCode];
            BOOL ok = !networkError && (code == 200 || code == 201);

            dispatch_async(dispatch_get_main_queue(), ^{
                NineHomeDashboard *current = weakSelf;
                if (!current) return;

                if (!ok) {
                    [current showError:networkError
                        ? networkError.localizedDescription
                        : [NSString stringWithFormat:
                            @"Comando non riuscito: HTTP %ld", (long)code]];
                    // Ripristina eventuali stati ottimistici.
                    [current updateDisplayedEntities:nil];
                } else if (!current.liveConnected) {
                    [current fetchStates];
                }

                if (completion) completion(ok);
            });
        }] resume];
    }];
}

- (void)showError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedViewController) return;

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"NineHA"
                             message:message
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Navigazione

- (void)openList {
    NineDashboard *list = [[NineDashboard alloc]
        initWithAuth:self.auth mode:self.mode];
    [self.navigationController pushViewController:list animated:YES];
}

- (void)openServers {
    NineServersController *controller = [[NineServersController alloc]
        initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)openSettings {
    NineRefreshSettingsController *settings =
        [[NineRefreshSettingsController alloc]
            initWithServerURL:self.auth.serverURL];
    [self.navigationController pushViewController:settings animated:YES];
}

#pragma mark - Menu laterale

- (void)drawerEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) [self openMenu];
}

- (void)closeDrawerImmediately {
    [self.drawerShade removeFromSuperview];
    self.drawerShade = nil;
    self.drawerPanel = nil;
    self.drawerClosing = NO;
}

- (void)drawerBackgroundTapped {
    [self closeDrawerWithAction:0];
}

- (void)drawerItemTapped:(UIButton *)sender {
    [self closeDrawerWithAction:sender.tag];
}

- (void)drawerSwipe:(UISwipeGestureRecognizer *)gesture {
    [self closeDrawerWithAction:0];
}

- (void)closeDrawerWithAction:(NSInteger)action {
    if (!self.drawerShade || self.drawerClosing) return;
    self.drawerClosing = YES;

    UIControl *shade = self.drawerShade;
    UIView *panel = self.drawerPanel;

    [UIView animateWithDuration:.22 animations:^{
        CGRect frame = panel.frame;
        frame.origin.x = -frame.size.width;
        panel.frame = frame;
        shade.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    } completion:^(BOOL finished) {
        [self closeDrawerImmediately];

        if (action >= 100) {
            NSArray *dashboards = [NineCustomDashboards
                dashboardsForServer:self.auth.serverURL];
            NSInteger index = action - 100;
            if (index < (NSInteger)dashboards.count) {
                [self showDashboard:dashboards[index][@"id"]];
            }
            return;
        }

        switch (action) {
            case 1: [self showDashboard:nil]; break;
            case 9: [self createDashboardAddingEntity:nil]; break;
            case 2: [self openList]; break;
            case 3: [self manualRefresh]; break;
            case 4: [self openServers]; break;
            case 5: [self openSettings]; break;
            case 6:
                [self.navigationController popToRootViewControllerAnimated:YES];
                break;
            default: break;
        }
    }];
}

- (void)openMenu {
    if (self.drawerShade || self.drawerClosing) return;

    UIView *host = self.navigationController.view;
    if (!host) return;

    CGFloat height = host.bounds.size.height;
    CGFloat panelWidth = MIN((CGFloat)280, host.bounds.size.width * .82f);

    UIControl *shade = [[UIControl alloc] initWithFrame:host.bounds];
    shade.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    [shade addTarget:self
              action:@selector(drawerBackgroundTapped)
    forControlEvents:UIControlEventTouchUpInside];

    UIView *panel = [[UIView alloc]
        initWithFrame:CGRectMake(-panelWidth, 0, panelWidth, height)];
    panel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    panel.backgroundColor = NTCard();
    [shade addSubview:panel];

    UIView *edge = [[UIView alloc]
        initWithFrame:CGRectMake(panelWidth - 0.5f, 0, 0.5f, height)];
    edge.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    edge.backgroundColor = NTBorder();
    [panel addSubview:edge];

    // Intestazione come la barra laterale HA.
    NineIconView *menuIcon = [[NineIconView alloc]
        initWithFrame:CGRectMake(14, 30, 30, 30) iconSize:24];
    menuIcon.iconName = @"menu";
    menuIcon.textColor = NTSecondaryText();
    [panel addSubview:menuIcon];

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(58, 28, panelWidth - 70, 34)];
    name.text = self.locationName ?: @"Home";
    name.font = NTMediumFont(20);
    name.textColor = NTText();
    [panel addSubview:name];

    UIView *divider = [[UIView alloc]
        initWithFrame:CGRectMake(0, 76, panelWidth, 0.5f)];
    divider.backgroundColor = NTBorder();
    [panel addSubview:divider];

    NSMutableArray *items = [NSMutableArray arrayWithObject:
        @[@1, @"view-dashboard", @"Panoramica"]];

    NSArray *dashboards = [NineCustomDashboards
        dashboardsForServer:self.auth.serverURL];
    for (NSUInteger i = 0; i < dashboards.count; i++) {
        NSString *icon = dashboards[i][@"icon"] ?: @"view-dashboard-variant";
        [items addObject:@[@(100 + i), icon, dashboards[i][@"name"]]];
    }

    [items addObjectsFromArray:@[
        @[@9, @"plus", @"Nuova dashboard"],
        @[@0, @"", @""],
        @[@2, @"format-list-bulleted", @"Entità"],
        @[@3, @"refresh", @"Aggiorna"],
        @[@0, @"", @""],
        @[@4, @"server-network", @"Server"],
        @[@5, @"cog", @"Aggiornamenti"],
        @[@6, @"account-key", @"Configurazione e accesso"]
    ]];

    // Voci scorrevoli: le dashboard possono essere molte.
    UIScrollView *list = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0, 77, panelWidth, height - 77 - 110)];
    list.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    list.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [panel addSubview:list];

    NSInteger selectedTag = 1;
    if (self.currentDashboardID) {
        for (NSUInteger i = 0; i < dashboards.count; i++) {
            if ([dashboards[i][@"id"] isEqualToString:self.currentDashboardID])
                selectedTag = 100 + i;
        }
    }

    CGFloat y = 9;

    for (NSArray *item in items) {
        NSInteger tag = [item[0] integerValue];

        if (tag == 0) {
            UIView *line = [[UIView alloc]
                initWithFrame:CGRectMake(0, y + 4, panelWidth, 0.5f)];
            line.backgroundColor = NTBorder();
            [list addSubview:line];
            y += 9;
            continue;
        }

        BOOL selected = tag == selectedTag;

        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(8, y, panelWidth - 16, 46);
        row.tag = tag;
        row.layer.cornerRadius = 8;
        row.backgroundColor = selected
            ? [NTPrimary() colorWithAlphaComponent:.14f] : [UIColor clearColor];
        row.accessibilityLabel = item[2];
        [row addTarget:self
                action:@selector(drawerItemTapped:)
      forControlEvents:UIControlEventTouchUpInside];

        NineIconView *icon = [[NineIconView alloc]
            initWithFrame:CGRectMake(8, 11, 24, 24) iconSize:24];
        icon.iconName = item[1];
        icon.textColor = selected ? NTPrimary() : NTSecondaryText();
        [row addSubview:icon];

        UILabel *label = [[UILabel alloc]
            initWithFrame:CGRectMake(50, 0, panelWidth - 74, 46)];
        label.text = item[2];
        label.font = NTMediumFont(14);
        label.textColor = selected ? NTPrimary() : NTText();
        [row addSubview:label];

        [list addSubview:row];
        y += 50;
    }

    list.contentSize = CGSizeMake(panelWidth, y + 8);

    // Piè di pagina: versione e connessione.
    NSString *version = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    UIView *status = [[UIView alloc]
        initWithFrame:CGRectMake(20, height - 92, 10, 10)];
    status.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    status.layer.cornerRadius = 5;
    status.backgroundColor = self.liveConnected ? NTSuccess()
        : ([self wantsLive] ? NTWarning() : NTPrimary());
    [panel addSubview:status];

    UILabel *connection = [[UILabel alloc]
        initWithFrame:CGRectMake(38, height - 98, panelWidth - 50, 22)];
    connection.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    connection.font = NTFont(12);
    connection.textColor = NTSecondaryText();
    connection.text = [NSString stringWithFormat:@"%@ · %lu entità · %@",
        self.liveConnected ? @"Live" : @"REST",
        (unsigned long)self.stateByID.count,
        self.areasStatus ?: @""];
    [panel addSubview:connection];

    UILabel *footer = [[UILabel alloc]
        initWithFrame:CGRectMake(20, height - 70, panelWidth - 40, 50)];
    footer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    footer.numberOfLines = 2;
    footer.font = NTFont(12);
    footer.textColor = NTDisabledText();
    footer.text = [NSString stringWithFormat:@"NineHA %@\n%@",
        version ?: @"", self.auth.serverURL ?: @""];
    footer.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [panel addSubview:footer];

    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(drawerSwipe:)];
    swipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [panel addGestureRecognizer:swipe];

    self.drawerShade = shade;
    self.drawerPanel = panel;
    [host addSubview:shade];

    [UIView animateWithDuration:.24 animations:^{
        CGRect frame = panel.frame;
        frame.origin.x = 0;
        panel.frame = frame;
        shade.backgroundColor = [UIColor colorWithWhite:0 alpha:.5f];
    }];
}

#ifdef NINEHA_DEBUG_HOOKS
#pragma mark - Debug (solo build di test)

// Comandi letti da Documents/nineha-cmd.txt, per collaudo via SSH.
// Nessun comando invia servizi a Home Assistant.
- (void)debugPoll {
    NSString *documents = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path = [documents stringByAppendingPathComponent:@"nineha-cmd.txt"];
    NSString *text = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    if (!text.length) return;
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    for (NSString *raw in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        if (!line.length) continue;

        NSRange space = [line rangeOfString:@" "];
        NSString *command = space.location == NSNotFound
            ? line : [line substringToIndex:space.location];
        NSString *argument = space.location == NSNotFound
            ? @"" : [line substringFromIndex:space.location + 1];

        UINavigationController *nav = self.navigationController;

        if ([command isEqualToString:@"scroll"]) {
            [self.contentScroll setContentOffset:
                CGPointMake(0, argument.floatValue) animated:NO];
        } else if ([command isEqualToString:@"tab"]) {
            [self selectTab:argument.length ? argument : NineHomeTab];
        } else if ([command isEqualToString:@"info"]) {
            [self showMoreInfo:argument];
        } else if ([command isEqualToString:@"close"]) {
            [self.moreInfo dismiss];
            [self closeDrawerWithAction:0];
            [self dismissViewControllerAnimated:NO completion:nil];
        } else if ([command isEqualToString:@"menu"]) {
            [self openMenu];
        } else if ([command isEqualToString:@"push"]) {
            if ([argument isEqualToString:@"list"]) [self openList];
            if ([argument isEqualToString:@"settings"]) [self openSettings];
            if ([argument isEqualToString:@"servers"]) [self openServers];
        } else if ([command isEqualToString:@"pop"]) {
            [nav popToViewController:self animated:NO];
        } else if ([command isEqualToString:@"root"]) {
            [nav popToRootViewControllerAnimated:NO];
        } else if ([command isEqualToString:@"longpress"]) {
            NineTileView *tile = [self.tilesByEntity[argument] firstObject];
            if (tile) {
                [self.contentScroll scrollRectToVisible:tile.frame animated:NO];
                [self showMenuForTile:tile];
            }
        } else if ([command isEqualToString:@"mkdash"]) {
            // mkdash Nome|Titolo sezione|entity1,entity2
            NSArray *parts = [argument componentsSeparatedByString:@"|"];
            NSString *identifier = [NineCustomDashboards
                createDashboardNamed:parts.firstObject server:self.auth.serverURL];
            NSMutableDictionary *dash = [[NineCustomDashboards
                dashboardWithID:identifier server:self.auth.serverURL] mutableCopy];
            if (parts.count >= 3) {
                dash[@"sections"] = @[@{@"title": parts[1],
                    @"items": [parts[2] componentsSeparatedByString:@","]}];
                [NineCustomDashboards saveDashboard:dash server:self.auth.serverURL];
            }
            [self showDashboard:identifier];
        } else if ([command isEqualToString:@"showdash"]) {
            NSArray *all = [NineCustomDashboards dashboardsForServer:self.auth.serverURL];
            NSInteger index = argument.integerValue;
            [self showDashboard:[argument isEqualToString:@"home"] || index >= (NSInteger)all.count
                ? nil : all[index][@"id"]];
        } else if ([command isEqualToString:@"edit"]) {
            [self editCurrentDashboard];
        } else if ([command isEqualToString:@"pick"]) {
            id top = nav.topViewController;
            if ([top isKindOfClass:[NineDashboardEditor class]])
                [top debugOpenPicker];
        } else if ([command isEqualToString:@"rmdash"]) {
            for (NSDictionary *dash in [NineCustomDashboards
                    dashboardsForServer:self.auth.serverURL]) {
                if ([dash[@"name"] isEqualToString:argument])
                    [NineCustomDashboards deleteDashboardWithID:dash[@"id"]
                                                         server:self.auth.serverURL];
            }
        } else if ([command isEqualToString:@"rotate"]) {
            UIInterfaceOrientation orientation =
                [argument isEqualToString:@"p"]
                    ? UIInterfaceOrientationPortrait
                    : UIInterfaceOrientationLandscapeLeft;
            [[UIDevice currentDevice] setValue:@(orientation)
                                        forKey:@"orientation"];
            [UIViewController attemptRotationToDeviceOrientation];
        } else if ([command isEqualToString:@"dump"]) {
            [self debugDump:argument];
        }
    }
}

- (void)debugDump:(NSString *)argument {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *entityID in [[self.stateByID allKeys]
            sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *entity = self.stateByID[entityID];
        NSDictionary *info = [self registryFor:entityID] ?: @{};
        [rows addObject:[NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t%@",
            entityID, NEStateValue(entity), [self areaFor:entityID] ?: @"-",
            NEDeviceClass(entity), info[@"category"] ?: @"",
            [info[@"hidden"] boolValue] ? @"H" : @""]];
    }
    // Attributi completi delle entità indicate (es. "dump fire|vacuum").
    NSString *pattern = argument.length ? argument : @"$^";
    for (NSString *entityID in self.stateByID) {
        if ([entityID rangeOfString:pattern
                options:NSRegularExpressionSearch | NSCaseInsensitiveSearch]
                .location == NSNotFound) continue;
        NSData *json = [NSJSONSerialization dataWithJSONObject:self.stateByID[entityID]
                                                       options:0 error:nil];
        [rows addObject:[@"#ATTR " stringByAppendingString:
            [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] ?: @""]];
    }

    NSString *caches = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    [[rows componentsJoinedByString:@"\n"]
        writeToFile:[caches stringByAppendingPathComponent:@"nineha-dump.tsv"]
         atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
#endif

@end
