#import "NineDashboard.h"
#import "NineEntity.h"
#import "NineIcons.h"
#import "NineTheme.h"

@interface NineDashboard () <UISearchBarDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NineAuth *auth;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) NSArray *allStates;
@property (nonatomic, strong) NSArray *visibleStates;
@property (nonatomic, strong) NSMutableSet *favorites;
@property (nonatomic, strong) NSMutableSet *hiddenEntities;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UISegmentedControl *filter;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL loading;

@end

@implementation NineDashboard

- (instancetype)initWithAuth:(NineAuth *)auth
                        mode:(NSString *)mode {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _auth = auth;
        _mode = [mode copy];
        _allStates = @[];
        _visibleStates = @[];
        NSArray *saved = [[NSUserDefaults standardUserDefaults]
            arrayForKey:@"NineHA.Favorites"];
        _favorites = [NSMutableSet setWithArray:saved ?: @[]];
        NSArray *hidden = [[NSUserDefaults standardUserDefaults]
            arrayForKey:@"NineHA.HiddenEntities"];
        _hiddenEntities = [NSMutableSet setWithArray:hidden ?: @[]];
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

// Non inoltriamo mai il Bearer token attraverso redirect HTTP.
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Entità";

    self.navigationItem.rightBarButtonItem =
        NineIconBarItem(@"refresh", self, @selector(fetchStates));

    NTStyleTableView(self.tableView);
    self.tableView.rowHeight = 60;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;

    CGFloat width = self.view.bounds.size.width;

    UIView *header = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, width, 100)];
    header.backgroundColor = NTBackground();

    self.search = [[UISearchBar alloc]
        initWithFrame:CGRectMake(4, 4, width - 8, 48)];
    self.search.delegate = self;
    self.search.placeholder = @"Cerca entità";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    self.search.barStyle = UIBarStyleBlack;
    self.search.keyboardAppearance = UIKeyboardAppearanceDark;
    self.search.tintColor = NTPrimary();
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:self.search];

    self.filter = [[UISegmentedControl alloc]
        initWithItems:@[@"Tutte", @"Comandi", @"Preferiti", @"Nascoste"]];
    self.filter.frame = CGRectMake(12, 56, width - 24, 32);
    self.filter.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.filter.selectedSegmentIndex = 0;
    self.filter.tintColor = NTPrimary();
    [self.filter addTarget:self
                    action:@selector(applyFilter)
          forControlEvents:UIControlEventValueChanged];
    [header addSubview:self.filter];

    self.tableView.tableHeaderView = header;

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = NTSecondaryText();
    [refresh addTarget:self
                action:@selector(fetchStates)
      forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;

    [self createSession];
    [self fetchStates];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NTStyleNavigationBar(self.navigationController.navigationBar);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.timer invalidate];
    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:45
                               target:self
                             selector:@selector(fetchStates)
                             userInfo:nil
                              repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.timer invalidate];
    self.timer = nil;

    [self.session invalidateAndCancel];
    self.session = nil;
}

- (void)withToken:(NineAuthCompletion)completion {
    [self.auth useTokenForMode:self.mode completion:completion];
}

- (void)finishFetch:(NSArray *)states
            message:(NSString *)message {

    dispatch_async(dispatch_get_main_queue(), ^{
        self.loading = NO;
        [self.refreshControl endRefreshing];

        if (states) {
            self.allStates = [states sortedArrayUsingComparator:
                ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                    NSString *an = [self displayName:a];
                    NSString *bn = [self displayName:b];
                    return [an localizedCaseInsensitiveCompare:bn];
                }];
            [self applyFilter];
        }

        // Solo gli errori occupano la barra.
        self.navigationItem.prompt = message;
    });
}

- (void)fetchStates {
    if (self.loading) return;

    self.loading = YES;

    [self createSession];

    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) {
            [self finishFetch:nil message:
                error.localizedDescription ?: @"Token non disponibile"];
            return;
        }

        NSString *urlString =
            [self.auth.serverURL stringByAppendingString:@"/api/states"];

        NSMutableURLRequest *req = [NSMutableURLRequest
            requestWithURL:[NSURL URLWithString:urlString]];

        [req setValue:[@"Bearer " stringByAppendingString:token]
  forHTTPHeaderField:@"Authorization"];
        [req setValue:@"application/json"
  forHTTPHeaderField:@"Accept"];

        [[self.session dataTaskWithRequest:req
          completionHandler:^(NSData *data, NSURLResponse *response,
                              NSError *networkError) {

            if (networkError) {
                [self finishFetch:nil
                          message:networkError.localizedDescription];
                return;
            }

            NSInteger status =
                [(NSHTTPURLResponse *)response statusCode];

            if (status != 200) {
                [self finishFetch:nil message:
                    [NSString stringWithFormat:
                        @"Errore HTTP %ld", (long)status]];
                return;
            }

            NSError *parseError = nil;
            id json = [NSJSONSerialization
                JSONObjectWithData:data ?: [NSData data]
                           options:0
                             error:&parseError];

            if (![json isKindOfClass:[NSArray class]]) {
                [self finishFetch:nil
                          message:@"Risposta JSON non valida"];
                return;
            }

            NSArray *states = (NSArray *)json;

            [self finishFetch:states message:nil];

        }] resume];
    }];
}


