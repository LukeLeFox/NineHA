#import "NineUnstableSettingsController.h"

static NSArray *NHARefreshIntervals(void) {
    return @[@0, @15, @45, @120, @300];
}

static NSString *NHARefreshKey(NSInteger group,
                               NSString *serverURL) {
    NSString *kind = group == 0
        ? @"WeatherClock" : @"Entities";

    return [NSString stringWithFormat:
        @"NineHA.Unstable.Refresh.%@.%@",
        kind, serverURL ?: @""];
}

static NSString *NHARefreshLabel(NSInteger seconds) {
    switch (seconds) {
        case 0:   return @"Live";
        case 15:  return @"15 s";
        case 45:  return @"45 s";
        case 120: return @"2 min";
        case 300: return @"5 min";
        default:  return @"45 s";
    }
}

@interface NineUnstableSettingsController ()

@property (nonatomic, copy) NSString *serverURL;

@end

@implementation NineUnstableSettingsController

#pragma mark - Startup preference

+ (NSString *)startupModeForServerURL:(NSString *)serverURL {
    NSString *server = serverURL ?: @"";
    NSUserDefaults *prefs =
        [NSUserDefaults standardUserDefaults];

    NSString *key = [@"NineHA.StartupMode."
        stringByAppendingString:server];

    id value = [prefs objectForKey:key];

    NSArray *allowed =
        @[@"native", @"rebuilder", @"original"];

    if ([value isKindOfClass:[NSString class]] &&
        [allowed containsObject:value]) {
        return value;
    }

    // Compatibilità con la vecchia opzione booleana.
    NSString *legacyKey =
        [@"NineHA.LovelaceStartup."
            stringByAppendingString:server];

    id legacy = [prefs objectForKey:legacyKey];

    if ([legacy isKindOfClass:[NSNumber class]]) {
        return [legacy boolValue]
            ? @"rebuilder" : @"native";
    }

    return @"rebuilder";
}

+ (void)setStartupMode:(NSString *)mode
              serverURL:(NSString *)serverURL {

    if (![@[@"native", @"rebuilder", @"original"]
            containsObject:mode]) {
        return;
    }

    NSString *key =
        [@"NineHA.StartupMode."
            stringByAppendingString:serverURL ?: @""];

    [[NSUserDefaults standardUserDefaults]
        setObject:mode forKey:key];
}


- (instancetype)initWithServerURL:(NSString *)serverURL {
    self = [super initWithStyle:UITableViewStyleGrouped];

    if (self) {
        _serverURL = [serverURL copy];
    }

    return self;
}

+ (NSInteger)intervalForGroup:(NSInteger)group
                    serverURL:(NSString *)serverURL {

    NSString *key = NHARefreshKey(group, serverURL);

    id saved = [[NSUserDefaults standardUserDefaults]
        objectForKey:key];

    if (![saved isKindOfClass:[NSNumber class]]) {
        return 45;
    }

    NSInteger value = [saved integerValue];

    if ([NHARefreshIntervals() containsObject:@(value)]) {
        return value;
    }

    return 45;
}

+ (NSString *)summaryForServerURL:(NSString *)serverURL {
    NSInteger weather =
        [self intervalForGroup:0 serverURL:serverURL];

    NSInteger entities =
        [self intervalForGroup:1 serverURL:serverURL];

    return [NSString stringWithFormat:
        @"Meteo %@ · Card %@",
        NHARefreshLabel(weather),
        NHARefreshLabel(entities)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Aggiornamenti";
    self.tableView.tableFooterView = [[UIView alloc] init];
}

- (NSInteger)numberOfSectionsInTableView:
    (UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return section == 2 ? 3 : NHARefreshIntervals().count;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    if (section == 2)
        return @"Schermata all'avvio";

    return section == 0
        ? @"Meteo e orologi" : @"Card ed entità";
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return @"La scelta sarà usata al prossimo avvio. "
               "La Lovelace originale potrebbe bloccarsi "
               "su iOS 9: usa Rebuilder per tornare indietro.";
    }

    if (section == 0) {
        return @"L'orologio locale continua a segnare "
               "l'ora corretta indipendentemente dalla "
               "frequenza di rete.";
    }

    return @"Live utilizza eventi WebSocket. "
           "Le altre modalità utilizzano intervalli "
           "periodici di aggiornamento.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *reuse = @"NineRefreshOption";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:reuse];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleDefault
          reuseIdentifier:reuse];
    }


    if (indexPath.section == 2) {
        NSArray *values =
            @[@"native", @"rebuilder", @"original"];

        NSArray *names = @[
            @"NineHA nativa",
            @"Lovelace Rebuilder",
            @"Lovelace originale (unstable)"
        ];

        NSString *selected = [[self class]
            startupModeForServerURL:self.serverURL];

        cell.textLabel.text = names[indexPath.row];

        cell.accessoryType =
            [selected isEqualToString:values[indexPath.row]]
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;

        return cell;
    }

    NSInteger seconds =
        [NHARefreshIntervals()[indexPath.row] integerValue];

    NSInteger current =
        [[self class] intervalForGroup:indexPath.section
                             serverURL:self.serverURL];

    cell.textLabel.text = NHARefreshLabel(seconds);

    cell.accessoryType = seconds == current
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath
                            animated:YES];


    if (indexPath.section == 2) {
        NSArray *values =
            @[@"native", @"rebuilder", @"original"];

        [[self class]
            setStartupMode:values[indexPath.row]
                 serverURL:self.serverURL];

        [tableView reloadSections:
            [NSIndexSet indexSetWithIndex:2]
                withRowAnimation:UITableViewRowAnimationNone];
        return;
    }

    NSInteger seconds =
        [NHARefreshIntervals()[indexPath.row] integerValue];

    NSString *key =
        NHARefreshKey(indexPath.section, self.serverURL);

    [[NSUserDefaults standardUserDefaults]
        setInteger:seconds forKey:key];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"NineHA.UnstableRefreshChanged"
                      object:nil
                    userInfo:@{
        @"serverURL": self.serverURL ?: @""
    }];

    [tableView reloadSections:
        [NSIndexSet indexSetWithIndex:indexPath.section]
            withRowAnimation:UITableViewRowAnimationNone];
}

@end
