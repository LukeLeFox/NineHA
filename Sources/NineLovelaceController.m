#import "NineLovelaceController.h"
#import "NineLovelaceLoader.h"
#import "NineLovelaceActionEngine.h"
#import "NineLightBrightnessController.h"
#import "NineTilesController.h"
#import "NineLovelaceLive.h"
#import "NineUnstableSettingsController.h"
#import "NineGlyphView.h"
#import "NineLocalConfig.h"
#import <WebKit/WebKit.h>
#import <math.h>

static NSString *NHAString(id v) {
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

static NSArray *NHAArray(id v) {
    return [v isKindOfClass:[NSArray class]] ? v : @[];
}

static NSDictionary *NHADict(id v) {
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}

@interface NineMasonryClockLabel : UILabel
@property (nonatomic, strong) NSDictionary *clockConfiguration;
@end

@implementation NineMasonryClockLabel
@end

// NineHA.ActionSurface6B
@interface NineActionSurface : UIView
@property (nonatomic, strong) NSDictionary *actionCard;
@end

@implementation NineActionSurface
@end

// NineHA.NativeDetails8E
@interface NineEntityDetailsController :
    UITableViewController

@property (nonatomic, copy) NSString *entityName;
@property (nonatomic, copy) NSString *entityID;
@property (nonatomic, copy) NSString *stateText;
@property (nonatomic, strong) UIColor *stateColor;
@property (nonatomic, copy) NSArray *detailRows;

@end

@implementation NineEntityDetailsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.entityName.length
        ? self.entityName : @"Dettagli";

    self.view.backgroundColor =
        [UIColor colorWithWhite:.08 alpha:1];

    self.tableView.backgroundColor =
        [UIColor colorWithWhite:.08 alpha:1];

    self.tableView.separatorColor =
        [UIColor colorWithWhite:.20 alpha:1];

    self.tableView.tableFooterView =
        [[UIView alloc] initWithFrame:CGRectZero];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Chiudi"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(closeDetails)];
}

- (void)closeDetails {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:
    (UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return section == 0
        ? 1 : (NSInteger)self.detailRows.count;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    return section == 1 && self.detailRows.count
        ? @"ATTRIBUTI" : nil;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 72 : 54;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *identifier =
        indexPath.section == 0
        ? @"NineDetailsState"
        : @"NineDetailsAttribute";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:
            identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:identifier];
    }

    cell.selectionStyle =
        UITableViewCellSelectionStyleNone;

    cell.backgroundColor =
        [UIColor colorWithRed:.12
                        green:.13
                         blue:.16
                        alpha:1];

    cell.textLabel.textColor =
        [UIColor whiteColor];

    cell.detailTextLabel.textColor =
        [UIColor colorWithWhite:.65 alpha:1];

    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryView = nil;

    if (indexPath.section == 0) {
        cell.textLabel.text =
            self.stateText.length
            ? self.stateText : @"—";

        cell.textLabel.font =
            [UIFont boldSystemFontOfSize:25];

        cell.textLabel.textColor =
            self.stateColor ?: [UIColor whiteColor];

        cell.detailTextLabel.text =
            self.entityID ?: @"";

        NineGlyphView *glyph =
            [[NineGlyphView alloc]
                initWithFrame:CGRectMake(0, 0, 34, 34)];

        glyph.entityID = self.entityID;
        glyph.tintColor =
            self.stateColor ?: [UIColor whiteColor];

        cell.accessoryView = glyph;

    } else {
        NSDictionary *row =
            indexPath.row < (NSInteger)self.detailRows.count
            ? self.detailRows[indexPath.row] : @{};

        cell.textLabel.text =
            NHAString(row[@"label"]) ?: @"";

        cell.detailTextLabel.text =
            NHAString(row[@"value"]) ?: @"—";

        cell.textLabel.font =
            [UIFont boldSystemFontOfSize:13];
    }

    return cell;
}

@end

@interface NineLovelaceController () <NSURLSessionTaskDelegate>

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, strong) NineLovelaceActionEngine *actionEngine;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NineLovelaceLoader *loader;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *clockTimer;
@property (nonatomic, strong) NSTimer *weatherTimer;
@property (nonatomic, strong) NSDictionary *weatherStates;
@property (nonatomic, assign) NSUInteger weatherGeneration;
@property (nonatomic, assign) BOOL weatherInFlight;
@property (nonatomic, strong) NineLovelaceLive *liveFeed;
@property (nonatomic, strong) NSTimer *liveRetryTimer;
@property (nonatomic, strong) NSTimer *liveUITimer;
@property (nonatomic, assign) BOOL liveConnected;
@property (nonatomic, assign) BOOL liveConnecting;
@property (nonatomic, assign) NSUInteger liveEpoch;
@property (nonatomic, assign) NSInteger liveRetries;
@property (nonatomic, strong) UIScrollView *tabs;

@property (nonatomic, strong) NSArray *dashboards;
@property (nonatomic, strong) NSArray *views;
@property (nonatomic, strong) NSArray *rows;
@property (nonatomic, strong) NSDictionary *states;

@property (nonatomic, copy) NSString *dashboardPath;
@property (nonatomic, assign) NSInteger selectedView;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL chooseViewAfterLoading;
@property (nonatomic, assign) CGFloat ninehaLastLayoutWidth;
@property (nonatomic, assign) CGFloat ninehaBuildingColumnWidth;
@property (nonatomic, assign) BOOL ninehaRelayoutOnly;

@end

@implementation NineLovelaceController

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode {
    self = [super initWithStyle:UITableViewStylePlain];

    if (self) {
        _auth = auth;
        _mode = [mode copy];

        _actionEngine =
            [[NineLovelaceActionEngine alloc]
                initWithAuth:auth mode:mode];

        _dashboards = @[];
        _views = @[];
        _rows = @[];
        _states = @{};
        _weatherStates = @{};
        _dashboardPath = @"lovelace";
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Lovelace Rebuilder";

    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorStyle =
        UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor =
        [UIColor colorWithWhite:.17 alpha:1];

    self.tableView.tableFooterView = [[UIView alloc] init];

    self.tabs = [[UIScrollView alloc]
        initWithFrame:CGRectMake(
            0, 0, self.view.bounds.size.width, 52)];

    self.tabs.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;
    self.tabs.showsHorizontalScrollIndicator = NO;
    self.tabs.backgroundColor =
        [UIColor colorWithWhite:.09 alpha:1];

    self.tableView.tableHeaderView =
        [[UIView alloc] initWithFrame:CGRectZero];

    UIBarButtonItem *choose = [[UIBarButtonItem alloc]
        initWithTitle:@"Dashboard"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(chooseDashboard)];

    UIBarButtonItem *refresh = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self
                             action:@selector(reloadConfiguration)];

    self.navigationItem.rightBarButtonItems = @[choose, refresh];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"NineHA"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(ninehaOpenClassic)];

    [self showMessage:@"Caricamento Lovelace..."];
}

// NineHA.DarkLovelaceBar
// NineHA.Adaptive7B

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = self.tableView.bounds.size.width;

    if (width < 250 ||
        fabs(width - self.ninehaLastLayoutWidth) < 5.0)
        return;

    self.ninehaLastLayoutWidth = width;

    if (!self.started || !self.views.count)
        return;

    [NSObject cancelPreviousPerformRequestsWithTarget:self
        selector:@selector(ninehaApplyResponsiveLayout)
        object:nil];

    [self performSelector:
        @selector(ninehaApplyResponsiveLayout)
               withObject:nil
               afterDelay:0.18];
}

- (void)ninehaApplyResponsiveLayout {

    if (!self.isViewLoaded ||
        !self.view.window ||
        !self.views.count)
        return;

    CGFloat previousY =
        self.tableView.contentOffset.y;

    self.ninehaRelayoutOnly = YES;

    [self rebuildRows];

    self.ninehaRelayoutOnly = NO;

    [self.tableView layoutIfNeeded];

    CGFloat low =
        -self.tableView.contentInset.top;

    CGFloat high = MAX(
        low,
        self.tableView.contentSize.height -
        self.tableView.bounds.size.height +
        self.tableView.contentInset.bottom
    );

    CGFloat position =
        MAX(low, MIN(previousY, high));

    [self.tableView setContentOffset:
        CGPointMake(0, position)
                        animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UINavigationBar *bar =
        self.navigationController.navigationBar;

    bar.barStyle = UIBarStyleBlack;
    bar.barTintColor = [UIColor blackColor];
    bar.tintColor = [UIColor whiteColor];
    bar.translucent = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.started) {
        self.started = YES;
        [self loadDashboardList];
    }

    [self fetchStates];

    // Applichiamo la frequenza salvata per il server.
    [self configureEntityRefreshTimer];
    [self configureClockTimer];
    [self configureWeatherRefreshTimer];
    [self configureLiveUpdates];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [NSObject cancelPreviousPerformRequestsWithTarget:self
        selector:@selector(ninehaApplyResponsiveLayout)
        object:nil];

    UINavigationBar *bar =
        self.navigationController.navigationBar;

    bar.barStyle = UIBarStyleDefault;
    bar.barTintColor = nil;
    bar.tintColor = nil;
    bar.translucent = YES;


    [self.timer invalidate];
    self.timer = nil;

    [self.clockTimer invalidate];
    self.clockTimer = nil;

    [self.weatherTimer invalidate];
    self.weatherTimer = nil;
    [self stopLiveUpdates];
    [self.actionEngine cancel];

    self.weatherGeneration++;
    self.weatherInFlight = NO;

    self.generation++;

    [self.loader cancel];
    self.loader = nil;

    [self.session invalidateAndCancel];
    self.session = nil;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)showMessage:(NSString *)message {
    self.rows = @[@{
        @"kind": @"message",
        @"title": message ?: @""
    }];
    [self.tableView reloadData];
}

- (void)showError:(NSString *)message {
    [self showMessage:message];

    NSLog(@"NineHA Lovelace: %@", message);
}

- (void)withToken:(NineAuthCompletion)completion {
    if ([self.mode isEqualToString:@"oauth"]) {
        [self.auth useOAuthToken:completion];
    } else {
        [self.auth useManualToken:completion];
    }
}

- (NSString *)selectionKey {
    return [@"NineHA.LovelaceSelection."
        stringByAppendingString:self.auth.serverURL ?: @""];
}

#pragma mark - Lovelace WebSocket

- (void)requestList:(BOOL)list {
    NSUInteger generation = ++self.generation;

    [self.loader cancel];
    self.loader = nil;

    [self withToken:^(NSString *token, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation ||
                !self.view.window) return;

            if (error || !token.length) {
                [self showError:@"Token non disponibile"];
                return;
            }

            NineLovelaceLoader *loader =
                [[NineLovelaceLoader alloc]
                    initWithServerURL:self.auth.serverURL
                               token:token];

            self.loader = loader;

            NineLovelaceCompletion done =
                ^(id result, NSError *loadError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation != self.generation ||
                        !self.view.window) return;

                    self.loader = nil;

                    if (loadError) {
                        [self showError:
                            loadError.localizedDescription];
                        return;
                    }

                    if (list) {
                        [self receivedDashboardList:result];
                    } else {
                        [self receivedConfiguration:result];
                    }
                });
            };

            if (list) {
                [loader loadDashboardsWithCompletion:done];
            } else {
                [loader loadConfigurationForPath:
                    self.dashboardPath completion:done];
            }
        });
    }];
}

- (void)loadDashboardList {
    [self showMessage:@"Lettura dashboard..."];
    [self requestList:YES];
}

- (void)reloadConfiguration {
    [self showMessage:@"Aggiornamento Lovelace..."];
    [self requestList:NO];
    [self fetchStates];
}

- (void)receivedDashboardList:(id)result {
    self.dashboards = NHAArray(result);

    NSString *saved = [[NSUserDefaults standardUserDefaults]
        stringForKey:[self selectionKey]];

    if (saved.length) {
        self.dashboardPath = saved;
    } else {
        self.dashboardPath = @"lovelace";
    }

    [self requestList:NO];
}

- (void)receivedConfiguration:(id)result {
    NSDictionary *config = NHADict(result);

    self.views = NHAArray(config[@"views"]);
    self.selectedView = 0;

    NSUserDefaults *prefs =
        [NSUserDefaults standardUserDefaults];

    NSString *key = [self ninehaViewKey];

    NSString *savedPath =
        [prefs stringForKey:key];

    NSInteger savedIndex =
        [prefs integerForKey:
            [key stringByAppendingString:@".index"]];

    BOOL found = NO;

    for (NSUInteger i = 0; i < self.views.count; i++) {
        NSString *path =
            NHAString(NHADict(self.views[i])[@"path"]);

        if (savedPath.length &&
            [path isEqualToString:savedPath]) {
            self.selectedView = i;
            found = YES;
            break;
        }
    }

    if (!found &&
        savedIndex >= 0 &&
        savedIndex < (NSInteger)self.views.count) {
        self.selectedView = savedIndex;
    }

    if (!self.views.count) {
        [self showMessage:
            @"Dashboard senza viste statiche supportate."];
        return;
    }

    [self rebuildTabs];
    [self rebuildRows];

    if (self.chooseViewAfterLoading) {
        self.chooseViewAfterLoading = NO;

        [self performSelector:@selector(ninehaShowViews)
                   withObject:nil
                   afterDelay:0.3];
    }
}

#pragma mark - Dashboard selection


- (NSString *)ninehaViewKey {
    return [NSString stringWithFormat:
        @"NineHA.LovelaceView.%@|%@",
        self.auth.serverURL ?: @"",
        self.dashboardPath ?: @"lovelace"];
}

- (void)ninehaOpenClassic {
    for (UIViewController *vc in
         [self.navigationController.viewControllers
             reverseObjectEnumerator]) {

        if (vc != self &&
            [vc isKindOfClass:
                [NineTilesController class]]) {

            [self.navigationController
                popToViewController:vc animated:YES];
            return;
        }
    }

    NineTilesController *classic =
        [[NineTilesController alloc]
            initWithAuth:self.auth mode:self.mode];

    [self.navigationController
        pushViewController:classic animated:YES];
}

- (void)ninehaSelectViewIndex:(NSInteger)index {
    if (index < 0 ||
        index >= (NSInteger)self.views.count) {
        return;
    }

    self.selectedView = index;

    NSString *key = [self ninehaViewKey];

    NSUserDefaults *prefs =
        [NSUserDefaults standardUserDefaults];

    NSString *path =
        NHAString(NHADict(self.views[index])[@"path"]);

    if (path.length) {
        [prefs setObject:path forKey:key];
    } else {
        [prefs removeObjectForKey:key];
    }

    [prefs setInteger:index
               forKey:
        [key stringByAppendingString:@".index"]];

    [self rebuildTabs];
    [self rebuildRows];

    [self.tableView setContentOffset:
        CGPointMake(0, -self.tableView.contentInset.top)
                            animated:NO];
}

- (void)ninehaShowViews {
    if (!self.view.window || !self.views.count) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"Vista Lovelace"
                         message:@"Mostra una sola vista"
                  preferredStyle:
                    UIAlertControllerStyleActionSheet];

    for (NSUInteger i = 0; i < self.views.count; i++) {

        NSString *name =
            NHAString(
                NHADict(self.views[i])[@"title"])
            ?: @"Vista";

        NSString *label = [NSString stringWithFormat:
            @"%@%lu · %@",
            i == (NSUInteger)self.selectedView
                ? @"✓ " : @"",
            (unsigned long)(i + 1),
            name];

        [sheet addAction:
            [UIAlertAction
                actionWithTitle:label
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {

            [self ninehaSelectViewIndex:(NSInteger)i];
        }]];
    }

    [sheet addAction:
        [UIAlertAction
            actionWithTitle:@"Annulla"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem =
            self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:sheet
                       animated:YES
                     completion:nil];
}

- (void)chooseDashboard {
    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:@"Dashboard Home Assistant"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    for (id item in self.dashboards) {
        NSDictionary *dashboard = NHADict(item);

        NSString *title =
            NHAString(dashboard[@"title"]) ?: @"Dashboard";

        NSString *path =
            NHAString(dashboard[@"url_path"]) ?: @"lovelace";

        [menu addAction:[UIAlertAction
            actionWithTitle:title
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
            self.dashboardPath = path;
            self.chooseViewAfterLoading = YES;

            [[NSUserDefaults standardUserDefaults]
                setObject:path forKey:[self selectionKey]];

            [self reloadConfiguration];
        }]];
    }

    [menu addAction:[UIAlertAction
        actionWithTitle:@"Scegli vista della dashboard attuale…"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        [self performSelector:@selector(ninehaShowViews)
                   withObject:nil
                   afterDelay:0.3];
    }]];


    NSString *selected =
        [NineUnstableSettingsController
            startupModeForServerURL:self.auth.serverURL];

    NSArray *startupModes = @[
        @{@"id": @"native",
          @"title": @"NineHA nativa"},
        @{@"id": @"rebuilder",
          @"title": @"Lovelace Rebuilder"},
        @{@"id": @"original",
          @"title": @"Lovelace originale (unstable)"}
    ];

    for (NSDictionary *option in startupModes) {
        BOOL active = [selected isEqualToString:option[@"id"]];

        NSString *title = [NSString stringWithFormat:
            @"Avvio: %@%@",
            active ? @"✓ " : @"",
            option[@"title"]];

        [menu addAction:[UIAlertAction
            actionWithTitle:title
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {

            [NineUnstableSettingsController
                setStartupMode:option[@"id"]
                     serverURL:self.auth.serverURL];
        }]];
    }

    [menu addAction:[UIAlertAction
        actionWithTitle:@"Annulla"
                  style:UIAlertActionStyleCancel
                handler:nil]];

    UIPopoverPresentationController *popover =
        menu.popoverPresentationController;

    if (popover) {
        popover.barButtonItem =
            self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:menu
                       animated:YES
                     completion:nil];
}

#pragma mark - View tabs

- (void)rebuildTabs {
    if (self.selectedView >= 0 &&
        self.selectedView < (NSInteger)self.views.count) {

        self.title =
            NHAString(NHADict(
                self.views[self.selectedView])[@"title"])
            ?: @"Lovelace";
    }
}

