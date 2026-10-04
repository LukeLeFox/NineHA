#import "NineDashboard.h"

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

    NSString *version = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    self.title = [NSString stringWithFormat:
                  @"NineHA %@", version ?: @""];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
         initWithTitle:@"Dashboard"
                 style:UIBarButtonItemStylePlain
                target:self
                action:@selector(goBack)];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
         initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                            target:self
                            action:@selector(fetchStates)];

    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor =
        [UIColor colorWithWhite:0.17 alpha:1];
    self.tableView.rowHeight = 65;
    self.tableView.tableFooterView = [[UIView alloc] init];

    CGFloat width = self.view.bounds.size.width;

    UIView *header = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, width, 94)];
    header.backgroundColor = [UIColor blackColor];

    self.search = [[UISearchBar alloc]
        initWithFrame:CGRectMake(0, 0, width, 48)];
    self.search.delegate = self;
    self.search.placeholder = @"Cerca nome o entity_id";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    self.search.barStyle = UIBarStyleBlack;
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:self.search];

    self.filter = [[UISegmentedControl alloc]
        initWithItems:@[@"Home", @"Tutte", @"Comandi", @"Nascoste"]];
    self.filter.frame = CGRectMake(8, 52, width - 16, 34);
    self.filter.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.filter.selectedSegmentIndex = 0;
    self.filter.tintColor =
        [UIColor colorWithRed:0.12 green:0.61 blue:0.87 alpha:1];
    [self.filter addTarget:self
                    action:@selector(applyFilter)
          forControlEvents:UIControlEventValueChanged];
    [header addSubview:self.filter];

    self.tableView.tableHeaderView = header;

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self
                action:@selector(fetchStates)
      forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;

    [self createSession];
    [self fetchStates];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationController.navigationBar.barStyle =
        UIBarStyleBlack;
    self.navigationController.navigationBar.barTintColor =
        [UIColor blackColor];
    self.navigationController.navigationBar.tintColor =
        [UIColor whiteColor];
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

    self.navigationController.navigationBar.barStyle =
        UIBarStyleDefault;
    self.navigationController.navigationBar.barTintColor = nil;
    self.navigationController.navigationBar.tintColor = nil;
}

- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)withToken:(NineAuthCompletion)completion {
    if ([self.mode isEqualToString:@"oauth"]) {
        [self.auth useOAuthToken:completion];
    } else {
        [self.auth useManualToken:completion];
    }
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

        self.navigationItem.prompt = message;
    });
}

- (void)fetchStates {
    if (self.loading) return;

    self.loading = YES;
    self.navigationItem.prompt = @"Aggiornamento entità...";

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

            [self finishFetch:states message:
                [NSString stringWithFormat:
                    @"%lu entità · aggiornate",
                    (unsigned long)states.count]];

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

        BOOL command =
            [entityID hasPrefix:@"light."] ||
            [entityID hasPrefix:@"switch."] ||
            [entityID hasPrefix:@"input_boolean."];

        BOOL hidden = [self.hiddenEntities containsObject:entityID];

        if (filter == 3) {
            if (!hidden) continue;
        } else if (hidden) {
            continue;
        }

        // Home: preferiti, oppure comandi finche' non ne esistono.
        if (filter == 0) {
            if (self.favorites.count > 0) {
                if (![self.favorites containsObject:entityID])
                    continue;
            } else if (!command) {
                continue;
            }
        }

        if (filter == 2 && !command) continue;

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

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:reuseID];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:reuseID];
    }

    NSDictionary *entity = self.visibleStates[indexPath.row];
    NSString *entityID = entity[@"entity_id"];
    NSString *state = [entity[@"state"] description];

    NSDictionary *attrs = entity[@"attributes"];
    NSString *unit = nil;
    if ([attrs isKindOfClass:[NSDictionary class]]) {
        id value = attrs[@"unit_of_measurement"];
        if ([value isKindOfClass:[NSString class]]) unit = value;
    }

    BOOL favorite = [self.favorites containsObject:entityID];

    cell.textLabel.text = [NSString stringWithFormat:@"%@%@",
        favorite ? @"★ " : @"", [self displayName:entity]];

    cell.detailTextLabel.text = [NSString stringWithFormat:
        @"%@  ·  %@%@",
        entityID,
        state ?: @"N/D",
        unit.length ? [@" " stringByAppendingString:unit] : @""];

    cell.backgroundColor =
        [UIColor colorWithWhite:0.07 alpha:1];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

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
        @[@"light", @"switch", @"input_boolean"]];

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

        self.navigationItem.prompt = @"Invio comando...";

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
            : @"★ Aggiungi ai preferiti"
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
            ? @"Mostra entita'"
            : @"Nascondi entita'"
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

    BOOL controllable =
        [@[@"light", @"switch", @"input_boolean"]
            containsObject:domain];

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
