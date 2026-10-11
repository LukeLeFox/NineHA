#import "NineCustomDashboards.h"

NSString *const NineCustomDashboardsChangedNotification =
    @"NineHA.CustomDashboardsChanged";

static NSString *NCDKey(NSString *server) {
    return [@"NineHA.CustomDashboards." stringByAppendingString:server ?: @""];
}

static NSString *NCDStartKey(NSString *server) {
    return [@"NineHA.StartDashboard." stringByAppendingString:server ?: @""];
}

@implementation NineCustomDashboards

// Validazione minima: scarta voci malformate salvate da versioni diverse.
+ (NSDictionary *)sanitized:(id)value {
    if (![value isKindOfClass:[NSDictionary class]]) return nil;

    NSString *identifier = value[@"id"];
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;

    NSString *name = [value[@"name"] isKindOfClass:[NSString class]]
        ? value[@"name"] : @"Dashboard";

    NSMutableArray *sections = [NSMutableArray array];
    id rawSections = value[@"sections"];

    if ([rawSections isKindOfClass:[NSArray class]]) {
        for (id section in rawSections) {
            if (![section isKindOfClass:[NSDictionary class]]) continue;

            NSString *title = [section[@"title"] isKindOfClass:[NSString class]]
                ? section[@"title"] : @"";

            NSMutableArray *items = [NSMutableArray array];
            id rawItems = section[@"items"];
            if ([rawItems isKindOfClass:[NSArray class]]) {
                for (id item in rawItems) {
                    if ([item isKindOfClass:[NSString class]] &&
                        [item rangeOfString:@"."].location != NSNotFound &&
                        ![items containsObject:item]) {
                        [items addObject:item];
                    }
                }
            }

            [sections addObject:@{@"title": title, @"items": items}];
        }
    }

    NSMutableDictionary *result = [@{
        @"id": identifier, @"name": name, @"sections": sections
    } mutableCopy];

    if ([value[@"icon"] isKindOfClass:[NSString class]])
        result[@"icon"] = value[@"icon"];

    return result;
}

+ (NSArray *)dashboardsForServer:(NSString *)server {
    NSArray *stored = [[NSUserDefaults standardUserDefaults]
        arrayForKey:NCDKey(server)];

    NSMutableArray *result = [NSMutableArray array];
    for (id item in stored ?: @[]) {
        NSDictionary *dashboard = [self sanitized:item];
        if (dashboard) [result addObject:dashboard];
    }
    return result;
}

+ (NSDictionary *)dashboardWithID:(NSString *)identifier server:(NSString *)server {
    if (!identifier.length) return nil;
    for (NSDictionary *dashboard in [self dashboardsForServer:server]) {
        if ([dashboard[@"id"] isEqualToString:identifier]) return dashboard;
    }
    return nil;
}

+ (void)storeDashboards:(NSArray *)dashboards server:(NSString *)server {
    [[NSUserDefaults standardUserDefaults]
        setObject:dashboards forKey:NCDKey(server)];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:NineCustomDashboardsChangedNotification
                      object:nil];
}

+ (NSString *)createDashboardNamed:(NSString *)name server:(NSString *)server {
    NSString *identifier = [[NSUUID UUID] UUIDString];
    NSString *clean = [name stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray *dashboards = [[self dashboardsForServer:server] mutableCopy];
    [dashboards addObject:@{
        @"id": identifier,
        @"name": clean.length ? clean : @"Nuova dashboard",
        @"sections": @[@{@"title": @"", @"items": @[]}]
    }];

    [self storeDashboards:dashboards server:server];
    return identifier;
}

+ (void)saveDashboard:(NSDictionary *)dashboard server:(NSString *)server {
    NSDictionary *clean = [self sanitized:dashboard];
    if (!clean) return;

    NSMutableArray *dashboards = [[self dashboardsForServer:server] mutableCopy];
    BOOL replaced = NO;

    for (NSUInteger i = 0; i < dashboards.count; i++) {
        if ([dashboards[i][@"id"] isEqualToString:clean[@"id"]]) {
            dashboards[i] = clean;
            replaced = YES;
            break;
        }
    }
    if (!replaced) [dashboards addObject:clean];

    [self storeDashboards:dashboards server:server];
}

+ (void)deleteDashboardWithID:(NSString *)identifier server:(NSString *)server {
    NSMutableArray *dashboards = [NSMutableArray array];
    for (NSDictionary *dashboard in [self dashboardsForServer:server]) {
        if (![dashboard[@"id"] isEqualToString:identifier])
            [dashboards addObject:dashboard];
    }

    if ([[self startDashboardIDForServer:server] isEqualToString:identifier]) {
        [self setStartDashboardID:nil server:server];
    }

    [self storeDashboards:dashboards server:server];
}

+ (void)addEntity:(NSString *)entityID
      toDashboard:(NSString *)identifier
           server:(NSString *)server {
    NSDictionary *dashboard = [self dashboardWithID:identifier server:server];
    if (!dashboard || !entityID.length) return;

    NSMutableArray *sections = [dashboard[@"sections"] mutableCopy];
    if (!sections.count) [sections addObject:@{@"title": @"", @"items": @[]}];

    for (NSDictionary *section in sections) {
        if ([section[@"items"] containsObject:entityID]) return;
    }

    NSMutableDictionary *first = [sections[0] mutableCopy];
    first[@"items"] = [first[@"items"] arrayByAddingObject:entityID];
    sections[0] = first;

    NSMutableDictionary *updated = [dashboard mutableCopy];
    updated[@"sections"] = sections;
    [self saveDashboard:updated server:server];
}

+ (NSString *)startDashboardIDForServer:(NSString *)server {
    NSString *identifier = [[NSUserDefaults standardUserDefaults]
        stringForKey:NCDStartKey(server)];
    return [self dashboardWithID:identifier server:server] ? identifier : nil;
}

+ (void)setStartDashboardID:(NSString *)identifier server:(NSString *)server {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (identifier.length) {
        [defaults setObject:identifier forKey:NCDStartKey(server)];
    } else {
        [defaults removeObjectForKey:NCDStartKey(server)];
    }
}

@end