- (void)selectView:(UIButton *)sender {
    [self ninehaSelectViewIndex:sender.tag];
}


#pragma mark - Native Lovelace conditional cards

- (BOOL)ninehaReadNumber:(id)value
                  result:(double *)result {

    NSString *text = nil;

    if ([value isKindOfClass:[NSString class]]) {
        text = value;

    } else if ([value isKindOfClass:[NSNumber class]]) {
        text = [value stringValue];
    }

    if (!text.length) return NO;

    NSScanner *scanner =
        [NSScanner scannerWithString:text];

    scanner.locale =
        [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    double number = 0;

    if (![scanner scanDouble:&number] ||
        ![scanner isAtEnd]) {
        return NO;
    }

    if (result) *result = number;

    return YES;
}

- (BOOL)ninehaConditionalMatches:
    (NSDictionary *)configuration {

    NSArray *conditions =
        NHAArray(configuration[@"conditions"]);

    // Nessuna condizione valida: fail closed.
    if (!conditions.count) return NO;

    for (id object in conditions) {
        NSDictionary *condition = NHADict(object);

        NSString *type =
            NHAString(condition[@"condition"]) ?: @"state";

        NSString *entity =
            NHAString(condition[@"entity"]);

        if (!entity.length) return NO;

        NSDictionary *record =
            NHADict(self.states[entity]);

        NSString *current =
            NHAString(record[@"state"]);

        // Non rendiamo visibile una scheda quando
        // lo stato non è ancora disponibile.
        if (!current.length ||
            [current isEqualToString:@"unknown"] ||
            [current isEqualToString:@"unavailable"]) {
            return NO;
        }

        if ([type isEqualToString:@"state"]) {
            NSString *expected =
                NHAString(condition[@"state"]);

            NSString *excluded =
                NHAString(condition[@"state_not"]);

            if (!expected.length && !excluded.length)
                return NO;

            if (expected.length &&
                ![current isEqualToString:expected])
                return NO;

            if (excluded.length &&
                [current isEqualToString:excluded])
                return NO;

        } else if ([type isEqualToString:@"numeric_state"]) {

            NSString *attribute =
                NHAString(condition[@"attribute"]);

            id rawValue = attribute.length
                ? NHADict(record[@"attributes"])[attribute]
                : current;

            double value = 0;

            if (![self ninehaReadNumber:rawValue
                                result:&value])
                return NO;

            id above = condition[@"above"];
            id below = condition[@"below"];

            BOOL hasAbove =
                above && above != [NSNull null];

            BOOL hasBelow =
                below && below != [NSNull null];

            if (!hasAbove && !hasBelow)
                return NO;

            double threshold = 0;

            if (hasAbove) {
                if (![self ninehaReadNumber:above
                                    result:&threshold])
                    return NO;

                if (!(value > threshold))
                    return NO;
            }

            if (hasBelow) {
                if (![self ninehaReadNumber:below
                                    result:&threshold])
                    return NO;

                if (!(value < threshold))
                    return NO;
            }

        } else {
            // Altre condizioni non ancora implementate.
            return NO;
        }
    }

    return YES;
}

- (void)ninehaCollectConditionalDependencies:(id)object
                                       into:(NSMutableSet *)result
                                      depth:(NSInteger)depth {

    if (depth > 16) return;

    NSDictionary *node = NHADict(object);

    if (!node.count) return;

    NSString *type = NHAString(node[@"type"]);

    if ([type isEqualToString:@"conditional"]) {
        for (id item in NHAArray(node[@"conditions"])) {
            NSString *entity =
                NHAString(NHADict(item)[@"entity"]);

            if (entity.length)
                [result addObject:entity];
        }
    }

    for (id child in NHAArray(node[@"cards"])) {
        [self ninehaCollectConditionalDependencies:child
                                              into:result
                                             depth:depth+1];
    }

    for (id section in NHAArray(node[@"sections"])) {
        [self ninehaCollectConditionalDependencies:section
                                              into:result
                                             depth:depth+1];
    }

    if ([node[@"card"] isKindOfClass:
            [NSDictionary class]]) {

        [self ninehaCollectConditionalDependencies:
            node[@"card"]
                                              into:result
                                             depth:depth+1];
    }
}

- (NSSet *)ninehaConditionalEntityIDs {

    if (self.selectedView < 0 ||
        self.selectedView >= (NSInteger)self.views.count) {
        return [NSSet set];
    }

    NSMutableSet *result = [NSMutableSet set];

    [self ninehaCollectConditionalDependencies:
        self.views[self.selectedView]
                                          into:result
                                         depth:0];

    return [result copy];
}

#pragma mark - Native card builder

- (void)addCard:(id)object
         toRows:(NSMutableArray *)rows
          depth:(NSInteger)depth {

    if (depth > 8 || rows.count >= 300) return;

    NSDictionary *card = NHADict(object);
    if (!card.count) return;

    NSString *type =
        NHAString(card[@"type"]) ?: @"entity";

    if ([type isEqualToString:@"conditional"]) {

        if ([self ninehaConditionalMatches:card]) {

            NSDictionary *child =
                NHADict(card[@"card"]);

            if (child.count) {
                [self addCard:child
                      toRows:rows
                       depth:depth+1];
            }
        }

        return;
    }

    BOOL containerCard =
        [type isEqualToString:@"grid"] ||
        [type isEqualToString:@"horizontal-stack"] ||
        [type isEqualToString:@"vertical-stack"] ||
        [type isEqualToString:@"custom:layout-card"] ||
        [type isEqualToString:@"custom:stack-in-card"] ||
        [type isEqualToString:
            @"custom:vertical-stack-in-card"] ||
        [type isEqualToString:
            @"custom:horizontal-stack-in-card"] ||
        [type isEqualToString:@"custom:mod-card"];

    if (containerCard) {

        for (id child in NHAArray(card[@"cards"])) {
            [self addCard:child
                   toRows:rows
                    depth:depth+1];
        }

        NSDictionary *single =
            NHADict(card[@"card"]);

        if (single.count) {
            [self addCard:single
                   toRows:rows
                    depth:depth+1];
        }

        return;
    }

    // NineHA.ProgressBridge8D
    // Entity Progress Card conserva entità, azioni
    // e configurazione per il renderer UIKit.
    if ([type isEqualToString:
            @"custom:entity-progress-card"]) {

        NSString *progressEntity =
            NHAString(card[@"entity"]);

        if (progressEntity.length) {

            NSString *progressTitle =
                NHAString(card[@"name"])
                ?: NHAString(card[@"title"])
                ?: @"";

            if ([progressTitle containsString:@"{{"] ||
                [progressTitle containsString:@"[[["]) {
                progressTitle = @"";
            }

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": progressEntity,
                @"title": progressTitle,
                @"action_card": card,
                @"nine_plugin_type":
                    @"custom:entity-progress-card",
                @"nine_progress": @YES,
                @"progress_config": card
            }];

        } else {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title":
                    @"Entity Progress senza entità"
            }];
        }

        return;
    }

    // NineHA.BubbleBridge8C
    // Bubble Card viene ricostruita con una entità
    // principale e fasce native per i sub_button.
    if ([type isEqualToString:@"custom:bubble-card"]) {

        NSString *bubbleEntity =
            NHAString(card[@"entity"]);

        BOOL addedBubbleItem = NO;

        if (bubbleEntity.length) {

            NSString *bubbleTitle =
                NHAString(card[@"name"])
                ?: NHAString(card[@"title"])
                ?: @"";

            if ([bubbleTitle containsString:@"{{"] ||
                [bubbleTitle containsString:@"[[["]) {
                bubbleTitle = @"";
            }

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": bubbleEntity,
                @"title": bubbleTitle,
                @"action_card": card,
                @"nine_plugin_type":
                    @"custom:bubble-card"
            }];

            addedBubbleItem = YES;
        }

        NSMutableArray *bubbleSubItems =
            [NSMutableArray array];

        for (id object in
            NHAArray(card[@"sub_button"])) {

            NSDictionary *subButton =
                NHADict(object);

            NSString *subEntity =
                NHAString(subButton[@"entity"])
                ?: NHAString(subButton[@"entity_id"]);

            if (!subEntity.length)
                continue;

            NSString *subTitle =
                NHAString(subButton[@"name"])
                ?: NHAString(subButton[@"title"])
                ?: @"";

            if ([subTitle containsString:@"{{"] ||
                [subTitle containsString:@"[[["]) {
                subTitle = @"";
            }

            [bubbleSubItems addObject:@{
                @"kind": @"entity",
                @"entity": subEntity,
                @"title": subTitle,
                @"action_card": subButton,
                @"nine_plugin_type":
                    @"custom:bubble-sub-button"
            }];

            addedBubbleItem = YES;

            if (bubbleSubItems.count == 3) {
                [rows addObject:@{
                    @"kind": @"layout-band",
                    @"cells": [bubbleSubItems copy],
                    @"spans": @[@4, @4, @4]
                }];

                [bubbleSubItems removeAllObjects];
            }
        }

        if (bubbleSubItems.count) {

            NSMutableArray *tailSpans =
                [NSMutableArray array];

            for (NSUInteger index = 0;
                 index < bubbleSubItems.count;
                 index++) {
                [tailSpans addObject:@4];
            }

            [rows addObject:@{
                @"kind": @"layout-band",
                @"cells": [bubbleSubItems copy],
                @"spans": [tailSpans copy]
            }];
        }

        if (!addedBubbleItem) {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title":
                    @"Bubble Card senza entità native"
            }];
        }

        return;
    }

    // NineHA.PluginBridge8A
    // Mushroom Title diventa una heading UIKit.
    if ([type isEqualToString:
            @"custom:mushroom-title-card"]) {

        NSString *title =
            NHAString(card[@"title"])
            ?: NHAString(card[@"subtitle"])
            ?: @"Sezione";

        if ([title containsString:@"{{"])
            title = @"Sezione";

        [rows addObject:@{
            @"kind": @"heading",
            @"title": title
        }];

        return;
    }

    // I chip associati a entità diventano normali
    // elementi UIKit. Chip di navigazione o template
    // privi di entity vengono ignorati in sicurezza.
    if ([type isEqualToString:
            @"custom:mushroom-chips-card"]) {

        NSUInteger added = 0;

        for (id object in NHAArray(card[@"chips"])) {

            NSDictionary *chip =
                NHADict(object);

            NSString *entity =
                NHAString(chip[@"entity"]);

            if (!entity.length)
                continue;

            NSString *title =
                NHAString(chip[@"content"])
                ?: NHAString(chip[@"name"])
                ?: @"";

            if ([title containsString:@"{{"])
                title = @"";

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": entity,
                @"title": title,
                @"action_card": chip
            }];

            added++;
        }

        if (!added) {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title":
                    @"Mushroom Chips senza entità native"
            }];
        }

        return;
    }

    // NineHA.MushroomMedia7D4
    // Adattatore grafico per Mushroom media-player.
    // Le azioni originali restano nella action_card.
    if ([type isEqualToString:
            @"custom:mushroom-media-player-card"]) {

        NSString *entity =
            NHAString(card[@"entity"]);

        if (entity.length) {
            NSString *title =
                NHAString(card[@"name"])
                ?: NHAString(card[@"primary"])
                ?: @"";

            if ([title containsString:@"{{"])
                title = @"";

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": entity,
                @"title": title,
                @"action_card": card
            }];

        } else {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title": @"Mushroom media-player senza entità"
            }];
        }

        return;
    }

    if ([type isEqualToString:@"custom:mushroom-template-card"]) {
        NSString *entity = NHAString(card[@"entity"]);
        NSString *secondary =
            NHAString(card[@"secondary"]) ?: @"";

        if (NINEHA_NAS_SWITCH_ENTITY.length &&
            NINEHA_NAS_STATUS_ENTITY.length &&
            NINEHA_NAS_VM_STATUS_ENTITY.length &&
            [entity isEqualToString:
                NINEHA_NAS_SWITCH_ENTITY] &&
            [secondary containsString:
                NINEHA_NAS_STATUS_ENTITY] &&
            [secondary containsString:
                NINEHA_NAS_VM_STATUS_ENTITY]) {

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": entity,
                @"title": NHAString(card[@"primary"]) ?: @"NAS",
                @"nine_adapter": @"nas_vm",
                @"action_card": card,
                @"dependencies": @[
                    NINEHA_NAS_STATUS_ENTITY,
                    NINEHA_NAS_VM_STATUS_ENTITY
                ]
            }];

        } else if (entity.length) {

            NSString *title =
                NHAString(card[@"primary"]) ?: @"";

            if ([title containsString:@"{{"])
                title = @"";

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": entity,
                @"title": title,
                @"action_card": card
            }];

        } else {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title": @"custom:mushroom-template-card"
            }];
        }

        return;
    }

    if ([type isEqualToString:@"entities"]) {
        NSString *heading = NHAString(card[@"title"]);

        if (heading.length) {
            [rows addObject:@{
                @"kind": @"heading",
                @"title": heading
            }];
        }

        for (id item in NHAArray(card[@"entities"])) {
            NSString *entity = nil;
            NSString *title = nil;

            if ([item isKindOfClass:[NSString class]]) {
                entity = item;
            } else {
                NSDictionary *entry = NHADict(item);

                if ([NHAString(entry[@"type"])
                        isEqualToString:@"custom:mushroom-template-card"]) {
                    [self addCard:entry toRows:rows depth:depth+1];
                    continue;
                }

                entity = NHAString(entry[@"entity"]);
                title = NHAString(entry[@"name"]);
            }

            if (!entity.length) continue;

            NSMutableDictionary *row = [@{
                @"kind": @"entity",
                @"entity": entity,
                @"title": title ?: @""
            } mutableCopy];

            if ([item isKindOfClass:[NSDictionary class]]) {
                row[@"action_card"] = item;
            } else {
                row[@"action_card"] = @{
                    @"type": @"entity",
                    @"entity": entity
                };
            }

            [rows addObject:row];
        }

        return;
    }


    // NineHA.MediaControl8F
    // Adattatore UIKit in sola lettura per la
    // card Home Assistant media-control.
    if ([type isEqualToString:@"media-control"]) {

        NSString *mediaEntity =
            NHAString(card[@"entity"]);

        if (mediaEntity.length) {

            NSString *mediaTitle =
                NHAString(card[@"name"])
                ?: NHAString(card[@"title"])
                ?: @"";

            if ([mediaTitle containsString:@"{{"] ||
                [mediaTitle containsString:@"[[["]) {
                mediaTitle = @"";
            }

            [rows addObject:@{
                @"kind": @"entity",
                @"entity": mediaEntity,
                @"title": mediaTitle,
                @"action_card": card,
                @"nine_media_control": @YES
            }];

        } else {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title":
                    @"Media Control senza entità"
            }];
        }

        return;
    }

    if ([type isEqualToString:@"clock"]) {
        [rows addObject:@{
            @"kind": @"clock",
            @"config": card
        }];
        return;
    }

    if ([type isEqualToString:@"weather-forecast"]) {
        NSString *weatherID = NHAString(card[@"entity"]);

        if (weatherID.length) {
            [rows addObject:@{
                @"kind": @"weather",
                @"entity": weatherID,
                @"config": card
            }];
        } else {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title": @"weather: entità non specificata"
            }];
        }
        return;
    }

    if ([type isEqualToString:@"heading"]) {
        [rows addObject:@{
            @"kind": @"heading",
            @"title": NHAString(card[@"heading"]) ?:
                      NHAString(card[@"title"]) ?: @"Sezione"
        }];
        return;
    }

    BOOL customType =
        [type hasPrefix:@"custom:"];

    NSArray *pluginEntities =
        NHAArray(card[@"entities"]);

    if (customType && pluginEntities.count) {

        NSString *heading =
            NHAString(card[@"title"])
            ?: NHAString(card[@"name"]);

        if (heading.length &&
            ![heading containsString:@"{{"] &&
            ![heading containsString:@"[[["]) {

            [rows addObject:@{
                @"kind": @"heading",
                @"title": heading
            }];
        }

        NSUInteger added = 0;

        for (id object in pluginEntities) {

            NSString *pluginEntity = nil;
            NSString *pluginTitle = nil;
            NSDictionary *configuration = nil;

            if ([object isKindOfClass:
                    [NSString class]]) {

                pluginEntity = object;

            } else {
                configuration =
                    NHADict(object);

                pluginEntity =
                    NHAString(configuration[@"entity"])
                    ?: NHAString(
                        configuration[@"entity_id"]);

                pluginTitle =
                    NHAString(configuration[@"name"]);
            }

            if (!pluginEntity.length)
                continue;

            NSMutableDictionary *row =
                [@{
                    @"kind": @"entity",
                    @"entity": pluginEntity,
                    @"title": pluginTitle ?: @""
                } mutableCopy];

            if (configuration.count)
                row[@"action_card"] = configuration;

            [rows addObject:row];
            added++;
        }

        if (!added) {
            [rows addObject:@{
                @"kind": @"unsupported",
                @"title": type
            }];
        }

        return;
    }

    NSSet *supported = [NSSet setWithArray:@[
        @"tile", @"entity", @"button", @"sensor"
    ]];

    NSString *entity = NHAString(card[@"entity"]);

    if ([supported containsObject:type] && entity.length) {
        [rows addObject:@{
            @"kind": @"entity",
            @"entity": entity,
            @"title": NHAString(card[@"name"]) ?: @"",
            @"action_card": card
        }];
        return;
    }

    // Qualsiasi custom card che dichiara una normale
    // entity può essere rappresentata senza eseguire
    // il relativo componente JavaScript.
    if (customType && entity.length) {

        NSString *title =
            NHAString(card[@"name"])
            ?: NHAString(card[@"primary"])
            ?: NHAString(card[@"title"])
            ?: @"";

        if ([title containsString:@"{{"] ||
            [title containsString:@"[[["]) {
            title = @"";
        }

        [rows addObject:@{
            @"kind": @"entity",
            @"entity": entity,
            @"title": title,
            @"action_card": card,
            @"nine_plugin_type": type
        }];

        return;
    }

    // Plugin non riconosciuti e privi di entity
    // rimangono visibili come placeholder.
    [rows addObject:@{
        @"kind": @"unsupported",
        @"title": type
    }];
}



