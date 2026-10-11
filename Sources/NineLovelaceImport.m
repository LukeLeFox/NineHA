#import "NineLovelaceImport.h"
#import "NineWSRequest.h"

@interface NineLovelaceConverter : NSObject
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableArray *pendingItems;
@property (nonatomic, strong) NSMutableDictionary *pendingNames;
@property (nonatomic, copy) NSString *pendingTitle;
@property (nonatomic, assign) NSInteger skipped;
@end

static NSString *NLString(id value) {
    return [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
}

// I nomi calcolati da template (Jinja o button-card) non sono statici.
static NSString *NLStaticName(id value) {
    NSString *name = NLString(value);
    if (!name || [name rangeOfString:@"{{"].location != NSNotFound ||
        [name rangeOfString:@"[[["].location != NSNotFound) return nil;
    return name;
}

static BOOL NLIsEntityID(NSString *value) {
    return value && [value rangeOfString:@"."].location != NSNotFound &&
        [value rangeOfString:@" "].location == NSNotFound;
}

@implementation NineLovelaceConverter

- (instancetype)init {
    self = [super init];
    if (self) {
        _sections = [NSMutableArray array];
        _pendingItems = [NSMutableArray array];
        _pendingNames = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)flush {
    if (self.pendingItems.count) {
        NSMutableDictionary *section = [@{
            @"title": self.pendingTitle ?: @"",
            @"items": [self.pendingItems copy],
            @"style": @"tiles"
        } mutableCopy];
        if (self.pendingNames.count) section[@"names"] = [self.pendingNames copy];
        [self.sections addObject:section];
    }
    [self.pendingItems removeAllObjects];
    [self.pendingNames removeAllObjects];
    self.pendingTitle = nil;
}

- (void)addPending:(NSString *)entityID name:(NSString *)name {
    if (!NLIsEntityID(entityID) || [self.pendingItems containsObject:entityID]) return;
    [self.pendingItems addObject:entityID];
    if (name) self.pendingNames[entityID] = name;
}

// Righe di una card entities/glance: stringhe o dizionari.
- (void)collectRows:(NSArray *)rows
              items:(NSMutableArray *)items
              names:(NSMutableDictionary *)names {
    if (![rows isKindOfClass:[NSArray class]]) return;

    for (id row in rows) {
        NSString *entityID = NLString(row);
        NSString *name = nil;

        if ([row isKindOfClass:[NSDictionary class]]) {
            entityID = NLString(row[@"entity"]);
            name = NLStaticName(row[@"name"]);
        }

        if (!NLIsEntityID(entityID) || [items containsObject:entityID]) continue;
        [items addObject:entityID];
        if (name) names[entityID] = name;
    }
}

- (NSArray *)childrenOf:(NSDictionary *)card {
    if ([card[@"cards"] isKindOfClass:[NSArray class]]) return card[@"cards"];
    if ([card[@"card"] isKindOfClass:[NSDictionary class]]) return @[card[@"card"]];
    return nil;
}

// Contenitore composto solo da card entità di sensori: griglia valori.
- (BOOL)isSensorGrid:(NSArray *)children {
    if (children.count < 2) return NO;
    for (id child in children) {
        if (![child isKindOfClass:[NSDictionary class]]) return NO;
        NSString *type = NLString(child[@"type"]);
        NSString *entityID = NLString(child[@"entity"]);
        if (![@[@"entity", @"sensor"] containsObject:type ?: @""]) return NO;
        if (![entityID hasPrefix:@"sensor."] &&
            ![entityID hasPrefix:@"binary_sensor."]) return NO;
    }
    return YES;
}

- (void)processCard:(id)value {
    if (![value isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *card = value;

    NSString *type = NLString(card[@"type"]) ?: @"";
    NSString *entityID = NLString(card[@"entity"]);
    NSString *title = NLStaticName(card[@"title"]);

    if ([type isEqualToString:@"weather-forecast"] ||
        ([entityID hasPrefix:@"weather."] &&
         [type rangeOfString:@"weather"].location != NSNotFound)) {
        [self flush];
        if (NLIsEntityID(entityID)) {
            [self.sections addObject:@{@"title": NLStaticName(card[@"name"]) ?: @"",
                                       @"items": @[entityID],
                                       @"style": @"weather"}];
        }
        return;
    }

    if ([type isEqualToString:@"clock"] ||
        ([type hasPrefix:@"custom:"] &&
         [type rangeOfString:@"clock"].location != NSNotFound)) {
        [self flush];
        [self.sections addObject:@{
            @"title": title ?: @"", @"items": @[], @"style": @"clock",
            @"format": [[card[@"time_format"] description] isEqualToString:@"12"]
                ? @"12" : @"24"}];
        return;
    }

    if ([type isEqualToString:@"heading"]) {
        [self flush];
        self.pendingTitle = NLStaticName(card[@"heading"]);
        return;
    }

    if ([type isEqualToString:@"entities"] || [type isEqualToString:@"glance"]) {
        NSMutableArray *items = [NSMutableArray array];
        NSMutableDictionary *names = [NSMutableDictionary dictionary];
        [self collectRows:card[@"entities"] items:items names:names];
        if (!items.count) return;

        BOOL grid = [type isEqualToString:@"glance"];
        if (title || grid) {
            [self flush];
            NSMutableDictionary *section = [@{
                @"title": title ?: @"", @"items": items,
                @"style": grid ? @"grid" : @"tiles"} mutableCopy];
            if (names.count) section[@"names"] = names;
            [self.sections addObject:section];
        } else {
            for (NSString *item in items) [self addPending:item name:names[item]];
        }
        return;
    }

    NSArray *children = [self childrenOf:card];
    if (children) {
        if ([self isSensorGrid:children]) {
            [self flush];
            NSMutableArray *items = [NSMutableArray array];
            NSMutableDictionary *names = [NSMutableDictionary dictionary];
            for (NSDictionary *child in children) {
                NSString *childID = NLString(child[@"entity"]);
                if ([items containsObject:childID]) continue;
                [items addObject:childID];
                NSString *name = NLStaticName(child[@"name"]);
                if (name) names[childID] = name;
            }
            NSMutableDictionary *section = [@{
                @"title": title ?: @"", @"items": items, @"style": @"grid"} mutableCopy];
            if (names.count) section[@"names"] = names;
            [self.sections addObject:section];
            return;
        }

        if (title) {
            [self flush];
            self.pendingTitle = title;
        }
        for (id child in children) [self processCard:child];
        if (title) [self flush];
        return;
    }

    // Card singola legata a un'entità (tile, button, mushroom, ...).
    if (NLIsEntityID(entityID)) {
        NSString *name = NLStaticName(card[@"name"]) ?: NLStaticName(card[@"primary"]);
        [self addPending:entityID name:name];
        return;
    }

    self.skipped++;
}

@end

@implementation NineLovelaceImport

+ (void)loadDashboardsWithServerURL:(NSString *)serverURL
                              token:(NSString *)token
                         completion:(void (^)(NSArray *, NSError *))completion {
    [NineWSRequest sendCommands:@[@{@"type": @"lovelace/dashboards/list"}]
                      serverURL:serverURL
                          token:token
                     completion:^(NSArray *results, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSMutableArray *dashboards = [NSMutableArray arrayWithObject:
            @{@"title": @"Panoramica (predefinita)", @"url_path": [NSNull null]}];

        id list = results.firstObject;
        if ([list isKindOfClass:[NSArray class]]) {
            for (id item in list) {
                if (![item isKindOfClass:[NSDictionary class]]) continue;
                NSString *path = NLString(item[@"url_path"]);
                // "lovelace" è un alias della dashboard predefinita.
                if (!path || [path isEqualToString:@"lovelace"]) continue;
                [dashboards addObject:@{
                    @"title": NLString(item[@"title"]) ?: path,
                    @"url_path": path}];
            }
        }

        completion(dashboards, nil);
    }];
}

+ (void)loadConfigForURLPath:(id)urlPath
                   serverURL:(NSString *)serverURL
                       token:(NSString *)token
                  completion:(void (^)(NSDictionary *, NSError *))completion {
    [NineWSRequest sendCommands:@[@{@"type": @"lovelace/config",
                                    @"url_path": urlPath ?: [NSNull null]}]
                      serverURL:serverURL
                          token:token
                     completion:^(NSArray *results, NSError *error) {
        id config = results.firstObject;
        if (error || ![config isKindOfClass:[NSDictionary class]]) {
            completion(nil, error ?: [NSError errorWithDomain:@"NineHA.Lovelace"
                code:1 userInfo:@{NSLocalizedDescriptionKey:
                    @"Configurazione non disponibile (dashboard automatica "
                     "o in modalità YAML non accessibile)"}]);
            return;
        }
        completion(config, nil);
    }];
}

+ (NSArray *)sectionsForView:(NSDictionary *)view skipped:(NSInteger *)skipped {
    NineLovelaceConverter *converter = [[NineLovelaceConverter alloc] init];

    id sections = view[@"sections"];
    if ([sections isKindOfClass:[NSArray class]]) {
        for (id section in sections) {
            if (![section isKindOfClass:[NSDictionary class]]) continue;
            [converter flush];
            id cards = section[@"cards"];
            if ([cards isKindOfClass:[NSArray class]]) {
                for (id card in cards) [converter processCard:card];
            }
        }
    }

    id cards = view[@"cards"];
    if ([cards isKindOfClass:[NSArray class]]) {
        for (id card in cards) [converter processCard:card];
    }

    [converter flush];
    if (skipped) *skipped = converter.skipped;
    return converter.sections;
}

+ (NSString *)titleForView:(NSDictionary *)view index:(NSUInteger)index {
    return NLString(view[@"title"]) ?: NLString(view[@"path"])
        ?: [NSString stringWithFormat:@"Vista %lu", (unsigned long)index + 1];
}

@end
