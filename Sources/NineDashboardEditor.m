#import "NineDashboardEditor.h"
#import "NineCustomDashboards.h"
#import "NineEntity.h"
#import "NineIcons.h"
#import "NineTheme.h"

static NSInteger const NineEditorIconTag = 7101;

// Cella con icona MDI nel cerchio colorato, come nei tile.
static UITableViewCell *NineEditorEntityCell(UITableView *tableView,
                                             NSDictionary *entity,
                                             NSDictionary *registry,
                                             NSString *entityID) {
    static NSString *reuse = @"NineEditorEntity";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:reuse];
        NTStyleCell(cell);
        cell.indentationLevel = 1;
        cell.indentationWidth = 44;
        cell.textLabel.font = NTMediumFont(15);
        cell.detailTextLabel.font = NTFont(12);

        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 34, 34)];
        circle.layer.cornerRadius = 17;
        circle.tag = NineEditorIconTag;
        NineIconView *icon = [[NineIconView alloc] initWithFrame:circle.bounds
                                                         iconSize:20];
        [circle addSubview:icon];
        [cell.contentView addSubview:circle];
    }

    UIView *circle = [cell.contentView viewWithTag:NineEditorIconTag];
    NineIconView *icon = circle.subviews.firstObject;

    if (entity) {
        UIColor *color = NEIconColor(entity);
        icon.iconName = NEIconName(entity, registry);
        icon.textColor = color;
        circle.backgroundColor = [color colorWithAlphaComponent:.2f];
        cell.textLabel.text = NEName(entity, registry);
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@",
            NEStateText(entity, registry), entityID];
    } else {
        icon.iconName = @"help-circle-outline";
        icon.textColor = NTDisabledText();
        circle.backgroundColor = [NTDisabledText() colorWithAlphaComponent:.2f];
        cell.textLabel.text = entityID;
        cell.detailTextLabel.text = @"Entità non trovata";
    }

    return cell;
}

#pragma mark - Editor

@interface NineDashboardEditor ()
@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *dashboardID;
@property (nonatomic, strong) NSDictionary *stateByID;
@property (nonatomic, strong) NSDictionary *registry;
@property (nonatomic, strong) NSMutableDictionary *dashboard;
@end

@implementation NineDashboardEditor

- (instancetype)initWithServerURL:(NSString *)serverURL
                      dashboardID:(NSString *)dashboardID
                           states:(NSDictionary *)stateByID
                         registry:(NSDictionary *)registry {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _serverURL = [serverURL copy];
        _dashboardID = [dashboardID copy];
        _stateByID = [stateByID copy] ?: @{};
        _registry = registry ?: @{};
        [self reload];
    }
    return self;
}

- (void)reload {
    NSDictionary *stored = [NineCustomDashboards dashboardWithID:self.dashboardID
                                                          server:self.serverURL];
    self.dashboard = [stored mutableCopy];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Modifica dashboard";
    NTStyleTableView(self.tableView);
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.rowHeight = 54;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
    [self.tableView reloadData];
}

- (NSMutableArray *)sections {
    return [self.dashboard[@"sections"] mutableCopy] ?: [NSMutableArray array];
}

- (void)saveSections:(NSArray *)sections {
    self.dashboard[@"sections"] = sections;
    [NineCustomDashboards saveDashboard:self.dashboard server:self.serverURL];
}

- (NSInteger)dashboardSectionCount {
    return [self.dashboard[@"sections"] count];
}

- (BOOL)isDashboardSection:(NSInteger)section {
    return section >= 1 && section <= [self dashboardSectionCount];
}

- (NSArray *)itemsInTableSection:(NSInteger)section {
    return self.dashboard[@"sections"][section - 1][@"items"] ?: @[];
}

#pragma mark Struttura

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.dashboard) return 0;
    return [self dashboardSectionCount] + 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if ([self isDashboardSection:section])
        return [self itemsInTableSection:section].count + 2;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Dashboard";
    if ([self isDashboardSection:section]) {
        return [NSString stringWithFormat:@"Sezione %ld", (long)section];
    }
    return @"Gestione";
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"La dashboard è salvata su questo dispositivo e compare "
               "nel menu laterale.";
    }
    if (section == [self dashboardSectionCount]) {
        return @"Trascina le entità per riordinarle, anche tra sezioni diverse.";
    }
    return nil;
}