#pragma mark - Configurable NAS native adapter

- (NSInteger)ninehaNASLevel {
    if (!NINEHA_NAS_STATUS_ENTITY.length ||
        !NINEHA_NAS_VM_STATUS_ENTITY.length) {
        return -1;
    }

    NSString *nas = NHAString(
        NHADict(self.states[
            NINEHA_NAS_STATUS_ENTITY])[@"state"]);

    NSString *vm = NHAString(
        NHADict(self.states[
            NINEHA_NAS_VM_STATUS_ENTITY])[@"state"]);

    if ([nas isEqualToString:@"on"]) return 2;
    if ([vm isEqualToString:@"on"]) return 1;

    if ([nas isEqualToString:@"off"] &&
        [vm isEqualToString:@"off"]) return 0;

    return -1;
}

- (NSString *)ninehaNASStatus {
    NSInteger level = [self ninehaNASLevel];

    if (level == 2) return @"Online";
    if (level == 1) return @"VM attiva…";
    if (level == 0) return @"Spento";

    return @"Stato non disponibile";
}

- (UIColor *)ninehaNASColor {
    NSInteger level = [self ninehaNASLevel];

    if (level == 2)
        return [UIColor colorWithRed:.30
                              green:.85
                               blue:.48
                              alpha:1];

    if (level == 1)
        return [UIColor colorWithRed:1
                              green:.72
                               blue:.23
                              alpha:1];

    if (level == 0)
        return [UIColor colorWithRed:.93
                              green:.36
                               blue:.37
                              alpha:1];

    return [UIColor colorWithWhite:.65 alpha:1];
}

#pragma mark - Native layout engine 4A

- (void)ninehaLayoutBandForItems:(NSArray *)items
                         spans:(NSArray *)spans
                        toRows:(NSMutableArray *)output {

    if (!items.count) return;

    [output addObject:@{
        @"kind": @"layout-band",
        @"cells": [items copy],
        @"spans": [spans copy]
    }];
}

- (NSInteger)ninehaColumnsForContainer:
    (NSDictionary *)card {

    NSString *type = NHAString(card[@"type"]) ?: @"";
    NSInteger columns = 1;

    if ([type isEqualToString:@"grid"]) {
        columns =
            [card[@"columns"] respondsToSelector:
                @selector(integerValue)]
            ? [card[@"columns"] integerValue] : 3;

    } else if ([type isEqualToString:@"horizontal-stack"]) {
        columns = NHAArray(card[@"cards"]).count;

    } else if ([type isEqualToString:@"custom:layout-card"]) {
        NSString *grid =
            NHAString(NHADict(card[@"layout"])[
                @"grid-template-columns"]);

        if (grid.length) {
            NSRegularExpression *pattern =
                [NSRegularExpression
                    regularExpressionWithPattern:
                        @"repeat\\(\\s*([0-9]+)\\s*,"
                    options:0
                    error:nil];

            NSTextCheckingResult *match =
                [pattern firstMatchInString:grid
                    options:0
                    range:NSMakeRange(0, grid.length)];

            if (match &&
                [match rangeAtIndex:1].location
                    != NSNotFound) {

                columns =
                    [[grid substringWithRange:
                        [match rangeAtIndex:1]]
                            integerValue];
            }
        }
    }

    // Le griglie annidate dipendono dalla
    // larghezza della propria colonna, non
    // dalla larghezza totale dell'iPad.

    CGFloat available =
        self.ninehaBuildingColumnWidth > 50
        ? self.ninehaBuildingColumnWidth
        : self.tableView.bounds.size.width - 20;

    NSArray *containerCards =
        NHAArray(card[@"cards"]);

    BOOL gridContainer =
        [type isEqualToString:@"grid"] ||
        [type isEqualToString:@"custom:layout-card"];

    BOOL threeColumnSensorGrid =
        UI_USER_INTERFACE_IDIOM() ==
            UIUserInterfaceIdiomPad &&
        gridContainer &&
        columns == 3 &&
        containerCards.count >= 3;

    if (threeColumnSensorGrid) {
        for (id object in containerCards) {
            NSString *sensorEntity =
                NHAString(NHADict(object)[@"entity"]);

            if (![sensorEntity hasPrefix:@"sensor."]) {
                threeColumnSensorGrid = NO;
                break;
            }
        }
    }

    // Tutte le griglie di soli sensori configurate
    // a tre colonne restano su tre colonne, anche
    // quando contengono molte righe.
    CGFloat minimumItemWidth =
        threeColumnSensorGrid ? 88.0 : 118.0;

    NSInteger fitting =
        (NSInteger)floor(
            (available + 8) /
            (minimumItemWidth + 8)
        );

    return MAX(
        1,
        MIN(3, MIN(columns, MAX(1, fitting)))
    );
}

- (void)ninehaAppendContainer:(NSDictionary *)card
                        toRows:(NSMutableArray *)rows {

    NSArray *cards = NHAArray(card[@"cards"]);

    NSInteger columns =
        [self ninehaColumnsForContainer:card];

    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *spans = [NSMutableArray array];

    for (id child in cards) {

        NSMutableArray *leaves =
            [NSMutableArray array];

        [self addCard:child
              toRows:leaves
               depth:1];

        for (NSDictionary *leaf in leaves) {

            if ([leaf[@"kind"]
                    isEqualToString:@"heading"]) {

                [self ninehaLayoutBandForItems:items
                    spans:spans toRows:rows];

                [items removeAllObjects];
                [spans removeAllObjects];

                [rows addObject:leaf];
                continue;
            }

            [items addObject:leaf];
            [spans addObject:@(12 / columns)];

            if (items.count >= (NSUInteger)columns) {
                [self ninehaLayoutBandForItems:items
                    spans:spans toRows:rows];

                [items removeAllObjects];
                [spans removeAllObjects];
            }
        }
    }

    [self ninehaLayoutBandForItems:items
        spans:spans toRows:rows];
}

- (void)ninehaAppendSection:(NSArray *)cards
                     toRows:(NSMutableArray *)rows {

    NSMutableArray *halves =
        [NSMutableArray array];

    for (id object in cards) {

        NSDictionary *card = NHADict(object);

        NSMutableArray *leaves =
            [NSMutableArray array];

        [self addCard:object
              toRows:leaves
               depth:0];

        id configuredColumns =
            NHADict(card[@"grid_options"])[@"columns"];

        NSInteger span =
            [configuredColumns
                respondsToSelector:@selector(integerValue)]
            ? [configuredColumns integerValue] : 12;

        BOOL half =
            span == 6 &&
            leaves.count == 1 &&
            ![leaves[0][@"kind"]
                isEqualToString:@"heading"];

        if (!half) {

            if (halves.count) {
                [self ninehaLayoutBandForItems:halves
                    spans:@[@6] toRows:rows];

                [halves removeAllObjects];
            }

            if (leaves.count == 1 &&
                ![leaves[0][@"kind"]
                    isEqualToString:@"heading"]) {

                [self ninehaLayoutBandForItems:leaves
                    spans:@[@12] toRows:rows];

            } else {
                [rows addObjectsFromArray:leaves];
            }

            continue;
        }

        [halves addObject:leaves[0]];

        if (halves.count == 2) {
            [self ninehaLayoutBandForItems:halves
                spans:@[@6, @6] toRows:rows];

            [halves removeAllObjects];
        }
    }

    if (halves.count) {
        [self ninehaLayoutBandForItems:halves
            spans:@[@6] toRows:rows];
    }
}

- (BOOL)ninehaRow:(id)value
   containsEntity:(NSString *)entity
             kind:(NSString *)kind {

    NSDictionary *row = NHADict(value);

    if ([row[@"kind"] isEqualToString:kind] &&
        ([row[@"entity"] isEqual:entity] ||
         [NHAArray(row[@"dependencies"]) containsObject:entity])) {
        return YES;
    }

    for (id child in NHAArray(row[@"cells"])) {
        if ([self ninehaRow:child
            containsEntity:entity kind:kind]) {
            return YES;
        }
    }

    for (id column in NHAArray(row[@"columns"])) {
        for (id block in NHAArray(column)) {
            if ([self ninehaRow:block
                containsEntity:entity kind:kind]) {
                return YES;
            }
        }
    }

    return NO;
}

// NineHA.SensorGrid7D5
// Riconosce ogni riga appartenente a una griglia
// di sensori su tre colonne. La riga finale può
// contenere anche soltanto uno o due elementi.
- (BOOL)ninehaIsThreeSensorBand:(NSDictionary *)band {

    if (![band[@"kind"] isEqualToString:@"layout-band"])
        return NO;

    NSArray *cells = NHAArray(band[@"cells"]);
    NSArray *spans = NHAArray(band[@"spans"]);

    if (cells.count < 1 ||
        cells.count > 3 ||
        spans.count != cells.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < cells.count; i++) {

        NSDictionary *cell = NHADict(cells[i]);
        NSString *entity = NHAString(cell[@"entity"]);

        if (![cell[@"kind"] isEqualToString:@"entity"] ||
            ![entity hasPrefix:@"sensor."] ||
            [spans[i] integerValue] != 4) {
            return NO;
        }
    }

    return YES;
}

- (UITableViewCell *)ninehaLayoutCell:
    (UITableView *)table
                                 row:(NSDictionary *)row {

    static NSString *reuse = @"NineLayoutBand";

    UITableViewCell *cell =
        [table dequeueReusableCellWithIdentifier:reuse];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleDefault
          reuseIdentifier:reuse];
    }

    cell.selectionStyle =
        UITableViewCellSelectionStyleNone;

    cell.backgroundColor = [UIColor blackColor];

    for (UIView *old in [cell.contentView.subviews copy]) {
        [old removeFromSuperview];
    }

    NSArray *items = NHAArray(row[@"cells"]);
    NSArray *spans = NHAArray(row[@"spans"]);

    CGFloat available =
        MAX(200, table.bounds.size.width - 20);

    CGFloat unit = (available - 16) / 12.0;
    CGFloat x = 10;

    BOOL compactSensorBand =
        [self ninehaIsThreeSensorBand:row];

    CGFloat height =
        compactSensorBand ? 76 : 94;

    for (NSDictionary *item in items) {
        NSString *kind =
            NHAString(item[@"kind"]) ?: @"";

        if ([kind isEqualToString:@"clock"])
            height = MAX(height, 120);

        if ([kind isEqualToString:@"weather"])
            height = MAX(height, 105);
    }

    for (NSUInteger i = 0; i < items.count; i++) {

        NSDictionary *item = NHADict(items[i]);

        NSInteger span = i < spans.count
            ? [spans[i] integerValue] : 12;

        CGFloat width =
            MAX(55, unit * MAX(1, MIN(12, span)) - 5);

        NineActionSurface *panel =
            [[NineActionSurface alloc]
                initWithFrame:CGRectMake(
                    x, 5, width, height - 10)];

        panel.backgroundColor =
            [UIColor colorWithRed:.12
                            green:.14
                             blue:.18
                            alpha:1];

        panel.layer.cornerRadius = 10;

        [cell.contentView addSubview:panel];

        NSString *kind =
            NHAString(item[@"kind"]) ?: @"";

        NSString *name =
            NHAString(item[@"title"]) ?: @"";

        NSString *value = @"";

        if ([item[@"nine_adapter"] isEqualToString:@"nas_vm"]) {
            name = NHAString(item[@"title"]) ?: @"NAS";
            value = [self ninehaNASStatus];

        } else if ([kind isEqualToString:@"entity"]) {

            NSString *entity =
                NHAString(item[@"entity"]);

            NSDictionary *state =
                NHADict(self.states[entity]);

            NSDictionary *attributes =
                NHADict(state[@"attributes"]);

            if (!name.length) {
                name =
                    NHAString(attributes[@"friendly_name"])
                    ?: entity;
            }

            value =
                NHAString(state[@"state"]) ?: @"—";

            NSString *unitName =
                NHAString(
                    attributes[@"unit_of_measurement"]);

            if (unitName.length) {
                value = [NSString
                    stringWithFormat:@"%@ %@",
                    value, unitName];
            }

        } else if ([kind isEqualToString:@"clock"]) {
            name = @"Orologio";

            value = [self formattedClock:
                NHADict(item[@"config"])];

        } else if ([kind isEqualToString:@"weather"]) {
            name = @"Meteo";

            value = [self weatherSummary:item];

        } else if ([kind isEqualToString:@"unsupported"]) {
            name = @"Non supportato";
            value =
                NHAString(item[@"title"]) ?: @"";
        }

        NSDictionary *look =
            [self ninehaPalette7C:item];

        if (look[@"label"])
            value = look[@"label"];

        UILabel *titleLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                9,
                compactSensorBand ? 5 : 9,
                width - 18,
                compactSensorBand ? 18 : 43)];

        titleLabel.text = name;

        if (look && width >= 210) {
            CGRect rect = titleLabel.frame;
            rect.size.width =
                MAX(25, rect.size.width - 27);
            titleLabel.frame = rect;
        }

        titleLabel.font = compactSensorBand
            ? [UIFont boldSystemFontOfSize:11]
            : [UIFont systemFontOfSize:13
                                  weight:UIFontWeightMedium];

        titleLabel.numberOfLines =
            compactSensorBand ? 1 : 2;
        titleLabel.lineBreakMode =
            NSLineBreakByTruncatingTail;

        titleLabel.textColor = [UIColor whiteColor];

        [panel addSubview:titleLabel];

        CGRect valueFrame = compactSensorBand
            ? CGRectMake(9, 23, width - 18, 27)
            : CGRectMake(9, 54,
                         width - 18, height - 69);

        UILabel *valueLabel =
            [kind isEqualToString:@"clock"]
            ? (UILabel *)[[NineMasonryClockLabel alloc]
                initWithFrame:valueFrame]
            : [[UILabel alloc]
                initWithFrame:valueFrame];

        if ([kind isEqualToString:@"clock"]) {
            ((NineMasonryClockLabel *)valueLabel)
                .clockConfiguration =
                    NHADict(item[@"config"]);
        }

        valueLabel.text = value;
        valueLabel.textColor = look
            ? look[@"accent"]
            : [UIColor colorWithWhite:.76 alpha:1];

        // NineHA.NumericValues8B:
        // aumenta solo i valori contenenti cifre.
        NSRange valueDigitRange =
            [value rangeOfCharacterFromSet:
                [NSCharacterSet decimalDigitCharacterSet]];

        BOOL valueHasDigits =
            valueDigitRange.location != NSNotFound;

        valueLabel.font = compactSensorBand
            ? [UIFont boldSystemFontOfSize:16]
            : [UIFont systemFontOfSize:
                valueHasDigits ? 14 : 12];

        valueLabel.minimumScaleFactor = .72;
        valueLabel.adjustsFontSizeToFitWidth = YES;
        valueLabel.numberOfLines =
            compactSensorBand ? 1 : 2;
        valueLabel.lineBreakMode =
            NSLineBreakByTruncatingTail;

        [panel addSubview:valueLabel];

        NSDictionary *progressLook =
            [self ninehaProgressLook:item];

        if (progressLook) {
            UIProgressView *progressBar =
                [[UIProgressView alloc]
                    initWithProgressViewStyle:
                        UIProgressViewStyleDefault];

            progressBar.progress =
                [progressLook[@"progress"]
                    floatValue];

            progressBar.progressTintColor =
                progressLook[@"color"];

            progressBar.trackTintColor =
                [UIColor colorWithWhite:.28
                                  alpha:1];

            progressBar.frame = CGRectMake(
                9,
                MAX(42, height - 17),
                MAX(20, width - 18),
                3
            );

            progressBar.userInteractionEnabled = NO;
            [panel addSubview:progressBar];
        }

        [self ninehaDecorate7C:panel leaf:item];
        [self ninehaBindActions:panel leaf:item];

        x += width + 9;
    }

    return cell;
}



// NineHA.LightUI7A
// Rendering locale: nessuna azione di rete.
- (NSDictionary *)ninehaLightLook:(NSDictionary *)leaf {

    if (![leaf[@"kind"] isEqualToString:@"entity"])
        return nil;

    NSString *entity =
        NHAString(leaf[@"entity"]) ?: @"";

    NSDictionary *state =
        NHADict(self.states[entity]);

    NSDictionary *attrs =
        NHADict(state[@"attributes"]);

    BOOL light =
        [entity hasPrefix:@"light."];

    BOOL requestedDevice =
        light ||
        [entity hasPrefix:@"switch."] ||
        [entity hasPrefix:@"fan."] ||
        [entity hasPrefix:@"vacuum."] ||
        [entity hasPrefix:@"media_player."];

    if (!light && !requestedDevice)
        return nil;

    NSString *value =
        NHAString(state[@"state"]) ?: @"unknown";

    BOOL unavailable =
        [value isEqualToString:@"unknown"] ||
        [value isEqualToString:@"unavailable"];

    BOOL active =
        [value isEqualToString:@"on"] ||
        [value isEqualToString:@"playing"] ||
        [value isEqualToString:@"cleaning"] ||
        [value isEqualToString:@"returning"] ||
        [value isEqualToString:@"heating"] ||
        [value isEqualToString:@"cooling"];

    UIColor *color = active
        ? [UIColor colorWithRed:.98
                         green:.73
                          blue:.30
                         alpha:1]
        : [UIColor colorWithWhite:.55 alpha:1];

    if (unavailable) {
        color = [UIColor colorWithRed:.90
                                green:.49
                                 blue:.47
                                alpha:1];
    }

    NSString *subtitle = nil;

    if (unavailable) {
        subtitle = @"Non disponibile";
    } else if ([value isEqualToString:@"on"]) {
        subtitle = light ? @"Accesa" : @"Acceso";
    } else if ([value isEqualToString:@"off"]) {
        subtitle = light ? @"Spenta" : @"Spento";
    } else if ([value isEqualToString:@"playing"]) {
        subtitle = @"In riproduzione";
    } else if ([value isEqualToString:@"paused"]) {
        subtitle = @"In pausa";
    } else if ([value isEqualToString:@"idle"]) {
        subtitle = @"Inattivo";
    } else if ([value isEqualToString:@"cleaning"]) {
        subtitle = @"Pulizia in corso";
    } else if ([value isEqualToString:@"returning"]) {
        subtitle = @"Rientro alla base";
    } else if ([value isEqualToString:@"docked"]) {
        subtitle = @"In base";
    } else {
        subtitle = value.length
            ? [value capitalizedString]
            : @"—";
    }

    NSInteger percentage = 0;
    id level = attrs[@"brightness"];

    if (light &&
        active &&
        [level isKindOfClass:[NSNumber class]] &&
        [self ninehaSupportsBrightness:entity]) {

        percentage = MAX(
            1,
            MIN(100,
                (NSInteger)(
                    [level doubleValue] * 100.0 /
                    255.0 + .5
                )
            )
        );

        subtitle = [NSString stringWithFormat:
            @"Accesa · %ld%%",
            (long)percentage];
    }

    return @{
        @"color": color,
        @"subtitle": subtitle ?: @"—",
        @"on": @(active),
        @"percentage": @(percentage)
    };
}