- (NSString *)displayName:(NSDictionary *)entity {
    NSDictionary *attributes = entity[@"attributes"];
    NSString *name = nil;

    if ([attributes isKindOfClass:[NSDictionary class]]) {
        id friendly = attributes[@"friendly_name"];
        if ([friendly isKindOfClass:[NSString class]]) {
            name = friendly;
        }
    }

    if (!name.length) {
        id entityID = entity[@"entity_id"];
        if ([entityID isKindOfClass:[NSString class]]) {
            name = entityID;
        }
    }

    return name ?: @"Entità";
}

- (void)applyFilter {
    NSString *query = [self.search.text lowercaseString] ?: @"";
    NSInteger filter = self.filter.selectedSegmentIndex;

    NSMutableArray *results = [NSMutableArray array];

    for (id item in self.allStates) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSDictionary *entity = item;
        NSString *entityID = entity[@"entity_id"];

        if (![entityID isKindOfClass:[NSString class]]) continue;

        BOOL command = NEIsToggleable(entity);

        BOOL hidden = [self.hiddenEntities containsObject:entityID];

        if (filter == 3) {
            if (!hidden) continue;
        } else if (hidden) {
            continue;
        }

        if (filter == 1 && !command) continue;
        if (filter == 2 && ![self.favorites containsObject:entityID])
            continue;

        if (query.length &&
            [[self displayName:entity].lowercaseString
                rangeOfString:query].location == NSNotFound &&
            [entityID.lowercaseString
                rangeOfString:query].location == NSNotFound) {
            continue;
        }

        [results addObject:entity];
    }

    self.visibleStates = results;
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText {
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.visibleStates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *reuseID = @"NineEntityCell";
    static NSInteger const iconTag = 9001;

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:reuseID];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:reuseID];
        NTStyleCell(cell);
        cell.backgroundColor = NTBackground();
        cell.indentationLevel = 1;
        cell.indentationWidth = 46;
        cell.textLabel.font = NTMediumFont(15);
        cell.detailTextLabel.font = NTFont(12);

        UIView *circle = [[UIView alloc]
            initWithFrame:CGRectMake(12, 12, 36, 36)];
        circle.layer.cornerRadius = 18;
        circle.tag = iconTag;
        NineIconView *icon = [[NineIconView alloc]
            initWithFrame:circle.bounds iconSize:22];
        [circle addSubview:icon];
        [cell.contentView addSubview:circle];
    }

    NSDictionary *entity = self.visibleStates[indexPath.row];
    NSString *entityID = entity[@"entity_id"];

    UIView *circle = [cell.contentView viewWithTag:iconTag];
    NineIconView *icon = circle.subviews.firstObject;
    UIColor *color = NEIconColor(entity);
    icon.iconName = NEIconName(entity, nil);
    icon.textColor = color;
    circle.backgroundColor = [color colorWithAlphaComponent:.2f];

    cell.textLabel.text = NEName(entity, nil);
    cell.detailTextLabel.text = [NSString stringWithFormat:
        @"%@  ·  %@", NEStateText(entity, nil), entityID];

    BOOL favorite = [self.favorites containsObject:entityID];
    if (favorite) {
        NineIconView *star = [[NineIconView alloc]
            initWithFrame:CGRectMake(0, 0, 24, 24) iconSize:18];
        star.iconName = @"star";
        star.textColor = NTHex(0xFFC107, 1);
        cell.accessoryView = star;
    } else {
        cell.accessoryView = nil;
    }

    return cell;
}

- (void)saveFavorites {
    NSArray *ids = [[self.favorites allObjects]
        sortedArrayUsingSelector:@selector(compare:)];

    [[NSUserDefaults standardUserDefaults]
        setObject:ids forKey:@"NineHA.Favorites"];
}