- (UITableViewCell *)plainCell:(UITableView *)tableView {
    static NSString *reuse = @"NineEditorPlain";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:reuse];
        NTStyleCell(cell);
    }
    cell.textLabel.textColor = NTText();
    cell.textLabel.font = NTFont(16);
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.editingAccessoryType = UITableViewCellAccessoryNone;
    cell.editingAccessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    if (section == 0) {
        UITableViewCell *cell = [self plainCell:tableView];
        if (row == 0) {
            cell.textLabel.text = @"Nome";
            cell.detailTextLabel.text = self.dashboard[@"name"];
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = @"Mostra all'avvio";
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = [[NineCustomDashboards
                startDashboardIDForServer:self.serverURL]
                    isEqualToString:self.dashboardID];
            [toggle addTarget:self action:@selector(startChanged:)
             forControlEvents:UIControlEventValueChanged];
            cell.editingAccessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return cell;
    }

    if ([self isDashboardSection:section]) {
        NSArray *items = [self itemsInTableSection:section];

        if (row == 0) {
            UITableViewCell *cell = [self plainCell:tableView];
            NSString *title = self.dashboard[@"sections"][section - 1][@"title"];
            cell.textLabel.text = @"Titolo";
            cell.detailTextLabel.text = [title length] ? title : @"Nessun titolo";
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }

        if (row == (NSInteger)items.count + 1) {
            UITableViewCell *cell = [self plainCell:tableView];
            cell.textLabel.text = @"Aggiungi entità…";
            cell.textLabel.textColor = NTPrimary();
            return cell;
        }

        NSString *entityID = items[row - 1];
        return NineEditorEntityCell(tableView, self.stateByID[entityID],
                                    self.registry[entityID], entityID);
    }

    UITableViewCell *cell = [self plainCell:tableView];
    if (row == 0) {
        cell.textLabel.text = @"Aggiungi sezione";
        cell.textLabel.textColor = NTPrimary();
    } else {
        cell.textLabel.text = @"Elimina dashboard";
        cell.textLabel.textColor = NTHex(0xFF6E60, 1);
    }
    return cell;
}

#pragma mark Modifica

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self isDashboardSection:indexPath.section])
        return UITableViewCellEditingStyleNone;

    NSInteger count = [self itemsInTableSection:indexPath.section].count;

    if (indexPath.row == count + 1) return UITableViewCellEditingStyleInsert;
    if (indexPath.row == 0) {
        return [self dashboardSectionCount] > 1
            ? UITableViewCellEditingStyleDelete
            : UITableViewCellEditingStyleNone;
    }
    return UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)tableView
shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self isDashboardSection:indexPath.section];
}

