#import "NineRefreshSettingsController.h"
#import "NineTheme.h"

NSString *const NineRefreshSettingsChangedNotification =
    @"NineHA.RefreshSettingsChanged";

static NSArray *NineRefreshIntervals(void) {
    return @[@0, @15, @45, @120, @300];
}

static NSString *NineRefreshKey(NSString *serverURL) {
    // Chiave delle versioni precedenti: la scelta resta valida.
    return [@"NineHA.Unstable.Refresh.Entities."
        stringByAppendingString:serverURL ?: @""];
}

static NSString *NineRefreshLabel(NSInteger seconds) {
    switch (seconds) {
        case 0:   return @"Live (consigliato)";
        case 15:  return @"Ogni 15 secondi";
        case 45:  return @"Ogni 45 secondi";
        case 120: return @"Ogni 2 minuti";
        case 300: return @"Ogni 5 minuti";
        default:  return @"Live";
    }
}

@interface NineRefreshSettingsController ()
@property (nonatomic, copy) NSString *serverURL;
@end

@implementation NineRefreshSettingsController

+ (NSInteger)entityIntervalForServerURL:(NSString *)serverURL {
    id saved = [[NSUserDefaults standardUserDefaults]
        objectForKey:NineRefreshKey(serverURL)];

    if ([saved isKindOfClass:[NSNumber class]] &&
        [NineRefreshIntervals() containsObject:saved]) {
        return [saved integerValue];
    }

    return 0;
}

- (instancetype)initWithServerURL:(NSString *)serverURL {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) _serverURL = [serverURL copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Aggiornamenti";
    NTStyleTableView(self.tableView);
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return NineRefreshIntervals().count;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    return @"Aggiornamento delle entità";
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section {
    return @"Live riceve i cambi di stato in tempo reale tramite "
           "WebSocket, con lettura periodica di riserva. "
           "Gli intervalli fissi riducono il traffico di rete.";
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
        NTStyleCell(cell);
    }

    NSInteger seconds = [NineRefreshIntervals()[indexPath.row] integerValue];
    NSInteger current = [[self class] entityIntervalForServerURL:self.serverURL];

    cell.textLabel.text = NineRefreshLabel(seconds);
    cell.accessoryType = seconds == current
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSInteger seconds = [NineRefreshIntervals()[indexPath.row] integerValue];

    [[NSUserDefaults standardUserDefaults]
        setInteger:seconds forKey:NineRefreshKey(self.serverURL)];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:NineRefreshSettingsChangedNotification
                      object:nil];

    [tableView reloadData];
}

@end
