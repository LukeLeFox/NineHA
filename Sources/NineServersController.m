#import "NineServersController.h"

@implementation NineServersController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Server";
    self.tableView.tableFooterView = [[UIView alloc] init];
}

- (NSArray *)profiles {
    id profiles = [[NSUserDefaults standardUserDefaults]
        arrayForKey:@"NineHA.Servers"];

    if (![profiles isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *valid = [NSMutableArray array];

    for (id item in profiles) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSString *url = item[@"url"];
        if ([url isKindOfClass:[NSString class]] && url.length) {
            [valid addObject:item];
        }
    }

    return valid;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {

    return section == 2 ? 1 : [self profiles].count;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {

    if (section == 0) return @"Collegati a";
    if (section == 1) return @"Predefinito all'avvio";
    return @"Gestione";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *identifier = @"ServerCell";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:identifier];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];

    if (indexPath.section == 2) {
        cell.textLabel.text = @"＋ Aggiungi server";
        cell.detailTextLabel.text = @"Configura URL e autenticazione";
        return cell;
    }

    NSDictionary *profile = [self profiles][indexPath.row];
    NSString *url = profile[@"url"];

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    NSString *active = [defaults stringForKey:@"NineHA.Server"];
    NSString *preferred =
        [defaults stringForKey:@"NineHA.DefaultServer"];

    cell.textLabel.text = url;

    if (indexPath.section == 0) {
        BOOL selected = [active isEqualToString:url];

        cell.detailTextLabel.text = selected
            ? @"Server attualmente utilizzato"
            : @"Tocca per collegarti";

        cell.accessoryType = selected
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
    } else {
        BOOL selected = [preferred isEqualToString:url];

        cell.detailTextLabel.text = selected
            ? @"Predefinito"
            : @"Tocca per impostare come predefinito";

        cell.accessoryType = selected
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 2) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"NineHA.ServerAction"
                          object:nil
                        userInfo:@{@"action": @"add"}];
        return;
    }

    NSArray *profiles = [self profiles];
    if (indexPath.row >= (NSInteger)profiles.count) return;

    NSDictionary *profile = profiles[indexPath.row];
    NSString *url = profile[@"url"];

    if (indexPath.section == 1) {
        [[NSUserDefaults standardUserDefaults]
            setObject:url forKey:@"NineHA.DefaultServer"];

        [self.tableView reloadData];
        return;
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"NineHA.ServerAction"
                      object:nil
                    userInfo:@{
        @"action": @"switch",
        @"profile": profile
    }];
}

@end