// NineHA.ProgressBridge8D
// Calcolo condiviso della percentuale e del colore.
- (NSDictionary *)ninehaProgressLook:
    (NSDictionary *)leaf {

    if (![leaf[@"nine_progress"] boolValue])
        return nil;

    NSString *entity =
        NHAString(leaf[@"entity"]) ?: @"";

    NSDictionary *record =
        NHADict(self.states[entity]);

    NSDictionary *attributes =
        NHADict(record[@"attributes"]);

    NSString *rawState =
        NHAString(record[@"state"]) ?: @"";

    double currentValue = 0;
    NSScanner *scanner =
        [NSScanner scannerWithString:rawState];

    BOOL valid =
        [scanner scanDouble:&currentValue];

    NSDictionary *configuration =
        NHADict(leaf[@"progress_config"]);

    id minimumObject =
        configuration[@"min"]
        ?: configuration[@"min_value"];

    id maximumObject =
        configuration[@"max"]
        ?: configuration[@"max_value"];

    double minimum =
        [minimumObject respondsToSelector:
            @selector(doubleValue)]
        ? [minimumObject doubleValue] : 0.0;

    double maximum =
        [maximumObject respondsToSelector:
            @selector(doubleValue)]
        ? [maximumObject doubleValue] : 100.0;

    if (maximum <= minimum)
        maximum = minimum + 100.0;

    double fraction = valid
        ? (currentValue - minimum) /
            (maximum - minimum)
        : 0.0;

    fraction = MAX(0.0, MIN(1.0, fraction));

    NSString *deviceClass =
        [NHAString(attributes[@"device_class"])
            lowercaseString];

    NSString *lowerEntity =
        [entity lowercaseString];

    BOOL battery =
        [deviceClass isEqualToString:@"battery"] ||
        [lowerEntity containsString:@"battery"] ||
        [lowerEntity containsString:@"batteria"];

    UIColor *color =
        [UIColor colorWithRed:.37
                        green:.67
                         blue:.89
                        alpha:1];

    if (battery && valid) {
        if (fraction <= .20) {
            color = [UIColor colorWithRed:.91
                                    green:.34
                                     blue:.35
                                    alpha:1];
        } else if (fraction <= .50) {
            color = [UIColor colorWithRed:.94
                                    green:.66
                                     blue:.24
                                    alpha:1];
        } else {
            color = [UIColor colorWithRed:.37
                                    green:.78
                                     blue:.42
                                    alpha:1];
        }
    }

    if (!valid) {
        color =
            [UIColor colorWithWhite:.48 alpha:1];
    }

    return @{
        @"progress": @(fraction),
        @"color": color,
        @"valid": @(valid)
    };
}

// NineHA.Polish7C
// Solo grafica UIKit: nessuna richiesta di rete.
- (NSDictionary *)ninehaPalette7C:
    (NSDictionary *)leaf {

    NSString *kind =
        NHAString(leaf[@"kind"]) ?: @"";

    NSString *entity =
        NHAString(leaf[@"entity"]) ?: @"";

    // Le luci conservano lo stile 7A.1.
    if ([self ninehaLightLook:leaf] ||
        [kind isEqualToString:@"heading"])
        return nil;

    UIColor *accent =
        [UIColor colorWithRed:.54
                        green:.72
                         blue:.88
                        alpha:1];

    NSString *label = nil;
    BOOL active = NO;

    if ([leaf[@"nine_adapter"]
            isEqualToString:@"nas_vm"]) {

        accent = [self ninehaNASColor];
        label = [self ninehaNASStatus];

        active = [self ninehaNASLevel] == 2;

    } else if ([kind isEqualToString:@"clock"]) {

        accent = [UIColor colorWithRed:.70
                                green:.59
                                 blue:.94
                                alpha:1];

    } else if ([kind isEqualToString:@"weather"]) {

        accent = [UIColor colorWithRed:.47
                                green:.76
                                 blue:.97
                                alpha:1];

    } else if (
        [kind isEqualToString:@"entity"] &&
        entity.length
    ) {

        NSDictionary *record =
            NHADict(self.states[entity]);

        NSString *state =
            NHAString(record[@"state"])
            ?: @"unknown";

        NSString *domain =
            [[entity componentsSeparatedByString:@"."]
                firstObject];

        BOOL on = [state isEqualToString:@"on"];
        BOOL off = [state isEqualToString:@"off"];

        if ([domain isEqualToString:@"switch"] ||
            [domain isEqualToString:@"input_boolean"]) {

            accent = on
                ? [UIColor colorWithRed:.39
                                  green:.84
                                   blue:.58
                                  alpha:1]
                : [UIColor colorWithWhite:.62
                                    alpha:1];

            label = on ? @"Acceso"
                       : (off ? @"Spento" : nil);

            active = on;

        } else if (
            [domain isEqualToString:@"binary_sensor"]
        ) {

            accent = on
                ? [UIColor colorWithRed:.93
                                  green:.69
                                   blue:.36
                                  alpha:1]
                : [UIColor colorWithWhite:.62
                                    alpha:1];

            label = on ? @"Attivo"
                       : (off ? @"Inattivo" : nil);

            active = on;

        } else if (
            [domain isEqualToString:@"sensor"]
        ) {

            accent = [UIColor colorWithRed:.43
                                    green:.79
                                     blue:.88
                                    alpha:1];

        } else if (
            [domain isEqualToString:@"vacuum"]
        ) {

            active =
                [state isEqualToString:@"cleaning"];

            accent = active
                ? [UIColor colorWithRed:.40
                                  green:.83
                                   blue:.60
                                  alpha:1]
                : [UIColor colorWithRed:.63
                                  green:.72
                                   blue:.85
                                  alpha:1];

            if (active)
                label = @"Pulizia in corso";

            if ([state isEqualToString:@"docked"])
                label = @"In base";

            if ([state isEqualToString:@"paused"])
                label = @"In pausa";

        } else if (
            [domain isEqualToString:@"media_player"]
        ) {

            active =
                [state isEqualToString:@"playing"];

            accent = active
                ? [UIColor colorWithRed:.77
                                  green:.62
                                   blue:.98
                                  alpha:1]
                : [UIColor colorWithWhite:.64
                                    alpha:1];

            NSDictionary *mediaAttributes =
                NHADict(record[@"attributes"]);

            NSString *mediaTitle =
                NHAString(
                    mediaAttributes[@"media_title"]);

            BOOL paused =
                [state isEqualToString:@"paused"];

            if ([leaf[@"nine_media_control"] boolValue] &&
                mediaTitle.length &&
                (active || paused)) {
                label = mediaTitle;
            } else if (active) {
                label = @"Riproduzione";
            } else if (paused) {
                label = @"In pausa";
            }

            if ([state isEqualToString:@"idle"])
                label = @"Inattivo";

            if ([state isEqualToString:@"off"])
                label = @"Spento";

        } else if (
            [domain isEqualToString:@"button"]
        ) {

            accent = [UIColor colorWithRed:.70
                                    green:.63
                                     blue:.98
                                    alpha:1];
        }

        if (
            [state isEqualToString:@"unavailable"] ||
            [state isEqualToString:@"unknown"]
        ) {

            accent = [UIColor colorWithRed:.90
                                    green:.49
                                     blue:.47
                                    alpha:1];

            label = @"Non disponibile";
            active = NO;
        }

    } else if (![kind isEqualToString:@"unsupported"]) {
        return nil;
    }

    NSMutableDictionary *result = [@{
        @"accent": accent,
        @"active": @(active)
    } mutableCopy];

    if (label.length)
        result[@"label"] = label;

    return result;
}

- (void)ninehaDecorate7C:(UIView *)panel
                    leaf:(NSDictionary *)leaf {

    NSString *kind =
        NHAString(leaf[@"kind"]) ?: @"";

    if ([kind isEqualToString:@"clock"] ||
        [kind isEqualToString:@"weather"]) {
        return;
    }

    NSDictionary *look =
        [self ninehaPalette7C:leaf];

    if (!look) return;

    UIColor *accent = look[@"accent"];
    BOOL active = [look[@"active"] boolValue];

    panel.backgroundColor = active
        ? [UIColor colorWithRed:.13
                          green:.19
                           blue:.19
                          alpha:1]
        : [UIColor colorWithRed:.13
                          green:.15
                           blue:.19
                          alpha:1];

    panel.layer.cornerRadius = 9;
    panel.layer.borderWidth = .5;

    panel.layer.borderColor =
        [accent colorWithAlphaComponent:.25].CGColor;

    // Indicatore colorato molto sottile.
    UIView *stripe = [[UIView alloc]
        initWithFrame:CGRectMake(
            2, 9, 2.5,
            MAX(8, panel.bounds.size.height - 18)
        )];

    stripe.backgroundColor =
        [accent colorWithAlphaComponent:.8];

    stripe.layer.cornerRadius = 1;
    stripe.userInteractionEnabled = NO;

    [panel addSubview:stripe];

    // Glifo solo sulle card abbastanza larghe.
    NSString *entity =
        NHAString(leaf[@"entity"]);

    if (panel.bounds.size.width >= 210 &&
        entity.length) {

        NineGlyphView *glyph =
            [[NineGlyphView alloc]
                initWithFrame:CGRectMake(
                    panel.bounds.size.width - 30,
                    8, 20, 20
                )];

        glyph.entityID = entity;
        glyph.tintColor = accent;
        glyph.userInteractionEnabled = NO;

        [panel addSubview:glyph];
    }
}

#pragma mark - Masonry cards

- (CGFloat)ninehaMasonryLeafHeight:(NSDictionary *)leaf {
    NSString *kind = NHAString(leaf[@"kind"]) ?: @"";

    // NineHA.LightUI7A1
    NSDictionary *deviceLook =
        [self ninehaLightLook:leaf];

    if (deviceLook) {
        NSString *deviceEntity =
            NHAString(leaf[@"entity"]) ?: @"";

        // Le luci mantengono altezza e indicatore
        // della luminosità originali.
        if ([deviceEntity hasPrefix:@"light."])
            return 64;

        // Switch, fan, vacuum e media player usano
        // la variante compatta per evitare ritagli.
        return 54;
    }

    if ([kind isEqualToString:@"heading"]) return 32;
    if ([kind isEqualToString:@"clock"]) return 92;
    if ([kind isEqualToString:@"weather"]) return 63;

    if ([kind isEqualToString:@"layout-band"]) {
        CGFloat height =
            [self ninehaIsThreeSensorBand:leaf]
            ? 76 : 94;

        for (id child in NHAArray(leaf[@"cells"])) {
            NSString *type =
                NHAString(NHADict(child)[@"kind"]);

            if ([type isEqualToString:@"clock"])
                height = MAX(height, 115);

            if ([type isEqualToString:@"weather"])
                height = MAX(height, 100);
        }

        return height;
    }

    return 53;
}

- (NSDictionary *)ninehaMasonryBlock:(id)config {
    NSDictionary *card = NHADict(config);
    if (!card.count) return nil;

    NSMutableArray *leaves =
        [NSMutableArray array];

    NSString *type =
        NHAString(card[@"type"]) ?: @"";

    if ([type isEqualToString:@"grid"] ||
        [type isEqualToString:@"horizontal-stack"] ||
        [type isEqualToString:@"custom:layout-card"]) {

        [self ninehaAppendContainer:card
                             toRows:leaves];

    } else {
        [self addCard:card toRows:leaves depth:0];
    }

    if (!leaves.count) return nil;

    CGFloat height = 16;

    for (id leaf in leaves) {
        height += [self ninehaMasonryLeafHeight:
            NHADict(leaf)];
    }

    return @{
        @"kind": @"masonry-card",
        @"cells": [leaves copy],
        @"height": @(height)
    };
}

- (void)ninehaFlushMasonryColumns:(NSArray *)columns
                          heights:(NSArray *)heights
                           toRows:(NSMutableArray *)rows {

    BOOL empty = YES;
    CGFloat maximum = 0;

    for (NSUInteger i = 0; i < columns.count; i++) {
        if ([columns[i] count]) empty = NO;

        maximum = MAX(
            maximum,
            [heights[i] doubleValue]
        );
    }

    if (empty) return;

    NSMutableArray *frozen =
        [NSMutableArray array];

    for (NSArray *column in columns) {
        [frozen addObject:[column copy]];
    }

    [rows addObject:@{
        @"kind": @"masonry-band",
        @"columns": [frozen copy],
        @"height": @(maximum + 8)
    }];
}

- (void)ninehaAppendMasonryCards:(NSArray *)cards
                          toRows:(NSMutableArray *)rows {

    CGFloat width = MAX(
        260,
        self.tableView.bounds.size.width
    );

    CGFloat usable = MAX(240, width - 20);

    // NineHA.AdaptiveFit7D1
    // Densità responsive:
    // - iPhone 4S: una colonna
    // - iPad verticale: due colonne
    // - iPad orizzontale: tre colonne
    //
    // Il calcolo resta basato sulla larghezza reale
    // del contenitore e continua quindi a reagire
    // alle rotazioni e ai ridimensionamenti.

    CGFloat minColumnWidth = 305.0;

    CGFloat gap = 9.0;

    NSInteger numberOfColumns = MAX(
        1,
        MIN(3,
            (NSInteger)floor(
                (usable + gap) /
                (minColumnWidth + gap)
            )
        )
    );

    self.ninehaBuildingColumnWidth = MAX(
        80,
        (usable - 9.0 * (numberOfColumns - 1)) /
        numberOfColumns
    );

    NSMutableArray *columns =
        [NSMutableArray array];

    NSMutableArray *heights =
        [NSMutableArray array];

    for (NSInteger i = 0; i < numberOfColumns; i++) {
        [columns addObject:[NSMutableArray array]];
        [heights addObject:@0];
    }

    NSUInteger count = 0;

    for (id card in cards) {
        if (++count > 150) break;

        NSDictionary *block =
            [self ninehaMasonryBlock:card];

        if (!block) continue;

        CGFloat blockHeight =
            [block[@"height"] doubleValue] + 8;

        NSInteger shortest = 0;

        for (NSInteger i = 1;
             i < numberOfColumns;
             i++) {

            if ([heights[i] doubleValue] <
                [heights[shortest] doubleValue]) {
                shortest = i;
            }
        }

        // Suddividiamo in bande per limitare
        // il numero di viste presenti in memoria.

        BOOL occupied = YES;

        for (NSArray *column in columns) {
            if (!column.count)
                occupied = NO;
        }

        // Manteniamo più card nella stessa banda
        // per limitare gli spazi vuoti tra colonne.
        // Conserviamo un limite per non creare
        // celle eccessivamente grandi su iOS 9.

        CGFloat bandLimit = MAX(
            1400.0,
            MIN(
                1750.0,
                self.tableView.bounds.size.height * 2.0
            )
        );

        if (occupied &&
            [heights[shortest] doubleValue] +
                blockHeight > bandLimit) {

            [self ninehaFlushMasonryColumns:columns
                                   heights:heights
                                    toRows:rows];

            for (NSInteger i = 0;
                 i < numberOfColumns;
                 i++) {

                [columns[i] removeAllObjects];
                heights[i] = @0;
            }

            shortest = 0;
        }

        [columns[shortest] addObject:block];

        heights[shortest] = @(
            [heights[shortest] doubleValue] +
            blockHeight
        );
    }

    [self ninehaFlushMasonryColumns:columns
                           heights:heights
                            toRows:rows];

    self.ninehaBuildingColumnWidth = 0;
}

- (NSArray *)ninehaTextForLeaf:(NSDictionary *)leaf {
    NSString *kind =
        NHAString(leaf[@"kind"]) ?: @"";

    if ([kind isEqualToString:@"clock"]) {
        return @[
            @"Orologio",
            [self formattedClock:
                NHADict(leaf[@"config"])]
        ];
    }

    if ([kind isEqualToString:@"weather"]) {
        NSString *entity =
            NHAString(leaf[@"entity"]);

        NSDictionary *state =
            NHADict(self.weatherStates[entity]);

        NSDictionary *attr =
            NHADict(state[@"attributes"]);

        return @[
            NHAString(attr[@"friendly_name"]) ?: @"Meteo",
            [self weatherSummary:leaf]
        ];
    }

    if ([leaf[@"nine_adapter"] isEqualToString:@"nas_vm"]) {
        return @[
            NHAString(leaf[@"title"]) ?: @"NAS",
            [self ninehaNASStatus]
        ];
    }

    if ([kind isEqualToString:@"entity"]) {
        NSString *entity =
            NHAString(leaf[@"entity"]) ?: @"";

        NSDictionary *state =
            NHADict(self.states[entity]);

        NSDictionary *attr =
            NHADict(state[@"attributes"]);

        NSString *name =
            NHAString(leaf[@"title"]);

        if (!name.length) {
            name = NHAString(attr[@"friendly_name"])
                ?: entity;
        }

        NSString *value =
            NHAString(state[@"state"]) ?: @"—";

        NSString *unit =
            NHAString(attr[@"unit_of_measurement"]);

        if (unit.length) {
            value = [NSString stringWithFormat:
                @"%@ %@", value, unit];
        }

        return @[name ?: @"", value];
    }

    if ([kind isEqualToString:@"unsupported"]) {
        return @[
            NHAString(leaf[@"title"]) ?: @"Plugin",
            @"Non supportato"
        ];
    }

    return @[
        NHAString(leaf[@"title"]) ?: @"",
        @""
    ];
}