- (NSString *)tableView:(UITableView *)tableView
titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row == 0 ? @"Elimina sezione" : @"Rimuovi";
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleInsert) {
        [self addEntitiesToSection:indexPath.section];
        return;
    }
    if (style != UITableViewCellEditingStyleDelete) return;

    NSMutableArray *sections = [self sections];
    NSInteger index = indexPath.section - 1;

    if (indexPath.row == 0) {
        [sections removeObjectAtIndex:index];
        [self saveSections:sections];
        [tableView reloadData];
        return;
    }

    NSMutableDictionary *section = [sections[index] mutableCopy];
    NSMutableArray *items = [section[@"items"] mutableCopy];
    [items removeObjectAtIndex:indexPath.row - 1];
    section[@"items"] = items;
    sections[index] = section;
    [self saveSections:sections];

    [tableView deleteRowsAtIndexPaths:@[indexPath]
                     withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self isDashboardSection:indexPath.section]) return NO;
    NSInteger count = [self itemsInTableSection:indexPath.section].count;
    return indexPath.row >= 1 && indexPath.row <= count;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source
       toProposedIndexPath:(NSIndexPath *)proposed {
    NSInteger section = proposed.section;
    NSInteger last = [self dashboardSectionCount];

    if (section < 1) return [NSIndexPath indexPathForRow:1 inSection:1];
    if (section > last) {
        NSInteger count = [self itemsInTableSection:last].count;
        // Nella stessa sezione l'ultima posizione utile è "count".
        NSInteger row = source.section == last ? count : count + 1;
        return [NSIndexPath indexPathForRow:MAX(1, row) inSection:last];
    }

    NSInteger count = [self itemsInTableSection:section].count;
    NSInteger maximum = source.section == section ? count : count + 1;
    NSInteger row = MAX(1, MIN(maximum, proposed.row));
    return [NSIndexPath indexPathForRow:row inSection:section];
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)from
      toIndexPath:(NSIndexPath *)to {
    NSMutableArray *sections = [self sections];

    NSMutableDictionary *source = [sections[from.section - 1] mutableCopy];
    NSMutableArray *sourceItems = [source[@"items"] mutableCopy];
    NSString *entityID = sourceItems[from.row - 1];
    [sourceItems removeObjectAtIndex:from.row - 1];
    source[@"items"] = sourceItems;
    sections[from.section - 1] = source;

    NSMutableDictionary *target = [sections[to.section - 1] mutableCopy];
    NSMutableArray *targetItems = [target[@"items"] mutableCopy];
    NSInteger position = MIN((NSInteger)targetItems.count, to.row - 1);
    [targetItems insertObject:entityID atIndex:MAX(0, position)];
    target[@"items"] = targetItems;
    sections[to.section - 1] = target;

    [self saveSections:sections];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    if (section == 0 && row == 0) {
        [self askText:@"Nome della dashboard"
              current:self.dashboard[@"name"]
           completion:^(NSString *text) {
            if (!text.length) return;
            self.dashboard[@"name"] = text;
            [NineCustomDashboards saveDashboard:self.dashboard server:self.serverURL];
            [self.tableView reloadData];
        }];
        return;
    }

    if ([self isDashboardSection:section]) {
        NSInteger count = [self itemsInTableSection:section].count;

        if (row == 0) {
            NSString *current = self.dashboard[@"sections"][section - 1][@"title"];
            [self askText:@"Titolo della sezione"
                  current:current
               completion:^(NSString *text) {
                NSMutableArray *sections = [self sections];
                NSMutableDictionary *edited = [sections[section - 1] mutableCopy];
                edited[@"title"] = text ?: @"";
                sections[section - 1] = edited;
                [self saveSections:sections];
                [self.tableView reloadData];
            }];
        } else if (row == count + 1) {
            [self addEntitiesToSection:section];
        }
        return;
    }

    if (section == [self dashboardSectionCount] + 1) {
        if (row == 0) {
            NSMutableArray *sections = [self sections];
            [sections addObject:@{@"title": @"", @"items": @[]}];
            [self saveSections:sections];
            [self.tableView reloadData];
        } else {
            [self confirmDelete];
        }
    }
}

- (void)addEntitiesToSection:(NSInteger)section {
    NSArray *current = [self itemsInTableSection:section];
    __weak typeof(self) weakSelf = self;

    NineEntityPicker *picker = [[NineEntityPicker alloc]
        initWithStates:self.stateByID
              registry:self.registry
              selected:current
            completion:^(NSArray *selected) {
        NineDashboardEditor *owner = weakSelf;
        if (!owner) return;

        NSMutableArray *sections = [owner sections];
        if (section - 1 >= (NSInteger)sections.count) return;

        // Un'entità compare una sola volta nella dashboard.
        for (NSUInteger i = 0; i < sections.count; i++) {
            if ((NSInteger)i == section - 1) continue;
            NSMutableDictionary *other = [sections[i] mutableCopy];
            NSMutableArray *items = [other[@"items"] mutableCopy];
            [items removeObjectsInArray:selected];
            other[@"items"] = items;
            sections[i] = other;
        }

        NSMutableDictionary *edited = [sections[section - 1] mutableCopy];
        edited[@"items"] = selected;
        sections[section - 1] = edited;
        [owner saveSections:sections];
        [owner.tableView reloadData];
    }];

    [self.navigationController pushViewController:picker animated:YES];
}

