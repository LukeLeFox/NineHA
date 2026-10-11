#import "NineNASAdapter.h"
#import "NineLocalConfig.h"
#import "NineTheme.h"

typedef NS_ENUM(NSInteger, NineNASDirection) {
    NineNASDirectionNone = 0,
    NineNASDirectionStarting,
    NineNASDirectionStopping
};

static NSTimeInterval const NineNASRequestTimeout = 300;

@interface NineNASAdapter ()
@property (nonatomic, readwrite) NineNASLevel level;
@property (nonatomic, readwrite, copy) NSString *lastChanged;
@property (nonatomic, assign) NineNASLevel lastStableLevel;
@property (nonatomic, assign) NineNASDirection direction;
@property (nonatomic, strong) NSDate *requestDate;
@property (nonatomic, assign) NineNASDirection requested;
@end

@implementation NineNASAdapter

+ (BOOL)isConfigured {
    return NINEHA_NAS_SWITCH_ENTITY.length &&
           NINEHA_NAS_STATUS_ENTITY.length &&
           NINEHA_NAS_VM_STATUS_ENTITY.length;
}

+ (BOOL)isNASEntity:(NSString *)entityID {
    return [self isConfigured] &&
           [entityID isEqualToString:NINEHA_NAS_SWITCH_ENTITY];
}

+ (NSArray *)dependencies {
    if (![self isConfigured]) return @[];
    return @[NINEHA_NAS_STATUS_ENTITY, NINEHA_NAS_VM_STATUS_ENTITY];
}

+ (NSString *)configuredTitle {
    return NINEHA_NAS_TITLE.length ? NINEHA_NAS_TITLE : nil;
}

+ (NSArray *)gracefulService {
    if (!NINEHA_NAS_GRACEFUL_DOMAIN.length ||
        !NINEHA_NAS_GRACEFUL_SERVICE.length) return nil;
    return @[NINEHA_NAS_GRACEFUL_DOMAIN, NINEHA_NAS_GRACEFUL_SERVICE];
}

+ (NSArray *)forceService {
    if (!NINEHA_NAS_FORCE_DOMAIN.length ||
        !NINEHA_NAS_FORCE_SERVICE.length) return nil;
    return @[NINEHA_NAS_FORCE_DOMAIN, NINEHA_NAS_FORCE_SERVICE];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _level = NineNASLevelUnknown;
        _lastStableLevel = NineNASLevelUnknown;
    }
    return self;
}

static NSString *NineNASState(NSDictionary *states, NSString *entityID) {
    NSDictionary *entity = states[entityID];
    if (![entity isKindOfClass:[NSDictionary class]]) return nil;
    id state = entity[@"state"];
    return [state isKindOfClass:[NSString class]] ? state : nil;
}

- (void)updateWithStates:(NSDictionary *)stateByID {
    if (![NineNASAdapter isConfigured]) {
        self.level = NineNASLevelUnknown;
        return;
    }

    NSString *nas = NineNASState(stateByID, NINEHA_NAS_STATUS_ENTITY);
    NSString *vm = NineNASState(stateByID, NINEHA_NAS_VM_STATUS_ENTITY);

    // Ultimo cambio tra i due sensori (le stringhe ISO UTC
    // di Home Assistant sono confrontabili lessicograficamente).
    NSString *latest = nil;
    for (NSString *entityID in [NineNASAdapter dependencies]) {
        NSDictionary *entity = stateByID[entityID];
        id changed = [entity isKindOfClass:[NSDictionary class]]
            ? entity[@"last_changed"] : nil;
        if ([changed isKindOfClass:[NSString class]] &&
            (!latest || [changed compare:latest] == NSOrderedDescending)) {
            latest = changed;
        }
    }
    self.lastChanged = latest;

    NineNASLevel level = NineNASLevelUnknown;

    if ([nas isEqualToString:@"on"]) {
        level = NineNASLevelOnline;
    } else if ([vm isEqualToString:@"on"]) {
        level = NineNASLevelVMRunning;
    } else if ([vm isEqualToString:@"off"] &&
               ([nas isEqualToString:@"off"] || !nas.length ||
                [nas isEqualToString:@"unavailable"])) {
        level = NineNASLevelOff;
    }

    self.level = level;

    // Le richieste scadono: lo stato reale torna prioritario.
    if (self.requestDate &&
        -[self.requestDate timeIntervalSinceNow] > NineNASRequestTimeout) {
        self.requestDate = nil;
        self.requested = NineNASDirectionNone;
    }

    if (level == NineNASLevelOnline || level == NineNASLevelOff) {
        // Stato stabile raggiunto: la richiesta coerente è conclusa.
        if ((level == NineNASLevelOnline &&
             self.requested == NineNASDirectionStarting) ||
            (level == NineNASLevelOff &&
             self.requested == NineNASDirectionStopping)) {
            self.requested = NineNASDirectionNone;
            self.requestDate = nil;
        }

        self.lastStableLevel = level;
        self.direction = self.requested;
        return;
    }

    if (level == NineNASLevelVMRunning) {
        if (self.requested != NineNASDirectionNone) {
            self.direction = self.requested;
        } else if (self.lastStableLevel == NineNASLevelOnline) {
            self.direction = NineNASDirectionStopping;
        } else if (self.lastStableLevel == NineNASLevelOff) {
            self.direction = NineNASDirectionStarting;
        } else {
            self.direction = NineNASDirectionNone;
        }
        return;
    }

    self.direction = NineNASDirectionNone;
}

- (void)noteRequestedPower:(BOOL)on {
    self.requested = on ? NineNASDirectionStarting
                        : NineNASDirectionStopping;
    self.requestDate = [NSDate date];
    self.direction = self.requested;
}

- (BOOL)busy {
    return self.direction != NineNASDirectionNone;
}

- (BOOL)poweredOn {
    return self.level == NineNASLevelOnline ||
           self.level == NineNASLevelVMRunning;
}

- (NSString *)statusText {
    if (self.direction == NineNASDirectionStarting) return @"Avvio in corso…";
    if (self.direction == NineNASDirectionStopping) return @"Arresto in corso…";

    switch (self.level) {
        case NineNASLevelOnline:    return @"Online";
        case NineNASLevelVMRunning: return @"VM attiva, NAS non raggiungibile";
        case NineNASLevelOff:       return @"Spento";
        default:                    return @"Stato non disponibile";
    }
}

- (NSString *)iconName {
    if (self.busy) return @"nas";
    return self.level == NineNASLevelOff ? @"server-off" : @"nas";
}

- (UIColor *)color {
    if (self.busy) return NTWarning();

    switch (self.level) {
        case NineNASLevelOnline:    return NTHex(0x4CAF50, 1);
        case NineNASLevelVMRunning: return NTWarning();
        case NineNASLevelOff:       return NTInactive();
        default:                    return NTDisabledText();
    }
}

@end