// NineHA.ClockWeather7D3

- (void)ninehaAddClockContent:(NSDictionary *)leaf
                        frame:(CGRect)frame
                       parent:(UIView *)parent {

    NineMasonryClockLabel *clock =
        [[NineMasonryClockLabel alloc]
            initWithFrame:CGRectInset(frame, 6, 4)];

    clock.clockConfiguration =
        NHADict(leaf[@"config"]);

    clock.text =
        [self formattedClock:clock.clockConfiguration];

    clock.textColor =
        [UIColor colorWithRed:.70
                        green:.59
                         blue:.94
                        alpha:1];

    clock.font =
        [UIFont monospacedDigitSystemFontOfSize:38
                                         weight:UIFontWeightMedium];

    clock.textAlignment = NSTextAlignmentCenter;
    clock.adjustsFontSizeToFitWidth = YES;
    clock.minimumScaleFactor = .42;
    clock.numberOfLines = 1;
    clock.lineBreakMode = NSLineBreakByClipping;

    [parent addSubview:clock];
}

- (void)ninehaAddWeatherContent:(NSDictionary *)leaf
                          frame:(CGRect)frame
                         parent:(UIView *)parent {

    NSString *entity =
        NHAString(leaf[@"entity"]) ?: @"";

    NSDictionary *state =
        NHADict(self.weatherStates[entity]);

    NSDictionary *attrs =
        NHADict(state[@"attributes"]);

    NSString *condition =
        NHAString(state[@"state"]) ?: @"unknown";

    NSString *title =
        NHAString(attrs[@"friendly_name"])
        ?: @"Forecast Home";

    id temperature =
        attrs[@"temperature"];

    NSString *unit =
        NHAString(attrs[@"temperature_unit"])
        ?: @"°C";

    id humidity =
        attrs[@"humidity"];

    NSString *temperatureText =
        temperature && temperature != [NSNull null]
        ? [NSString stringWithFormat:
            @"%@ %@", temperature, unit]
        : @"—";

    NSString *humidityText =
        humidity && humidity != [NSNull null]
        ? [NSString stringWithFormat:
            @"Umidità %@%%", humidity]
        : @"Umidità —";

    BOOL narrow =
        frame.size.width < 190;

    CGFloat iconSize =
        narrow ? 32 : 40;

    CGFloat iconLeft =
        narrow ? 5 : 9;

    CGFloat iconTop =
        narrow ? 6 : 5;

    NineGlyphView *glyph =
        [[NineGlyphView alloc]
            initWithFrame:CGRectMake(
                frame.origin.x + iconLeft,
                frame.origin.y + iconTop,
                iconSize,
                iconSize)];

    glyph.entityID = [NSString stringWithFormat:
        @"weather_condition.%@",
        [condition lowercaseString]];

    glyph.tintColor =
        [UIColor colorWithRed:.47
                        green:.76
                         blue:.97
                        alpha:1];

    glyph.userInteractionEnabled = NO;
    [parent addSubview:glyph];

    // Condizione HA centrata sotto l'icona.
    UILabel *conditionLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                frame.origin.x + 2,
                frame.origin.y +
                    iconTop + iconSize + 1,
                iconLeft * 2 + iconSize + 4,
                15)];

    conditionLabel.text = condition;
    conditionLabel.textColor =
        [UIColor colorWithWhite:.76 alpha:1];

    conditionLabel.font =
        [UIFont systemFontOfSize:
            narrow ? 8.5 : 10];

    conditionLabel.textAlignment =
        NSTextAlignmentCenter;

    conditionLabel.adjustsFontSizeToFitWidth = YES;
    conditionLabel.minimumScaleFactor = .65;
    conditionLabel.lineBreakMode =
        NSLineBreakByClipping;

    [parent addSubview:conditionLabel];

    CGFloat textLeft =
        iconLeft + iconSize +
        (narrow ? 7 : 12);

    CGFloat textWidth =
        MAX(50,
            frame.size.width - textLeft - 7);

    UILabel *name =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                frame.origin.x + textLeft,
                frame.origin.y + 4,
                textWidth,
                17)];

    name.text = title;
    name.textColor = [UIColor whiteColor];

    name.font =
        [UIFont boldSystemFontOfSize:
            narrow ? 11 : 12];

    name.adjustsFontSizeToFitWidth = YES;
    name.minimumScaleFactor = .72;
    name.lineBreakMode =
        NSLineBreakByTruncatingTail;

    [parent addSubview:name];

    CGFloat valuesTop =
        frame.origin.y + 23;

    CGFloat valueGap =
        narrow ? 3 : 7;

    CGFloat temperatureWidth =
        floor((textWidth - valueGap) *
              (narrow ? .52 : .48));

    CGFloat humidityWidth =
        MAX(30,
            textWidth -
            temperatureWidth -
            valueGap);

    UILabel *temperatureLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                frame.origin.x + textLeft,
                valuesTop,
                temperatureWidth,
                31)];

    temperatureLabel.text =
        temperatureText;

    temperatureLabel.textColor =
        [UIColor colorWithRed:.47
                        green:.76
                         blue:.97
                        alpha:1];

    temperatureLabel.font =
        [UIFont boldSystemFontOfSize:
            narrow ? 17 : 22];

    temperatureLabel.adjustsFontSizeToFitWidth = YES;
    temperatureLabel.minimumScaleFactor = .62;
    temperatureLabel.lineBreakMode =
        NSLineBreakByClipping;

    [parent addSubview:temperatureLabel];

    UILabel *humidityLabel =
        [[UILabel alloc]
            initWithFrame:CGRectMake(
                frame.origin.x + textLeft +
                    temperatureWidth + valueGap,
                valuesTop + 2,
                humidityWidth,
                29)];

    humidityLabel.text =
        humidityText;

    humidityLabel.textColor =
        [UIColor colorWithRed:.47
                        green:.76
                         blue:.97
                        alpha:1];

    humidityLabel.font =
        [UIFont boldSystemFontOfSize:
            narrow ? 13 : 16];

    humidityLabel.adjustsFontSizeToFitWidth = YES;
    humidityLabel.minimumScaleFactor = .62;
    humidityLabel.lineBreakMode =
        NSLineBreakByClipping;

    [parent addSubview:humidityLabel];
}

- (void)ninehaAddProgressContent:
    (NSDictionary *)leaf
                             frame:(CGRect)frame
                            parent:(UIView *)parent {

    NSDictionary *look =
        [self ninehaProgressLook:leaf];

    if (!look) return;

    NSArray *text =
        [self ninehaTextForLeaf:leaf];

    CGFloat left = frame.origin.x + 7;
    CGFloat top = frame.origin.y;
    CGFloat width =
        MAX(20, frame.size.width - 14);

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(
            left, top + 3,
            MAX(10, width - 28), 18)];

    name.text = text[0];
    name.textColor = [UIColor whiteColor];
    name.font =
        [UIFont boldSystemFontOfSize:12];
    name.lineBreakMode =
        NSLineBreakByTruncatingTail;

    [parent addSubview:name];

    UILabel *value = [[UILabel alloc]
        initWithFrame:CGRectMake(
            left, top + 20,
            width, 19)];

    value.text = text[1];
    value.textColor = look[@"color"];
    value.font =
        [UIFont boldSystemFontOfSize:14];
    value.adjustsFontSizeToFitWidth = YES;
    value.minimumScaleFactor = .70;

    [parent addSubview:value];

    UIProgressView *progress =
        [[UIProgressView alloc]
            initWithProgressViewStyle:
                UIProgressViewStyleDefault];

    progress.progress =
        [look[@"progress"] floatValue];

    progress.progressTintColor =
        look[@"color"];

    progress.trackTintColor =
        [UIColor colorWithWhite:.28 alpha:1];

    progress.frame = CGRectMake(
        left,
        top + MAX(41, frame.size.height - 9),
        width,
        3
    );

    progress.userInteractionEnabled = NO;

    [parent addSubview:progress];
}

- (void)ninehaAddMasonryText:(NSDictionary *)leaf
                      frame:(CGRect)frame
                     parent:(UIView *)parent {

    NSString *kind =
        NHAString(leaf[@"kind"]) ?: @"";

    if ([kind isEqualToString:@"clock"]) {
        [self ninehaAddClockContent:leaf
                              frame:frame
                             parent:parent];
        return;
    }

    if ([kind isEqualToString:@"weather"]) {
        [self ninehaAddWeatherContent:leaf
                                frame:frame
                               parent:parent];
        return;
    }

    if ([leaf[@"nine_progress"] boolValue]) {
        [self ninehaAddProgressContent:leaf
                                 frame:frame
                                parent:parent];
        return;
    }

    NSDictionary *light =
        [self ninehaLightLook:leaf];

    if (light) {
        UIColor *accent = light[@"color"];

        CGFloat left = frame.origin.x;
        CGFloat top = frame.origin.y;
        CGFloat width = frame.size.width;

        BOOL compact = width < 185;

        CGFloat badgeSize = compact ? 30 : 34;
        CGFloat badgeTop = compact ? 9 : 10;
        CGFloat badgeLeft = compact ? 8 : 9;
        CGFloat glyphSize = compact ? 18 : 20;
        CGFloat glyphInset = compact ? 6 : 7;

        UIView *badge = [[UIView alloc]
            initWithFrame:CGRectMake(
                left + badgeLeft, top + badgeTop,
                badgeSize, badgeSize)];

        badge.backgroundColor =
            [accent colorWithAlphaComponent:.14];

        badge.layer.cornerRadius = compact ? 9 : 10;
        badge.userInteractionEnabled = NO;

        NineGlyphView *glyph =
            [[NineGlyphView alloc]
                initWithFrame:CGRectMake(
                    glyphInset, glyphInset,
                    glyphSize, glyphSize)];

        glyph.entityID =
            NHAString(leaf[@"entity"]);

        glyph.tintColor = accent;
        glyph.userInteractionEnabled = NO;

        [badge addSubview:glyph];
        [parent addSubview:badge];

        NSString *name =
            NHAString(leaf[@"title"]);

        if (!name.length) {
            NSDictionary *state =
                NHADict(self.states[leaf[@"entity"]]);

            name = NHAString(
                NHADict(state[@"attributes"])
                    [@"friendly_name"])
                ?: NHAString(leaf[@"entity"])
                ?: @"Luce";
        }

        CGFloat x = left + (compact ? 45 : 49);
        CGFloat textWidth =
            MAX(20, width - (compact ? 52 : 57));

        UILabel *title =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    x, top + 7,
                    textWidth, 20)];

        title.text = name;
        title.textColor = [UIColor whiteColor];
        title.font =
            [UIFont boldSystemFontOfSize:
                compact ? 12 : 12.5];
        title.lineBreakMode =
            NSLineBreakByTruncatingTail;

        [parent addSubview:title];

        UILabel *stateLabel =
            [[UILabel alloc]
                initWithFrame:CGRectMake(
                    x, top + 26,
                    textWidth, 17)];

        stateLabel.text = light[@"subtitle"];
        stateLabel.textColor = accent;
        stateLabel.font =
            [UIFont systemFontOfSize:
                compact ? 11 : 11.5];

        [parent addSubview:stateLabel];

        NSInteger pct =
            [light[@"percentage"] integerValue];

        if (pct > 0 && !compact) {
            UIView *track =
                [[UIView alloc]
                    initWithFrame:CGRectMake(
                        x, top + 48,
                        textWidth, 2.5)];

            track.backgroundColor =
                [UIColor colorWithWhite:.28
                                  alpha:1];

            track.layer.cornerRadius = 1.25;

            UIView *fill =
                [[UIView alloc]
                    initWithFrame:CGRectMake(
                        0, 0,
                        textWidth * pct / 100.0,
                        2.5)];

            fill.backgroundColor = accent;
            fill.layer.cornerRadius = 1.25;

            [track addSubview:fill];
            [parent addSubview:track];
        }

        return;
    }

    NSDictionary *look =
        [self ninehaPalette7C:leaf];

    NSArray *text =
        [self ninehaTextForLeaf:leaf];

    BOOL clock =
        [leaf[@"kind"] isEqualToString:@"clock"];

    BOOL heading =
        [leaf[@"kind"] isEqualToString:@"heading"];

    BOOL compactSensor =
        [leaf[@"nine_compact_sensor"] boolValue];

    UILabel *name = [[UILabel alloc]
        initWithFrame:CGRectMake(
            frame.origin.x + 7,
            frame.origin.y +
                (compactSensor ? 4 : 3),
            MAX(10, frame.size.width - 14 -
                (look && frame.size.width >= 210
                    ? 27 : 0)),
            heading
                ? MAX(23, frame.size.height - 4)
                : (compactSensor ? 16 : 22)
        )];

    name.text = text[0];
    name.textColor = [UIColor whiteColor];
    name.font = [UIFont boldSystemFontOfSize:
        heading ? 13 :
            (compactSensor ? 12 :
                (frame.size.width < 135 ? 11 : 12))];

    name.numberOfLines = heading ? 2 : 1;
    name.lineBreakMode = NSLineBreakByTruncatingTail;

    [parent addSubview:name];

    if (heading) return;

    CGRect valueFrame = compactSensor
        ? CGRectMake(
            frame.origin.x + 7,
            frame.origin.y + 20,
            MAX(10, frame.size.width - 14),
            25
        )
        : CGRectMake(
            frame.origin.x + 7,
            frame.origin.y + 27,
            MAX(10, frame.size.width - 14),
            MAX(18, frame.size.height - 30)
        );

    UILabel *value = clock
        ? (UILabel *)[[NineMasonryClockLabel alloc]
            initWithFrame:valueFrame]
        : [[UILabel alloc]
            initWithFrame:valueFrame];

    if (clock) {
        ((NineMasonryClockLabel *)value)
            .clockConfiguration =
                NHADict(leaf[@"config"]);
    }

    NSString *visibleValue =
        look[@"label"] ?: text[1];

    value.text = visibleValue;

    NSRange visibleDigitRange =
        [visibleValue rangeOfCharacterFromSet:
            [NSCharacterSet decimalDigitCharacterSet]];

    BOOL visibleValueHasDigits =
        visibleDigitRange.location != NSNotFound;

    value.textColor = look
        ? look[@"accent"]
        : [UIColor colorWithWhite:.78 alpha:1];

    value.font = compactSensor
        ? [UIFont boldSystemFontOfSize:18]
        : [UIFont systemFontOfSize:
            clock ? 20 :
            (visibleValueHasDigits
                ? (frame.size.width < 135 ? 13 : 14)
                : (frame.size.width < 135 ? 11 : 12))];

    value.minimumScaleFactor = .6;
    value.adjustsFontSizeToFitWidth = YES;
    value.numberOfLines =
        (clock || compactSensor) ? 1 : 2;
    value.lineBreakMode = NSLineBreakByTruncatingTail;

    [parent addSubview:value];
}

- (void)ninehaDrawMasonryLeaf:(NSDictionary *)leaf
                         atY:(CGFloat)y
                       width:(CGFloat)width
                      parent:(UIView *)panel {

    CGFloat height =
        [self ninehaMasonryLeafHeight:leaf];

    if (![leaf[@"kind"]
            isEqualToString:@"layout-band"]) {

        NineActionSurface *target =
            [[NineActionSurface alloc]
                initWithFrame:CGRectMake(
                    3, y, width - 6, height)];

        NSDictionary *light =
            [self ninehaLightLook:leaf];

        if (light) {
            target.backgroundColor =
                [light[@"on"] boolValue]
                ? [UIColor colorWithRed:.23
                                  green:.19
                                   blue:.13
                                  alpha:1]
                : [UIColor colorWithRed:.15
                                  green:.16
                                   blue:.19
                                  alpha:1];

            target.layer.cornerRadius = 9;
        }

        [panel addSubview:target];

        [self ninehaAddMasonryText:leaf
                            frame:CGRectMake(
                                0, 0, width - 6, height)
                           parent:target];

        [self ninehaDecorate7C:target leaf:leaf];
        [self ninehaBindActions:target leaf:leaf];

        return;
    }

    NSArray *items =
        NHAArray(leaf[@"cells"]);

    NSArray *spans =
        NHAArray(leaf[@"spans"]);

    BOOL compactSensorBand =
        [self ninehaIsThreeSensorBand:leaf];

    CGFloat sideInset =
        compactSensorBand ? 3 : 6;

    CGFloat tileGap =
        compactSensorBand ? 2 : 5;

    CGFloat usable =
        MAX(20, width - sideInset * 2);

    CGFloat x = sideInset;

    for (NSUInteger i = 0; i < items.count; i++) {

        NSDictionary *item =
            NHADict(items[i]);

        if (compactSensorBand) {
            NSMutableDictionary *marked =
                [item mutableCopy];

            marked[@"nine_compact_sensor"] = @YES;
            item = marked;
        }

        NSInteger span =
            i < spans.count
            ? [spans[i] integerValue]
            : 12;

        span = MAX(1, MIN(12, span));

        CGFloat itemWidth = compactSensorBand
            ? MAX(20, (usable - tileGap * 2) / 3.0)
            : MAX(
                20,
                usable * span / 12.0 - tileGap
            );

        NineActionSurface *tile =
            [[NineActionSurface alloc]
                initWithFrame:CGRectMake(
                    x, y + 3,
                    itemWidth, height - 7
                )];

        tile.backgroundColor =
            [UIColor colorWithWhite:.19 alpha:1];

        tile.layer.cornerRadius = 5;

        [panel addSubview:tile];

        [self ninehaAddMasonryText:item
                            frame:CGRectMake(
                                0, 0,
                                itemWidth, height - 7)
                           parent:tile];

        [self ninehaDecorate7C:tile
                          leaf:item];

        [self ninehaBindActions:tile
                          leaf:item];

        x += itemWidth + tileGap;
    }
}