#ifdef NINEHA_DEBUG_HOOKS
- (void)debugOpenPicker {
    [self addEntitiesToSection:1];
}
#endif

- (void)startChanged:(UISwitch *)toggle {
    [NineCustomDashboards setStartDashboardID:toggle.on ? self.dashboardID : nil
                                       server:self.serverURL];
}

- (void)confirmDelete {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Eliminare la dashboard?"
                         message:self.dashboard[@"name"]
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Elimina"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [NineCustomDashboards deleteDashboardWithID:self.dashboardID
                                             server:self.serverURL];
        [self.navigationController popViewControllerAnimated:YES];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)askText:(NSString *)title
        current:(NSString *)current
     completion:(void (^)(NSString *text))completion {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
                         message:nil
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = current;
        field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Annulla"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Salva"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *text = [alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        completion(text ?: @"");
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Selettore entità

@interface NineEntityPicker () <UISearchBarDelegate>
@property (nonatomic, strong) NSDictionary *stateByID;
@property (nonatomic, strong) NSDictionary *registry;
@property (nonatomic, strong) NSMutableArray *selected;
@property (nonatomic, strong) NSArray *allIDs;
@property (nonatomic, strong) NSArray *visibleIDs;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, copy) void (^completion)(NSArray *);
@end

@implementation NineEntityPicker

- (instancetype)initWithStates:(NSDictionary *)stateByID
                      registry:(NSDictionary *)registry
                      selected:(NSArray *)selected
                    completion:(void (^)(NSArray *))completion {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _stateByID = stateByID ?: @{};
        _registry = registry ?: @{};
        _selected = [selected mutableCopy] ?: [NSMutableArray array];
        _completion = [completion copy];

        _allIDs = [[stateByID allKeys] sortedArrayUsingComparator:
            ^NSComparisonResult(NSString *a, NSString *b) {
                return [NEName(stateByID[a], registry[a])
                    localizedCaseInsensitiveCompare:NEName(stateByID[b], registry[b])];
            }];
        _visibleIDs = _allIDs;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Scegli entità";
    NTStyleTableView(self.tableView);
    self.tableView.rowHeight = 54;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Fine" style:UIBarButtonItemStyleDone
               target:self action:@selector(done)];

    self.search = [[UISearchBar alloc]
        initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 48)];
    self.search.delegate = self;
    self.search.placeholder = @"Cerca per nome o entity_id";
    self.search.searchBarStyle = UISearchBarStyleMinimal;
    self.search.barStyle = UIBarStyleBlack;
    self.search.keyboardAppearance = UIKeyboardAppearanceDark;
    self.search.tintColor = NTPrimary();
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tableView.tableHeaderView = self.search;
}

- (void)done {
    if (self.completion) self.completion([self.selected copy]);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
    NSString *query = [text lowercaseString];
    if (!query.length) {
        self.visibleIDs = self.allIDs;
    } else {
        NSMutableArray *matches = [NSMutableArray array];
        for (NSString *entityID in self.allIDs) {
            NSString *name = [NEName(self.stateByID[entityID],
                                     self.registry[entityID]) lowercaseString];
            if ([name rangeOfString:query].location != NSNotFound ||
                [entityID rangeOfString:query].location != NSNotFound) {
                [matches addObject:entityID];
            }
        }
        self.visibleIDs = matches;
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleIDs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *entityID = self.visibleIDs[indexPath.row];
    UITableViewCell *cell = NineEditorEntityCell(tableView,
        self.stateByID[entityID], self.registry[entityID], entityID);
    cell.backgroundColor = NTBackground();
    cell.accessoryType = [self.selected containsObject:entityID]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *entityID = self.visibleIDs[indexPath.row];

    if ([self.selected containsObject:entityID]) {
        [self.selected removeObject:entityID];
    } else {
        [self.selected addObject:entityID];
    }

    [tableView reloadRowsAtIndexPaths:@[indexPath]
                     withRowAnimation:UITableViewRowAnimationNone];
}

@end