- (void)saveHiddenEntities {
    NSArray *ids = [[self.hiddenEntities allObjects]
        sortedArrayUsingSelector:@selector(compare:)];

    [[NSUserDefaults standardUserDefaults]
        setObject:ids forKey:@"NineHA.HiddenEntities"];
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

- (void)callService:(NSString *)service
             domain:(NSString *)domain
           entityID:(NSString *)entityID {

    // Solo domini e servizi esplicitamente consentiti.
    NSSet *allowedDomains = [NSSet setWithArray:
        @[@"light", @"switch", @"input_boolean", @"fan"]];

    if (![allowedDomains containsObject:domain] ||
        ![@[@"turn_on", @"turn_off"] containsObject:service]) {
        return;
    }

    [self withToken:^(NSString *token, NSError *error) {
        if (error || !token.length) {
            [self showError:error.localizedDescription
                ?: @"Token non disponibile"];
            return;
        }

        NSString *path = [NSString stringWithFormat:
            @"/api/services/%@/%@", domain, service];

        NSURL *url = [NSURL URLWithString:
            [self.auth.serverURL stringByAppendingString:path]];

        NSMutableURLRequest *req =
            [NSMutableURLRequest requestWithURL:url];

        req.HTTPMethod = @"POST";
        [req setValue:[@"Bearer " stringByAppendingString:token]
  forHTTPHeaderField:@"Authorization"];
        [req setValue:@"application/json"
  forHTTPHeaderField:@"Content-Type"];

        NSError *jsonError = nil;
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:
            @{@"entity_id": entityID}
                       options:0
                         error:&jsonError];

        if (jsonError || !req.HTTPBody) {
            [self showError:@"Errore preparazione comando"];
            return;
        }

        [self createSession];

        [[self.session dataTaskWithRequest:req
          completionHandler:^(NSData *data, NSURLResponse *response,
                              NSError *networkError) {

            if (networkError) {
                [self showError:networkError.localizedDescription];
                return;
            }

            NSInteger status =
                [(NSHTTPURLResponse *)response statusCode];

            if (status != 200 && status != 201) {
                [self showError:[NSString stringWithFormat:
                    @"Comando non riuscito: HTTP %ld",
                    (long)status]];
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self fetchStates];
            });

        }] resume];
    }];
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *entity = self.visibleStates[indexPath.row];
    NSString *entityID = entity[@"entity_id"];
    NSString *state = [entity[@"state"] description];
    NSString *name = [self displayName:entity];

    NSString *domain =
        [[entityID componentsSeparatedByString:@"."] firstObject];

    UIAlertController *menu = [UIAlertController
        alertControllerWithTitle:name
                         message:[NSString stringWithFormat:
                            @"%@\nStato: %@",
                            entityID, state ?: @"N/D"]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL favorite = [self.favorites containsObject:entityID];

    [menu addAction:[UIAlertAction
        actionWithTitle:favorite
            ? @"Rimuovi dai preferiti"
            : @"Aggiungi ai preferiti"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        if (favorite) {
            [self.favorites removeObject:entityID];
        } else {
            [self.favorites addObject:entityID];
        }

        [self saveFavorites];
        [self applyFilter];
    }]];

    BOOL hidden = [self.hiddenEntities containsObject:entityID];

    [menu addAction:[UIAlertAction
        actionWithTitle:hidden
            ? @"Mostra nella Home"
            : @"Nascondi dalla Home"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

        if (hidden) {
            [self.hiddenEntities removeObject:entityID];
        } else {
            [self.hiddenEntities addObject:entityID];
            [self.favorites removeObject:entityID];
            [self saveFavorites];
        }

        [self saveHiddenEntities];
        [self applyFilter];
    }]];

    BOOL controllable = NEIsToggleable(entity);

    BOOL available =
        ![state isEqualToString:@"unknown"] &&
        ![state isEqualToString:@"unavailable"];

    if (controllable && available) {
        BOOL on = [state isEqualToString:@"on"];
        NSString *service = on ? @"turn_off" : @"turn_on";

        [menu addAction:[UIAlertAction
            actionWithTitle:on ? @"Spegni" : @"Accendi"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
            [self callService:service
                       domain:domain
                     entityID:entityID];
        }]];
    }

    [menu addAction:[UIAlertAction
        actionWithTitle:@"Annulla"
                  style:UIAlertActionStyleCancel
                handler:nil]];

    // Necessario per gli Action Sheet su iPad.
    UIPopoverPresentationController *popover =
        menu.popoverPresentationController;

    if (popover) {
        popover.sourceView = tableView;
        popover.sourceRect =
            [tableView rectForRowAtIndexPath:indexPath];
    }

    [self presentViewController:menu animated:YES completion:nil];
}

@end