- (UITableViewCell *)ninehaMasonryCell:
    (UITableView *)table
                                   row:(NSDictionary *)row {

    static NSString *reuse = @"NineMasonryBand";

    UITableViewCell *cell =
        [table dequeueReusableCellWithIdentifier:reuse];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleDefault
          reuseIdentifier:reuse];
    }

    cell.backgroundColor = [UIColor blackColor];
    cell.selectionStyle =
        UITableViewCellSelectionStyleNone;

    for (UIView *old in
         [cell.contentView.subviews copy]) {
        [old removeFromSuperview];
    }

    NSArray *columns =
        NHAArray(row[@"columns"]);

    NSUInteger n = columns.count;
    if (!n) return cell;

    CGFloat gap = 9;
    CGFloat width = MAX(
        80,
        (table.bounds.size.width -
            20 - (n - 1) * gap) / n
    );

    for (NSUInteger c = 0; c < n; c++) {
        CGFloat y = 4;

        NSArray *blocks =
            NHAArray(columns[c]);

        for (NSDictionary *block in blocks) {

            CGFloat height =
                [block[@"height"] doubleValue];

            UIView *panel = [[UIView alloc]
                initWithFrame:CGRectMake(
                    10 + c * (width + gap),
                    y, width, height
                )];

            panel.backgroundColor =
                [UIColor colorWithRed:.12
                                green:.14
                                 blue:.18
                                alpha:1];

            panel.layer.cornerRadius = 9;
            panel.clipsToBounds = YES;

            [cell.contentView addSubview:panel];

            CGFloat innerY = 8;

            for (NSDictionary *leaf in
                 NHAArray(block[@"cells"])) {

                [self ninehaDrawMasonryLeaf:leaf
                                      atY:innerY
                                    width:width
                                   parent:panel];

                innerY +=
                    [self ninehaMasonryLeafHeight:leaf];
            }

            y += height + 8;
        }
    }

    return cell;
}

- (BOOL)ninehaRowHasClock:(id)value
            needsSeconds:(BOOL *)seconds {

    NSDictionary *row = NHADict(value);
    BOOL found = NO;

    if ([row[@"kind"] isEqualToString:@"clock"]) {
        found = YES;

        if ([NHADict(row[@"config"])[
                @"show_seconds"] boolValue]) {
            *seconds = YES;
        }
    }

    for (id child in NHAArray(row[@"cells"])) {
        if ([self ninehaRowHasClock:child
                      needsSeconds:seconds]) {
            found = YES;
        }
    }

    for (id column in NHAArray(row[@"columns"])) {
        for (id block in NHAArray(column)) {
            if ([self ninehaRowHasClock:block
                          needsSeconds:seconds]) {
                found = YES;
            }
        }
    }

    return found;
}

- (void)ninehaUpdateClockLabels:(UIView *)view {

    if ([view isKindOfClass:
            [NineMasonryClockLabel class]]) {

        NineMasonryClockLabel *label =
            (NineMasonryClockLabel *)view;

        label.text =
            [self formattedClock:
                label.clockConfiguration];
    }

    for (UIView *child in view.subviews) {
        [self ninehaUpdateClockLabels:child];
    }
}

- (void)rebuildRows {

    if (!self.ninehaRelayoutOnly) {
        self.weatherGeneration++;
        self.weatherInFlight = NO;
        self.weatherStates = @{};
    }

    if (self.selectedView >= (NSInteger)self.views.count) return;

    NSDictionary *view =
        NHADict(self.views[self.selectedView]);

    NSMutableArray *rows = [NSMutableArray array];

    NSString *viewType =
        NHAString(view[@"type"]) ?: @"masonry";

    if ([viewType isEqualToString:@"masonry"]) {

        [self ninehaAppendMasonryCards:
            NHAArray(view[@"cards"])
                                 toRows:rows];

    } else {

        for (id card in NHAArray(view[@"cards"])) {

            NSString *type =
                NHAString(NHADict(card)[@"type"]) ?: @"";

            if ([type isEqualToString:@"grid"] ||
                [type isEqualToString:@"horizontal-stack"] ||
                [type isEqualToString:@"custom:layout-card"]) {

                [self ninehaAppendContainer:
                    NHADict(card) toRows:rows];

            } else {
                [self addCard:card
                       toRows:rows
                        depth:0];
            }
        }
    }

    for (id section in NHAArray(view[@"sections"])) {
        NSDictionary *configuration = NHADict(section);

        NSString *title = NHAString(configuration[@"title"]);

        if (title.length) {
            [rows addObject:@{
                @"kind": @"heading",
                @"title": title
            }];
        }

        [self ninehaAppendSection:
            NHAArray(configuration[@"cards"])
            toRows:rows];
    }

    if (!rows.count) {
        [rows addObject:@{
            @"kind": @"message",
            @"title": @"Nessuna scheda supportata in questa vista."
        }];
    }

    self.rows = rows;
    [self.tableView reloadData];

    if (!self.ninehaRelayoutOnly) {
        [self configureClockTimer];
        [self configureWeatherRefreshTimer];
        [self fetchWeatherStates];
        [self configureLiveUpdates];
    }
}


#pragma mark - Configurable refresh

- (void)configureEntityRefreshTimer {

    [self.timer invalidate];
    self.timer = nil;

    NSInteger seconds =
        [NineUnstableSettingsController
            intervalForGroup:1
                   serverURL:self.auth.serverURL];

    /*
     * Modalità Live:
     *
     * La connessione persistente sarà aggiunta
     * nel prossimo blocco WebSocket.
     *
     * Fino a quel momento conserviamo il polling
     * di sicurezza a 45 secondi.
     *
     * Non rilasciare questa versione intermedia.
     */
    if (seconds == 0) {
        if (self.liveConnected) return;
        seconds = 45; // Fallback REST
    }

    if (seconds < 15) {
        seconds = 45;
    }

    NSLog(@"NineHA Rebuilder: refresh entities every %ld s",
          (long)seconds);

    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
                               target:self
                             selector:@selector(fetchStates)
                             userInfo:nil
                              repeats:YES];
}


#pragma mark - Independent weather refresh

- (void)ensureRESTSession {
    if (self.session) return;

    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration
            ephemeralSessionConfiguration];

    self.session = [NSURLSession
        sessionWithConfiguration:config
                       delegate:self
                  delegateQueue:nil];
}

- (NSArray *)visibleWeatherEntityIDs {
    NSMutableOrderedSet *ids =
        [NSMutableOrderedSet orderedSet];

    NSCharacterSet *invalid = [[NSCharacterSet
        characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyz0123456789._"]
        invertedSet];

    NSMutableArray *scan =
        [NSMutableArray arrayWithArray:self.rows];

    while (scan.count) {

        NSDictionary *row =
            NHADict([scan lastObject]);

        [scan removeLastObject];

        [scan addObjectsFromArray:
            NHAArray(row[@"cells"])];

        for (id column in NHAArray(row[@"columns"])) {
            [scan addObjectsFromArray:
                NHAArray(column)];
        }

        if (![row[@"kind"] isEqualToString:@"weather"])
            continue;

        NSString *entity = NHAString(row[@"entity"]);

        if ([entity hasPrefix:@"weather."] &&
            [entity rangeOfCharacterFromSet:invalid].location
                == NSNotFound) {
            [ids addObject:entity];
        }
    }

    return [ids array];
}

- (void)configureWeatherRefreshTimer {
    [self.weatherTimer invalidate];
    self.weatherTimer = nil;

    if (!self.view.window ||
        ![self visibleWeatherEntityIDs].count)
        return;

    NSInteger seconds =
        [NineUnstableSettingsController
            intervalForGroup:0
                   serverURL:self.auth.serverURL];

    /*
     * Live sarà implementato nel blocco 3D.
     * Temporaneamente manteniamo il fallback.
     */
    if (seconds == 0) {
        if (self.liveConnected) return;
        seconds = 45; // Fallback REST
    }

    self.weatherTimer = [NSTimer
        scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
                               target:self
                             selector:@selector(fetchWeatherStates)
                             userInfo:nil
                              repeats:YES];

    NSLog(@"NineHA: weather refresh ogni %ld s",
          (long)seconds);
}

- (void)fetchWeatherStates {
    if (!self.view.window || self.weatherInFlight)
        return;

    NSArray *ids = [self visibleWeatherEntityIDs];

    if (!ids.count) return;

    NSUInteger generation = self.weatherGeneration;
    self.weatherInFlight = YES;

    [self withToken:^(NSString *token, NSError *tokenError) {
        dispatch_async(dispatch_get_main_queue(), ^{

            if (generation != self.weatherGeneration ||
                !self.view.window)
                return;

            if (tokenError || !token.length) {
                self.weatherInFlight = NO;
                return;
            }

            [self ensureRESTSession];

            __block NSUInteger pending = ids.count;

            NSMutableDictionary *updates =
                [NSMutableDictionary dictionary];

            for (NSString *entity in ids) {

                NSString *fullURL =
                    [NSString stringWithFormat:
                        @"%@/api/states/%@",
                        self.auth.serverURL,
                        entity];

                NSURL *url =
                    [NSURL URLWithString:fullURL];

                if (!url) {
                    if (--pending == 0)
                        self.weatherInFlight = NO;
                    continue;
                }

                NSMutableURLRequest *request =
                    [NSMutableURLRequest
                        requestWithURL:url];

                [request setValue:
                    [@"Bearer "
                        stringByAppendingString:token]
                    forHTTPHeaderField:@"Authorization"];

                request.timeoutInterval = 20;

                [[self.session
                    dataTaskWithRequest:request
                    completionHandler:^(
                        NSData *data,
                        NSURLResponse *response,
                        NSError *networkError) {

                    NSDictionary *state = nil;

                    if (!networkError &&
                        data.length &&
                        [response
                            isKindOfClass:
                            [NSHTTPURLResponse class]] &&
                        [(NSHTTPURLResponse *)response
                            statusCode] == 200) {

                        id obj = [NSJSONSerialization
                            JSONObjectWithData:data
                                       options:0
                                         error:nil];

                        if ([obj
                            isKindOfClass:[NSDictionary class]] &&
                            [obj[@"entity_id"]
                                isEqualToString:entity]) {
                            state = obj;
                        }
                    }

                    dispatch_async(
                        dispatch_get_main_queue(), ^{

                        if (generation !=
                                self.weatherGeneration ||
                            !self.view.window)
                            return;

                        if (state)
                            updates[entity] = state;

                        pending--;

                        if (pending == 0) {
                            NSMutableDictionary *merged =
                                [self.weatherStates mutableCopy];

                            if (!merged) {
                                merged =
                                    [NSMutableDictionary
                                        dictionary];
                            }

                            [merged
                                addEntriesFromDictionary:updates];

                            self.weatherStates =
                                [merged copy];

                            self.weatherInFlight = NO;

                            [self.tableView reloadData];
                        }
                    });

                }] resume];
            }
        });
    }];
}


#pragma mark - Live WebSocket state_changed

- (BOOL)wantsLiveUpdates {
    NSInteger cards =
        [NineUnstableSettingsController
            intervalForGroup:1
                   serverURL:self.auth.serverURL];

    NSInteger weather =
        [NineUnstableSettingsController
            intervalForGroup:0
                   serverURL:self.auth.serverURL];

    return cards == 0 ||
        (weather == 0 &&
         [self visibleWeatherEntityIDs].count > 0);
}

- (void)stopLiveUpdates {
    self.liveEpoch++;

    [self.liveRetryTimer invalidate];
    self.liveRetryTimer = nil;

    [self.liveUITimer invalidate];
    self.liveUITimer = nil;

    [self.liveFeed stop];
    self.liveFeed = nil;

    self.liveConnected = NO;
    self.liveConnecting = NO;
    self.liveRetries = 0;
}

- (void)configureLiveUpdates {
    if (!self.view.window || ![self wantsLiveUpdates]) {
        if (self.liveFeed ||
            self.liveRetryTimer ||
            self.liveConnecting) {

            [self stopLiveUpdates];
            [self configureEntityRefreshTimer];
            [self configureWeatherRefreshTimer];
        }
        return;
    }

    if (!self.liveFeed &&
        !self.liveConnecting &&
        !self.liveRetryTimer) {

        [self connectLiveUpdates];
    }
}

#pragma mark - Reconnection

- (void)scheduleLiveRetry {
    if (!self.view.window ||
        ![self wantsLiveUpdates] ||
        self.liveRetryTimer) {
        return;
    }

    self.liveRetries = MIN(self.liveRetries + 1, 5);

    NSTimeInterval delay =
        MIN((NSTimeInterval)60,
            (NSTimeInterval)(5 *
                (1 << (self.liveRetries - 1))));

    NSLog(@"NineHA Live: nuovo tentativo tra %.0f s",
          delay);

    self.liveRetryTimer = [NSTimer
        scheduledTimerWithTimeInterval:delay
                               target:self
                             selector:@selector(retryLiveConnection)
                             userInfo:nil
                              repeats:NO];
}

- (void)retryLiveConnection {
    self.liveRetryTimer = nil;
    [self configureLiveUpdates];
}

- (void)connectLiveUpdates {
    if (self.liveConnecting ||
        self.liveFeed ||
        !self.view.window) {
        return;
    }

    self.liveConnecting = YES;

    NSUInteger epoch = ++self.liveEpoch;
    __weak typeof(self) weakSelf = self;

    [self withToken:^(NSString *token, NSError *tokenError) {
        dispatch_async(dispatch_get_main_queue(), ^{

            NineLovelaceController *owner = weakSelf;

            if (!owner ||
                owner.liveEpoch != epoch ||
                !owner.view.window ||
                ![owner wantsLiveUpdates]) {
                return;
            }

            if (tokenError || !token.length) {
                owner.liveConnecting = NO;
                [owner scheduleLiveRetry];
                return;
            }

            owner.liveFeed = [[NineLovelaceLive alloc]
                initWithServerURL:owner.auth.serverURL
                            token:token
                          onState:^(
                              NSString *entity,
                              NSDictionary *newState) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    NineLovelaceController *current =
                        weakSelf;

                    if (current &&
                        current.liveEpoch == epoch &&
                        current.liveConnected &&
                        current.view.window) {

                        [current applyLiveState:entity
                                         state:newState];
                    }
                });

            } onStatus:^(BOOL ready) {

                dispatch_async(dispatch_get_main_queue(), ^{
                    NineLovelaceController *current =
                        weakSelf;

                    if (!current ||
                        current.liveEpoch != epoch) {
                        return;
                    }

                    [current liveConnectionChanged:ready];
                });
            }];

            [owner.liveFeed start];
        });
    }];
}

- (void)liveConnectionChanged:(BOOL)ready {
    self.liveConnecting = NO;
    self.liveConnected = ready;

    if (ready) {
        self.liveRetries = 0;
        NSLog(@"NineHA Live: sottoscrizione attiva");
    } else {
        [self.liveFeed stop];
        self.liveFeed = nil;
        NSLog(@"NineHA Live: fallback REST");
    }

    [self configureEntityRefreshTimer];
    [self configureWeatherRefreshTimer];

    if (ready) {
        // Dopo la riconnessione recuperiamo
        // eventuali cambiamenti persi.

        if ([NineUnstableSettingsController
                intervalForGroup:1
                       serverURL:self.auth.serverURL] == 0) {
            [self fetchStates];
        }

        if ([NineUnstableSettingsController
                intervalForGroup:0
                       serverURL:self.auth.serverURL] == 0) {
            [self fetchWeatherStates];
        }
    } else {
        [self scheduleLiveRetry];
    }
}

#pragma mark - Live entity updates

- (void)refreshLiveRows {
    self.liveUITimer = nil;

    if (self.view.window) {
        [self.tableView reloadData];
    }
}

- (void)applyLiveState:(NSString *)entity
                 state:(NSDictionary *)newState {
    if (!entity.length) return;

    BOOL conditionalDependency =
        [[self ninehaConditionalEntityIDs]
            containsObject:entity];

    BOOL cardLive =
        [NineUnstableSettingsController
            intervalForGroup:1
                   serverURL:self.auth.serverURL] == 0;

    BOOL weatherLive =
        [NineUnstableSettingsController
            intervalForGroup:0
                   serverURL:self.auth.serverURL] == 0;

    BOOL matchCard = NO;
    BOOL matchWeather = NO;

    // Non ridisegniamo entità assenti dalla vista.

    for (id item in self.rows) {
        NSDictionary *row = NHADict(item);

        if ([self ninehaRow:row
            containsEntity:entity kind:@"entity"]) {
            matchCard = YES;
        }

        if ([self ninehaRow:row
            containsEntity:entity kind:@"weather"]) {
            matchWeather = YES;
        }
    }

    BOOL changed = NO;

    if (cardLive && matchCard) {
        NSMutableDictionary *map =
            [self.states mutableCopy];

        if (newState) {
            map[entity] = newState;
        } else {
            [map removeObjectForKey:entity];
        }

        self.states = [map copy];
        changed = YES;
    }

    if (weatherLive && matchWeather) {
        NSMutableDictionary *map =
            [self.weatherStates mutableCopy];

        if (newState) {
            map[entity] = newState;
        } else {
            [map removeObjectForKey:entity];
        }

        self.weatherStates = [map copy];
        changed = YES;
    }

    if (cardLive && conditionalDependency) {

        NSMutableDictionary *map =
            [self.states mutableCopy];

        if (!map)
            map = [NSMutableDictionary dictionary];

        if (newState) {
            map[entity] = newState;
        } else {
            [map removeObjectForKey:entity];
        }

        self.states = [map copy];

        [self rebuildRows];
        return;
    }

    // Accorpiamo eventi ravvicinati per ARMv7.

    if (changed && !self.liveUITimer) {
        self.liveUITimer = [NSTimer
            scheduledTimerWithTimeInterval:0.25
                                   target:self
                                 selector:@selector(refreshLiveRows)
                                 userInfo:nil
                                  repeats:NO];
    }
}

#pragma mark - REST states

- (void)fetchStates {
    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.view.window) return;

            [self ensureRESTSession];

            NSURL *url = [NSURL URLWithString:
                [self.auth.serverURL
                    stringByAppendingString:@"/api/states"]];

            NSMutableURLRequest *request =
                [NSMutableURLRequest requestWithURL:url];

            [request setValue:
                [@"Bearer " stringByAppendingString:token]
                forHTTPHeaderField:@"Authorization"];

            request.timeoutInterval = 20;

            [[self.session dataTaskWithRequest:request
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *networkError) {

                if (networkError || !data.length ||
                    [(NSHTTPURLResponse *)response statusCode] != 200)
                    return;

                NSArray *states = [NSJSONSerialization
                    JSONObjectWithData:data options:0 error:nil];

                if (![states isKindOfClass:[NSArray class]]) return;

                NSMutableDictionary *map =
                    [NSMutableDictionary dictionary];

                for (id item in states) {
                    NSDictionary *state = NHADict(item);
                    NSString *entity = NHAString(state[@"entity_id"]);

                    if (entity.length) map[entity] = state;
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!self.view.window) return;

                    BOOL conditionalChanged = NO;

                    for (NSString *entity in
                         [self ninehaConditionalEntityIDs]) {

                        NSString *oldValue =
                            NHAString(
                                NHADict(self.states[entity])[@"state"]
                            ) ?: @"";

                        NSString *newValue =
                            NHAString(
                                NHADict(map[entity])[@"state"]
                            ) ?: @"";

                        if (![oldValue isEqualToString:newValue]) {
                            conditionalChanged = YES;
                            break;
                        }
                    }

                    self.states = map;

                    if (conditionalChanged) {
                        [self rebuildRows];
                    } else {
                        [self.tableView reloadData];
                    }
                });
            }] resume];
        });
    }];
}


#pragma mark - Native clock and weather

- (NSString *)formattedClock:(NSDictionary *)configuration {
    NSDictionary *card = NHADict(configuration);

    NSString *format = [NSString stringWithFormat:
        @"%@", card[@"time_format"] ?: @"24"];

    BOOL twelveHours = [format isEqualToString:@"12"];
    BOOL seconds = [card[@"show_seconds"] boolValue];

    NSDateFormatter *formatter =
        [[NSDateFormatter alloc] init];

    formatter.locale =
        [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    formatter.dateFormat = twelveHours
        ? (seconds ? @"h:mm:ss a" : @"h:mm a")
        : (seconds ? @"HH:mm:ss" : @"HH:mm");

    NSString *zone = NHAString(card[@"time_zone"]);

    if (zone.length) {
        NSTimeZone *timezone =
            [NSTimeZone timeZoneWithName:zone];

        if (timezone) {
            formatter.timeZone = timezone;
        }
    }

    return [formatter stringFromDate:[NSDate date]];
}

- (NSString *)weatherSummary:(NSDictionary *)row {
    NSString *entityID = NHAString(row[@"entity"]);

    NSDictionary *state =
        NHADict(self.weatherStates[entityID]);

    NSDictionary *attributes =
        NHADict(state[@"attributes"]);

    NSString *condition =
        NHAString(state[@"state"])
        ?: @"Non disponibile";

    id temperature =
        attributes[@"temperature"];

    NSString *unit =
        NHAString(attributes[@"temperature_unit"])
        ?: @"°C";

    id humidity =
        attributes[@"humidity"];

    NSMutableArray *parts =
        [NSMutableArray array];

    [parts addObject:condition];

    if (temperature &&
        temperature != [NSNull null]) {
        [parts addObject:[NSString stringWithFormat:
            @"%@ %@", temperature, unit]];
    }

    if (humidity &&
        humidity != [NSNull null]) {
        [parts addObject:[NSString stringWithFormat:
            @"Umidità %@%%", humidity]];
    }

    return [parts componentsJoinedByString:@" · "];
}

- (void)updateVisibleClocks {
    NSArray *visible =
        [self.tableView indexPathsForVisibleRows];

    for (NSIndexPath *indexPath in visible) {
        if (indexPath.row >= (NSInteger)self.rows.count)
            continue;

        NSDictionary *row = self.rows[indexPath.row];

        UITableViewCell *cell =
            [self.tableView cellForRowAtIndexPath:indexPath];

        if (!cell) continue;

        if ([row[@"kind"] isEqualToString:@"clock"]) {
            cell.textLabel.text =
                [self formattedClock:row[@"config"]];
        } else {
            [self ninehaUpdateClockLabels:
                cell.contentView];
        }
    }
}

- (void)configureClockTimer {
    [self.clockTimer invalidate];
    self.clockTimer = nil;

    if (!self.view.window) return;

    BOOL hasClock = NO;
    BOOL seconds = NO;

    for (NSDictionary *row in self.rows) {
        if ([self ninehaRowHasClock:row
                      needsSeconds:&seconds]) {
            hasClock = YES;
        }
    }

    if (!hasClock) return;

    NSTimeInterval interval = seconds ? 1.0 : 10.0;

    self.clockTimer = [NSTimer
        scheduledTimerWithTimeInterval:interval
                               target:self
                             selector:@selector(updateVisibleClocks)
                             userInfo:nil
                              repeats:YES];

    [self updateVisibleClocks];
}


// NineHA.LightBrightness6C2

- (BOOL)ninehaSupportsBrightness:(NSString *)entity {

    if (![entity hasPrefix:@"light."])
        return NO;

    NSDictionary *record =
        NHADict(self.states[entity]);

    NSDictionary *attrs =
        NHADict(record[@"attributes"]);

    NSArray *modes =
        NHAArray(attrs[@"supported_color_modes"]);

    NSSet *dimmable = [NSSet setWithArray:@[
        @"brightness",
        @"color_temp",
        @"hs",
        @"rgb",
        @"rgbw",
        @"rgbww",
        @"xy",
        @"white"
    ]];

    for (id value in modes) {
        if ([value isKindOfClass:[NSString class]] &&
            [dimmable containsObject:value]) {
            return YES;
        }
    }

    return NO;
}

- (void)ninehaShowBrightness:(NSString *)entity {

    if (![self ninehaSupportsBrightness:entity] ||
        self.presentedViewController ||
        !self.view.window) {
        return;
    }

    NSDictionary *record =
        NHADict(self.states[entity]);

    NSDictionary *attrs =
        NHADict(record[@"attributes"]);

    id raw = attrs[@"brightness"];

    // Valore iniziale quando la luce è spenta
    // oppure non comunica la luminosità.
    NSInteger percent = 50;

    if ([raw isKindOfClass:[NSNumber class]]) {

        double level = [raw doubleValue];

        if (level > 0) {
            percent = (NSInteger)(
                level * 100.0 / 255.0 + 0.5
            );
        }
    }

    percent = MAX(1, MIN(100, percent));

    NineLightBrightnessController *sheet =
        [[NineLightBrightnessController alloc] init];

    sheet.lightName =
        NHAString(attrs[@"friendly_name"]) ?: entity;

    sheet.initialPercent = percent;

    __weak NineLovelaceController *weakSelf = self;

    NSString *targetEntity = [entity copy];

    sheet.onApply = ^(NSInteger selected) {

        NineLovelaceController *owner = weakSelf;

        if (!owner) return;

        [owner dismissViewControllerAnimated:YES
                                  completion:^{

            if (owner.view.window) {

                [owner.actionEngine
                    setLightBrightness:targetEntity
                           percentage:selected
                            presenter:owner];
            }
        }];
    };

    UINavigationController *navigation =
        [[UINavigationController alloc]
            initWithRootViewController:sheet];

    navigation.modalPresentationStyle =
        UIModalPresentationFormSheet;

    navigation.navigationBar.barStyle =
        UIBarStyleBlack;

    navigation.navigationBar.barTintColor =
        [UIColor blackColor];

    navigation.navigationBar.tintColor =
        [UIColor whiteColor];

    [self presentViewController:navigation
                       animated:YES
                     completion:nil];
}

// NineHA.NativeDetails8E
- (NSString *)ninehaDetailsEntityForCard:
    (NSDictionary *)card
                                gesture:(NSString *)gesture {

    NSString *actionKey =
        [gesture isEqualToString:@"hold"]
        ? @"hold_action" : @"tap_action";

    NSDictionary *action =
        NHADict(card[actionKey]);

    id target =
        NHADict(action[@"target"])[@"entity_id"];

    if (!target) {
        target =
            NHADict(action[@"data"])[@"entity_id"];
    }

    if ([target isKindOfClass:[NSArray class]]) {
        target = [target count] ? [target firstObject] : nil;
    }

    return NHAString(target)
        ?: NHAString(card[@"entity"]);
}

- (NSString *)ninehaDetailsState:
    (NSString *)rawState
                         domain:(NSString *)domain {

    if ([rawState isEqualToString:@"on"])
        return [domain isEqualToString:@"light"]
            ? @"Accesa" : @"Acceso";

    if ([rawState isEqualToString:@"off"])
        return [domain isEqualToString:@"light"]
            ? @"Spenta" : @"Spento";

    if ([rawState isEqualToString:@"unavailable"] ||
        [rawState isEqualToString:@"unknown"])
        return @"Non disponibile";

    if ([rawState isEqualToString:@"docked"])
        return @"In base";

    if ([rawState isEqualToString:@"cleaning"])
        return @"Pulizia in corso";

    if ([rawState isEqualToString:@"returning"])
        return @"Rientro alla base";

    if ([rawState isEqualToString:@"playing"])
        return @"In riproduzione";

    if ([rawState isEqualToString:@"paused"])
        return @"In pausa";

    if ([rawState isEqualToString:@"idle"])
        return @"Inattivo";

    return rawState.length ? rawState : @"—";
}

- (void)ninehaShowDetailsForCard:
    (NSDictionary *)card
                            gesture:(NSString *)gesture {

    if (self.presentedViewController ||
        !self.view.window) {
        return;
    }

    NSString *entity =
        [self ninehaDetailsEntityForCard:card
                                 gesture:gesture];

    if (!entity.length) {
        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"Dettagli"
                message:@"Questa card non specifica "
                        "un'entità."
                preferredStyle:
                    UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction
            actionWithTitle:@"OK"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];
        return;
    }

    NSDictionary *record =
        NHADict(self.states[entity]);

    if (!record.count) {
        record = NHADict(self.weatherStates[entity]);
    }

    NSDictionary *attributes =
        NHADict(record[@"attributes"]);

    NSString *domain =
        [[entity componentsSeparatedByString:@"."]
            firstObject] ?: @"";

    NSString *title =
        NHAString(card[@"name"])
        ?: NHAString(card[@"primary"])
        ?: NHAString(card[@"title"])
        ?: NHAString(attributes[@"friendly_name"])
        ?: entity;

    if ([title containsString:@"{{"] ||
        [title containsString:@"[[["]) {
        title =
            NHAString(attributes[@"friendly_name"])
            ?: entity;
    }

    NSString *rawState =
        NHAString(record[@"state"]) ?: @"unknown";

    NSString *stateText =
        [self ninehaDetailsState:rawState
                           domain:domain];

    NSString *unit =
        NHAString(attributes[@"unit_of_measurement"]);

    if (unit.length &&
        ![stateText containsString:unit]) {
        stateText = [NSString
            stringWithFormat:@"%@ %@",
            stateText, unit];
    }

    NSMutableArray *rows =
        [NSMutableArray array];

    if (domain.length) {
        [rows addObject:@{
            @"label": @"Dominio",
            @"value": domain
        }];
    }

    NSArray *specifications = @[
        @[@"brightness", @"Luminosità"],
        @[@"battery_level", @"Batteria"],
        @[@"battery", @"Batteria"],
        @[@"humidity", @"Umidità"],
        @[@"temperature", @"Temperatura"],
        @[@"illuminance", @"Illuminamento"],
        @[@"volume_level", @"Volume"],
        @[@"media_title", @"Contenuto"],
        @[@"media_artist", @"Artista"],
        @[@"app_name", @"Applicazione"],
        @[@"source", @"Sorgente"],
        @[@"current_position", @"Posizione"],
        @[@"fan_speed", @"Velocità"],
        @[@"status", @"Stato dispositivo"],
        @[@"device_class", @"Classe dispositivo"]
    ];

    NSMutableSet *usedLabels =
        [NSMutableSet set];

    for (NSArray *specification in specifications) {

        NSString *key = specification[0];
        NSString *label = specification[1];
        id rawValue = attributes[key];

        if (!rawValue ||
            rawValue == [NSNull null] ||
            [usedLabels containsObject:label]) {
            continue;
        }

        if (![rawValue isKindOfClass:[NSString class]] &&
            ![rawValue isKindOfClass:[NSNumber class]]) {
            continue;
        }

        NSString *value = nil;

        if ([key isEqualToString:@"brightness"]) {
            NSInteger percentage =
                (NSInteger)(
                    [rawValue doubleValue] *
                    100.0 / 255.0 + .5);

            value = [NSString stringWithFormat:
                @"%ld%%",
                (long)MAX(0, MIN(100, percentage))];

        } else if ([key isEqualToString:@"volume_level"]) {
            NSInteger percentage =
                (NSInteger)(
                    [rawValue doubleValue] *
                    100.0 + .5);

            value = [NSString stringWithFormat:
                @"%ld%%",
                (long)MAX(0, MIN(100, percentage))];

        } else if (
            [key isEqualToString:@"battery_level"] ||
            [key isEqualToString:@"battery"] ||
            [key isEqualToString:@"humidity"] ||
            [key isEqualToString:@"current_position"]
        ) {
            value = [NSString stringWithFormat:
                @"%@%%", rawValue];

        } else if (
            [key isEqualToString:@"temperature"]
        ) {
            NSString *temperatureUnit =
                NHAString(attributes[@"temperature_unit"])
                ?: @"°C";

            value = [NSString stringWithFormat:
                @"%@ %@", rawValue, temperatureUnit];

        } else if (
            [key isEqualToString:@"illuminance"]
        ) {
            value = [NSString stringWithFormat:
                @"%@ lx", rawValue];

        } else {
            value = [rawValue description];
        }

        if (!value.length) continue;

        [rows addObject:@{
            @"label": label,
            @"value": value
        }];

        [usedLabels addObject:label];
    }

    NSString *lastChanged =
        NHAString(record[@"last_changed"]);

    if (lastChanged.length) {
        NSString *readable =
            [lastChanged
                stringByReplacingOccurrencesOfString:@"T"
                                          withString:@" "];

        [rows addObject:@{
            @"label": @"Ultima variazione",
            @"value": readable
        }];
    }

    NSDictionary *leaf = @{
        @"kind": @"entity",
        @"entity": entity,
        @"title": title
    };

    NSDictionary *light =
        [self ninehaLightLook:leaf];

    NSDictionary *palette =
        [self ninehaPalette7C:leaf];

    UIColor *accent =
        light[@"color"]
        ?: palette[@"accent"]
        ?: [UIColor colorWithRed:.43
                           green:.79
                            blue:.88
                           alpha:1];

    NineEntityDetailsController *details =
        [[NineEntityDetailsController alloc]
            initWithStyle:UITableViewStyleGrouped];

    details.entityName = title;
    details.entityID = entity;
    details.stateText = stateText;
    details.stateColor = accent;
    details.detailRows = [rows copy];

    UINavigationController *navigation =
        [[UINavigationController alloc]
            initWithRootViewController:details];

    navigation.modalPresentationStyle =
        UIModalPresentationFormSheet;

    navigation.navigationBar.barStyle =
        UIBarStyleBlack;

    navigation.navigationBar.barTintColor =
        [UIColor blackColor];

    navigation.navigationBar.tintColor =
        [UIColor whiteColor];

    [self presentViewController:navigation
                       animated:YES
                     completion:nil];
}

#pragma mark - Native Lovelace gestures 6B

- (void)ninehaTapAction:(UITapGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateRecognized)
        return;

    NineActionSurface *surface =
        (NineActionSurface *)gesture.view;

    NSDictionary *card = surface.actionCard;

    if (card.count && self.view.window) {

        NSString *action =
            NHAString(
                NHADict(card[@"tap_action"])
                    [@"action"]);

        if ([action isEqualToString:@"more-info"]) {
            [self ninehaShowDetailsForCard:card
                                   gesture:@"tap"];
            return;
        }

        [self.actionEngine performCard:card
                              gesture:@"tap"
                            presenter:self];
    }
}

- (void)ninehaHoldAction:
    (UILongPressGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateBegan)
        return;

    NineActionSurface *surface =
        (NineActionSurface *)gesture.view;

    NSDictionary *card = surface.actionCard;

    if (card.count && self.view.window) {

        NSString *action = NHAString(
            NHADict(card[@"hold_action"])[@"action"]
        );

        if ([action isEqualToString:@"more-info"]) {
            [self ninehaShowDetailsForCard:card
                                   gesture:@"hold"];
            return;
        }

        if ([action isEqualToString:
                @"nineha-brightness"]) {

            [self ninehaShowBrightness:
                NHAString(card[@"entity"])];

            return;
        }

        [self.actionEngine performCard:card
                              gesture:@"hold"
                            presenter:self];
    }
}

- (void)ninehaBindActions:(NineActionSurface *)surface
                     leaf:(NSDictionary *)leaf {

    NSDictionary *card =
        NHADict(leaf[@"action_card"]);

    if (!card.count) return;

    // NineHA.DefaultLightToggle6B1
    // Solo le tile light prive di tap_action.
    // Le azioni esplicite hanno sempre precedenza.
    NSString *cardType =
        NHAString(card[@"type"]);

    NSString *entityID =
        NHAString(card[@"entity"]);

    // NineHA.EntitiesLightToggle6B2
    // Supporta anche le righe delle card entities.
    // Non modifica le azioni Lovelace esplicite.

    NSString *rowKind =
        NHAString(leaf[@"kind"]);

    BOOL isEntityRow =
        [rowKind isEqualToString:@"entity"];

    BOOL isPlainEntity =
        !cardType.length ||
        [cardType isEqualToString:@"entity"];

    BOOL eligible =
        [cardType isEqualToString:@"tile"] ||
        (isEntityRow && isPlainEntity);

    BOOL defaultLightToggle =
        eligible &&
        [entityID hasPrefix:@"light."] &&
        card[@"tap_action"] == nil;

    // NineHA.SafeSwitchToggle6C1
    // Gli switch senza tap_action vengono attivati solo se
    // esplicitamente autorizzati nella configurazione locale.
    NSArray *safeSwitches = NINEHA_SAFE_SWITCH_ENTITIES;

    BOOL defaultSafeSwitchToggle =
        isEntityRow &&
        isPlainEntity &&
        [entityID hasPrefix:@"switch."] &&
        [safeSwitches containsObject:entityID] &&
        card[@"tap_action"] == nil;

    if (defaultLightToggle ||
        defaultSafeSwitchToggle) {

        NSMutableDictionary *adjusted =
            [card mutableCopy];

        adjusted[@"tap_action"] =
            @{@"action": @"toggle"};

        card = [adjusted copy];
    }

    // NineHA.NativeDetails8E
    // Le entità senza azioni esplicite aprono il
    // pannello dettagli. Toggle e hold già assegnati
    // mantengono sempre la precedenza.
    if (isEntityRow &&
        card[@"tap_action"] == nil &&
        card[@"hold_action"] == nil) {

        NSMutableDictionary *adjusted =
            [card mutableCopy];

        adjusted[@"tap_action"] =
            @{@"action": @"more-info"};

        card = [adjusted copy];
    }

    // Gesto nativo soltanto sulle luci
    // dimmerabili prive di hold_action esplicita.

    if (eligible &&
        [entityID hasPrefix:@"light."] &&
        card[@"hold_action"] == nil &&
        [self ninehaSupportsBrightness:entityID]) {

        NSMutableDictionary *adjusted =
            [card mutableCopy];

        adjusted[@"hold_action"] =
            @{@"action": @"nineha-brightness"};

        card = [adjusted copy];
    }

    NSDictionary *tap =
        NHADict(card[@"tap_action"]);

    NSDictionary *hold =
        NHADict(card[@"hold_action"]);

    NSString *tapType =
        NHAString(tap[@"action"]);

    NSString *holdType =
        NHAString(hold[@"action"]);

    BOOL hasTap =
        tapType.length &&
        ![tapType isEqualToString:@"none"];

    BOOL hasHold =
        holdType.length &&
        ![holdType isEqualToString:@"none"];

    if (!hasTap && !hasHold)
        return;

    surface.actionCard = card;
    surface.userInteractionEnabled = YES;

    UILongPressGestureRecognizer *holdGesture = nil;

    if (hasHold) {
        holdGesture =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(ninehaHoldAction:)];

        holdGesture.minimumPressDuration = 0.7;
        holdGesture.cancelsTouchesInView = NO;

        [surface addGestureRecognizer:holdGesture];
    }

    if (hasTap) {
        UITapGestureRecognizer *tapGesture =
            [[UITapGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(ninehaTapAction:)];

        tapGesture.cancelsTouchesInView = NO;

        if (holdGesture) {
            [tapGesture
                requireGestureRecognizerToFail:holdGesture];
        }

        [surface addGestureRecognizer:tapGesture];
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *kind = self.rows[indexPath.row][@"kind"];

    if ([kind isEqualToString:@"heading"]) return 43;

    if ([kind isEqualToString:@"masonry-band"]) {
        return [self.rows[indexPath.row][
            @"height"] doubleValue];
    }

    if ([kind isEqualToString:@"layout-band"]) {

        if ([self ninehaIsThreeSensorBand:
                NHADict(self.rows[indexPath.row])]) {
            return 76;
        }

        CGFloat height = 94;

        for (id object in
            NHAArray(self.rows[indexPath.row][@"cells"])) {

            NSString *type =
                NHAString(NHADict(object)[@"kind"]);

            if ([type isEqualToString:@"clock"])
                height = MAX(height, 120);

            if ([type isEqualToString:@"weather"])
                height = MAX(height, 105);
        }

        return height;
    }

    if ([self ninehaLightLook:
            NHADict(self.rows[indexPath.row])]) {
        return 68;
    }

    if ([kind isEqualToString:@"clock"]) return 88;
    if ([kind isEqualToString:@"weather"]) return 96;
    return 67;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSDictionary *layoutItem =
        NHADict(self.rows[indexPath.row]);

    if ([layoutItem[@"kind"]
            isEqualToString:@"masonry-band"]) {

        return [self ninehaMasonryCell:tableView
                                  row:layoutItem];
    }

    if ([layoutItem[@"kind"]
            isEqualToString:@"layout-band"]) {

        return [self ninehaLayoutCell:tableView
                                 row:layoutItem];
    }

    static NSString *reuse = @"LovelaceRow";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:reuse];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:reuse];
    }

    NSDictionary *row = self.rows[indexPath.row];
    NSString *kind = row[@"kind"];

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor =
        [UIColor colorWithRed:.12 green:.13 blue:.16 alpha:1];

    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font =
        [UIFont systemFontOfSize:15];

    cell.detailTextLabel.textColor =
        [UIColor colorWithWhite:.67 alpha:1];

    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;

    // Eliminiamo eventuali superfici precedenti
    // quando UITableView riutilizza la cella.
    for (UIView *old in [cell.contentView.subviews copy]) {
        if ([old isKindOfClass:[NineActionSurface class]] ||
            old.tag == 7707) {
            [old removeFromSuperview];
        }
    }

    if ([kind isEqualToString:@"clock"]) {
        cell.textLabel.text =
            [self formattedClock:row[@"config"]];

        cell.textLabel.font =
            [UIFont monospacedDigitSystemFontOfSize:38
                                             weight:UIFontWeightMedium];

        cell.textLabel.textAlignment =
            NSTextAlignmentCenter;

        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = .45;
        cell.detailTextLabel.text = nil;

    } else if ([kind isEqualToString:@"weather"]) {
        NSString *entityID = NHAString(row[@"entity"]);

        NSDictionary *state =
            NHADict(self.weatherStates[entityID]);

        NSDictionary *attrs =
            NHADict(state[@"attributes"]);

        cell.textLabel.text =
            NHAString(attrs[@"friendly_name"]) ?: @"Meteo";

        cell.detailTextLabel.text =
            [self weatherSummary:row];

        cell.textLabel.font =
            [UIFont systemFontOfSize:17];

    } else if ([row[@"nine_adapter"] isEqualToString:@"nas_vm"]) {
        cell.textLabel.text =
            NHAString(row[@"title"]) ?: @"NAS";

        cell.detailTextLabel.text =
            [self ninehaNASStatus];

        cell.detailTextLabel.textColor =
            [self ninehaNASColor];

    } else if ([kind isEqualToString:@"entity"]) {
        NSString *entity = row[@"entity"];
        NSDictionary *state = NHADict(self.states[entity]);
        NSDictionary *attributes = NHADict(state[@"attributes"]);

        NSString *title = row[@"title"];
        if (!title.length) {
            title = NHAString(attributes[@"friendly_name"]) ?: entity;
        }

        NSString *value = NHAString(state[@"state"]) ?: @"—";
        NSString *unit = NHAString(attributes[@"unit_of_measurement"]);

        NSDictionary *light =
            [self ninehaLightLook:row];

        cell.textLabel.text = title;

        cell.detailTextLabel.text = light
            ? light[@"subtitle"]
            : (unit.length
               ? [NSString stringWithFormat:
                    @"%@ %@", value, unit]
               : value);

        if (light) {
            UIColor *accent = light[@"color"];

            cell.textLabel.font =
                [UIFont boldSystemFontOfSize:15];

            cell.detailTextLabel.textColor = accent;

            cell.backgroundColor =
                [light[@"on"] boolValue]
                ? [UIColor colorWithRed:.18
                                  green:.15
                                   blue:.12
                                  alpha:1]
                : [UIColor colorWithRed:.12
                                  green:.13
                                   blue:.16
                                  alpha:1];

            NSInteger pct =
                [light[@"percentage"] integerValue];

            if (pct > 0) {
                UIProgressView *progress =
                    [[UIProgressView alloc]
                        initWithProgressViewStyle:
                            UIProgressViewStyleDefault];

                progress.tag = 7707;
                progress.progress = pct / 100.0f;
                progress.progressTintColor = accent;

                progress.trackTintColor =
                    [UIColor colorWithWhite:.26
                                      alpha:1];

                progress.frame = CGRectMake(
                    15, 56,
                    MAX(60,
                        tableView.bounds.size.width - 70),
                    2.5);

                progress.autoresizingMask =
                    UIViewAutoresizingFlexibleWidth;

                progress.userInteractionEnabled = NO;

                [cell.contentView addSubview:progress];
            }
        }

        NSDictionary *progressLook =
            [self ninehaProgressLook:row];

        if (progressLook) {
            UIProgressView *progressBar =
                [[UIProgressView alloc]
                    initWithProgressViewStyle:
                        UIProgressViewStyleDefault];

            progressBar.tag = 7707;

            progressBar.progress =
                [progressLook[@"progress"]
                    floatValue];

            progressBar.progressTintColor =
                progressLook[@"color"];

            progressBar.trackTintColor =
                [UIColor colorWithWhite:.26
                                  alpha:1];

            progressBar.frame = CGRectMake(
                15, 56,
                MAX(60,
                    tableView.bounds.size.width - 70),
                3
            );

            progressBar.autoresizingMask =
                UIViewAutoresizingFlexibleWidth;

            progressBar.userInteractionEnabled = NO;
            [cell.contentView addSubview:progressBar];
        }

        NineGlyphView *glyph = [[NineGlyphView alloc]
            initWithFrame:CGRectMake(0, 0, 30, 30)];

        glyph.entityID = entity;
        glyph.tintColor = light
            ? light[@"color"]
            : [UIColor colorWithRed:.43
                              green:.72
                               blue:.96
                              alpha:1];

        cell.accessoryView = glyph;

    } else {
        cell.textLabel.text = row[@"title"];

        if ([kind isEqualToString:@"unsupported"]) {
            cell.detailTextLabel.text =
                @"Scheda non ancora supportata";
        }
    }

    NSDictionary *look7C =
        [self ninehaPalette7C:row];

    if (look7C) {
        if (look7C[@"label"] &&
            [kind isEqualToString:@"entity"]) {

            cell.detailTextLabel.text =
                look7C[@"label"];
        }

        cell.detailTextLabel.textColor =
            look7C[@"accent"];

        cell.backgroundColor =
            [UIColor colorWithRed:.13
                            green:.15
                             blue:.19
                            alpha:1];

        if ([cell.accessoryView isKindOfClass:
                [NineGlyphView class]]) {

            cell.accessoryView.tintColor =
                look7C[@"accent"];
        }
    }

    if (NHADict(row[@"action_card"]).count) {

        NineActionSurface *target =
            [[NineActionSurface alloc]
                initWithFrame:cell.contentView.bounds];

        target.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [cell.contentView addSubview:target];

        [self ninehaBindActions:target leaf:row];
    }

    return cell;
}

@end

#pragma mark - Experimental WebView

// Evita un riferimento circolare tra WKWebView
// e il controller che gestisce i messaggi JavaScript.
@interface NineWeakAuthBridge : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> receiver;
@end

@implementation NineWeakAuthBridge

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.receiver userContentController:controller
                 didReceiveScriptMessage:message];
}

@end

@interface NineLegacyWebController () <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) WKWebView *web;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation NineLegacyWebController

- (void)ninehaExitOriginalWebView {
    [self.web stopLoading];
    self.web.navigationDelegate = nil;

    NineLovelaceController *target =
        [[NineLovelaceController alloc]
            initWithAuth:self.auth mode:self.mode];

    NSMutableArray *stack =
        [self.navigationController.viewControllers mutableCopy];

    NSUInteger index =
        [stack indexOfObjectIdenticalTo:self];

    if (index != NSNotFound) {
        [stack replaceObjectAtIndex:index
                         withObject:target];

        [self.navigationController
            setViewControllers:stack animated:NO];

    } else {
        [self.navigationController
            pushViewController:target animated:YES];
    }
}


- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode {
    self = [super init];

    if (self) {
        _auth = auth;
        _mode = [mode copy];
    }

    return self;
}

- (void)setStatus:(NSString *)status {
    self.statusLabel.text = status;
    NSLog(@"NineHA WebView: %@", status);
}

- (void)loadView {
    UIView *root = [[UIView alloc]
        initWithFrame:[UIScreen mainScreen].bounds];

    root.backgroundColor = [UIColor blackColor];
    self.view = root;

    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];

    WKUserContentController *messages =
        [[WKUserContentController alloc] init];

    NineWeakAuthBridge *bridge =
        [[NineWeakAuthBridge alloc] init];

    bridge.receiver = self;

    [messages addScriptMessageHandler:bridge
                                name:@"getExternalAuth"];

    [messages addScriptMessageHandler:bridge
                                name:@"revokeExternalAuth"];

    configuration.userContentController = messages;

    // Sessione WebView temporanea e separata.
    configuration.websiteDataStore =
        [WKWebsiteDataStore nonPersistentDataStore];

    self.web = [[WKWebView alloc]
        initWithFrame:root.bounds
       configuration:configuration];

    self.web.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    self.web.navigationDelegate = self;

    [root addSubview:self.web];

    UILabel *status = [[UILabel alloc]
        initWithFrame:CGRectMake(8,
                                 root.bounds.size.height - 42,
                                 root.bounds.size.width - 16,
                                 38)];

    status.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleTopMargin;

    status.textAlignment = NSTextAlignmentCenter;
    status.textColor = [UIColor whiteColor];
    status.backgroundColor =
        [UIColor colorWithWhite:0 alpha:.85];
    status.font = [UIFont systemFontOfSize:12];

    self.statusLabel = status;
    [root addSubview:status];

    NSURLComponents *components =
        [NSURLComponents componentsWithString:self.auth.serverURL];

    NSString *scheme = components.scheme.lowercaseString;

    if (!components.host.length ||
        (! [scheme isEqualToString:@"http"] &&
         ! [scheme isEqualToString:@"https"])) {
        [self setStatus:@"URL server non valido"];
        return;
    }

    NSString *path = components.path ?: @"";
    while ([path hasSuffix:@"/"] && path.length) {
        path = [path substringToIndex:path.length - 1];
    }

    components.path = [path stringByAppendingString:@"/lovelace"];
    components.query = @"external_auth=1";
    components.fragment = nil;

    NSURL *url = components.URL;

    if (url) {
        [self setStatus:@"Attesa richiesta autenticazione..."];
        [self.web loadRequest:
            [NSURLRequest requestWithURL:url]];
    }
}

// Accettiamo richieste del bridge soltanto dalla pagina
// principale dell'istanza HA configurata.
- (BOOL)isTrustedMessage:(WKScriptMessage *)message {
    if (!message.frameInfo.isMainFrame) return NO;

    NSURLComponents *server =
        [NSURLComponents componentsWithString:self.auth.serverURL];

    WKSecurityOrigin *origin =
        message.frameInfo.securityOrigin;

    NSString *scheme = server.scheme.lowercaseString;

    NSInteger expectedPort = server.port
        ? server.port.integerValue
        : ([scheme isEqualToString:@"https"] ? 443 : 80);

    return origin.host.length &&
        server.host.length &&
        [origin.host caseInsensitiveCompare:server.host] ==
            NSOrderedSame &&
        [origin.protocol isEqualToString:scheme] &&
        origin.port == expectedPort;
}

- (void)deliverToken:(NSString *)token
               error:(NSError *)error {
    if (!self.web) return;

    if (error || !token.length) {
        [self setStatus:@"Token non disponibile"];

        [self.web evaluateJavaScript:
            @"if (typeof window.externalAuthSetToken === 'function')"
             " window.externalAuthSetToken(false);"
                 completionHandler:nil];
        return;
    }

    // Durata prudente; NineAuth potrà fornire
    // nuovamente un token quando richiesto.
    NSDictionary *payload = @{
        @"access_token": token,
        @"expires_in": @300
    };

    NSData *data = [NSJSONSerialization
        dataWithJSONObject:payload options:0 error:nil];

    NSString *json = data
        ? [[NSString alloc] initWithData:data
                               encoding:NSUTF8StringEncoding]
        : nil;

    if (!json) {
        [self setStatus:@"Errore preparazione token"];
        return;
    }

    NSString *script = [NSString stringWithFormat:
        @"if (typeof window.externalAuthSetToken === 'function') "
         "window.externalAuthSetToken(true, %@);", json];

    [self.web evaluateJavaScript:script
               completionHandler:^(id result, NSError *jsError) {
        if (jsError) {
            [self setStatus:@"Callback JavaScript non riuscito"];
        } else {
            [self setStatus:
                @"Token consegnato · rendering iOS 9 sperimentale"];
        }
    }];
}

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![self isTrustedMessage:message]) {
        NSLog(@"NineHA WebView: origine bridge rifiutata");
        return;
    }

    NSDictionary *body =
        [message.body isKindOfClass:[NSDictionary class]]
        ? message.body : @{};

    if ([message.name isEqualToString:@"getExternalAuth"]) {
        if (![body[@"callback"]
                isEqualToString:@"externalAuthSetToken"]) return;

        [self setStatus:@"Richiesta token ricevuta..."];

        __weak typeof(self) weakSelf = self;

        NineAuthCompletion callback =
            ^(NSString *token, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf deliverToken:token error:error];
            });
        };

        if ([self.mode isEqualToString:@"oauth"]) {
            [self.auth useOAuthToken:callback];
        } else {
            [self.auth useManualToken:callback];
        }

    } else if ([message.name isEqualToString:@"revokeExternalAuth"]) {
        if (![body[@"callback"]
                isEqualToString:@"externalAuthRevokeToken"]) return;

        // Non cancelliamo il token condiviso con NineHA.
        [self.web evaluateJavaScript:
            @"if (typeof window.externalAuthRevokeToken === 'function')"
             " window.externalAuthRevokeToken(false);"
                 completionHandler:nil];
    }
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    [self setStatus:[NSString stringWithFormat:
        @"Errore caricamento (%ld)", (long)error.code]];
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    [self setStatus:[NSString stringWithFormat:
        @"Errore navigazione (%ld)", (long)error.code]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Lovelace originale · Unstable";

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Rebuilder"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(ninehaExitOriginalWebView)];
}

- (void)dealloc {
    [self.web.configuration.userContentController
        removeScriptMessageHandlerForName:@"getExternalAuth"];

    [self.web.configuration.userContentController
        removeScriptMessageHandlerForName:@"revokeExternalAuth"];
}

@end
