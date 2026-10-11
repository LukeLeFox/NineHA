#import "NineMoreInfoPanel.h"
#import "NineControls.h"
#import "NineEntity.h"
#import "NineIcons.h"
#import "NineNASAdapter.h"
#import "NineTheme.h"
#import <math.h>

typedef NS_ENUM(NSInteger, NineInfoKind) {
    NineInfoKindInfo = 0,
    NineInfoKindLight,
    NineInfoKindToggle,
    NineInfoKindCover,
    NineInfoKindClimate,
    NineInfoKindMedia,
    NineInfoKindVacuum,
    NineInfoKindAction,
    NineInfoKindNAS
};

static NSSet *NineSafeCoverClasses(void) {
    return [NSSet setWithArray:@[
        @"blind", @"curtain", @"shade", @"shutter", @"awning"
    ]];
}

@interface NineMoreInfoPanel ()

@property (nonatomic, copy, readwrite) NSString *entityID;
@property (nonatomic, strong) NSDictionary *entity;
@property (nonatomic, strong) NSDictionary *registry;
@property (nonatomic, copy) NSString *area;
@property (nonatomic, strong) NineNASAdapter *nas;
@property (nonatomic, assign) NineInfoKind kind;
@property (nonatomic, copy, readwrite) NSDictionary *related;
@property (nonatomic, strong) NSDictionary *relatedStates;
@property (nonatomic, strong) NSArray *transportButtons;
@property (nonatomic, strong) NSArray *remoteButtons;
@property (nonatomic, strong) UIButton *choiceButton;

@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *footerLabel;

@property (nonatomic, strong) UIView *bigIconCircle;
@property (nonatomic, strong) NineIconView *bigIcon;
@property (nonatomic, strong) NineBigSlider *slider;
@property (nonatomic, strong) NineBigToggle *toggle;
@property (nonatomic, strong) UIButton *powerButton;
@property (nonatomic, strong) NSArray *roundButtons;
@property (nonatomic, strong) NSArray *pillButtons;
@property (nonatomic, strong) UILabel *attributesLabel;

@property (nonatomic, assign) double pendingTemperature;
@property (nonatomic, strong) NSTimer *temperatureTimer;
@property (nonatomic, strong) NSDate *sliderReleaseDate;

@end

@implementation NineMoreInfoPanel

- (instancetype)initWithEntity:(NSDictionary *)entity
                      registry:(NSDictionary *)registry
                          area:(NSString *)area
                           nas:(NineNASAdapter *)nas
                       related:(NSDictionary *)related
                 relatedStates:(NSDictionary *)relatedStates {
    self = [super initWithFrame:CGRectZero];

    if (self) {
        _related = [related copy] ?: @{};
        _relatedStates = relatedStates ?: @{};
        _entity = entity;
        _entityID = [entity[@"entity_id"] copy];
        _registry = registry;
        _area = [area copy];
        _nas = [NineNASAdapter isNASEntity:_entityID] ? nas : nil;
        _kind = [self kindForEntity:entity];

        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        self.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        UIControl *shade = [[UIControl alloc] init];
        shade.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;
        [shade addTarget:self
                  action:@selector(dismiss)
        forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:shade];

        [self buildCard];
        [self refresh];
    }

    return self;
}

- (NineInfoKind)kindForEntity:(NSDictionary *)entity {
    if (self.nas) return NineInfoKindNAS;

    NSString *domain = NEDomain(self.entityID);
    NSDictionary *attrs = NEAttributes(entity);
    NSInteger features = [attrs[@"supported_features"] integerValue];

    if ([domain isEqualToString:@"light"]) {
        return NESupportsBrightness(entity)
            ? NineInfoKindLight : NineInfoKindToggle;
    }

    if ([@[@"switch", @"input_boolean", @"fan"] containsObject:domain])
        return NineInfoKindToggle;

    if ([domain isEqualToString:@"cover"] &&
        [NineSafeCoverClasses() containsObject:NEDeviceClass(entity)] &&
        (features & (1 | 2)))
        return NineInfoKindCover;

    if ([domain isEqualToString:@"climate"] && (features & 1) &&
        [attrs[@"temperature"] isKindOfClass:[NSNumber class]])
        return NineInfoKindClimate;

    if ([domain isEqualToString:@"media_player"])
        return NineInfoKindMedia;

    if ([domain isEqualToString:@"vacuum"])
        return NineInfoKindVacuum;

    if ([@[@"scene", @"script", @"button", @"input_button"]
            containsObject:domain])
        return NineInfoKindAction;

    return NineInfoKindInfo;
}

#pragma mark - Costruzione

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = .6f;
    [self.card addSubview:label];
    return label;
}

- (void)buildCard {
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = NTCard();
    self.card.layer.cornerRadius = 24;
    self.card.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
    self.card.layer.borderColor = NTBorder().CGColor;
    self.card.clipsToBounds = YES;
    [self addSubview:self.card];

    self.closeButton = NineIconButton(@"close", 24, NTText());
    [self.closeButton addTarget:self
                         action:@selector(dismiss)
               forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.accessibilityLabel = @"Chiudi";
    [self.card addSubview:self.closeButton];

    self.titleLabel = [self labelWithFont:NTMediumFont(18) color:NTText()];
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    self.subtitleLabel = [self labelWithFont:NTFont(13) color:NTSecondaryText()];
    self.subtitleLabel.textAlignment = NSTextAlignmentLeft;

    self.stateLabel = [self labelWithFont:NTMediumFont(30) color:NTText()];
    self.detailLabel = [self labelWithFont:NTFont(13) color:NTSecondaryText()];

    self.footerLabel = [self labelWithFont:NTFont(11) color:NTDisabledText()];
    self.footerLabel.text = self.entityID;

    NSString *domain = NEDomain(self.entityID);

    switch (self.kind) {
        case NineInfoKindLight: {
            self.slider = [[NineBigSlider alloc] init];
            [self.slider addTarget:self
                            action:@selector(sliderMoved)
                  forControlEvents:UIControlEventValueChanged];
            [self.slider addTarget:self
                            action:@selector(sliderReleased)
                  forControlEvents:UIControlEventEditingDidEnd];
            [self.card addSubview:self.slider];

            self.powerButton = NineRoundButton(@"power", 52,
                NTHex(0x9E9E9E, .2f), NTText());
            self.powerButton.accessibilityLabel = @"Accendi o spegni";
            [self.powerButton addTarget:self
                                 action:@selector(togglePower)
                       forControlEvents:UIControlEventTouchUpInside];
            [self.card addSubview:self.powerButton];
            break;
        }

        case NineInfoKindToggle: {
            self.toggle = [[NineBigToggle alloc] init];
            if ([domain isEqualToString:@"light"]) {
                self.toggle.onIcon = @"lightbulb";
                self.toggle.offIcon = @"lightbulb-off";
            } else if ([domain isEqualToString:@"fan"]) {
                self.toggle.onIcon = @"fan";
                self.toggle.offIcon = @"fan-off";
            }
            [self.toggle addTarget:self
                            action:@selector(toggleChanged)
                  forControlEvents:UIControlEventValueChanged];
            [self.card addSubview:self.toggle];
            break;
        }

        case NineInfoKindCover: {
            NSInteger features =
                [NEAttributes(self.entity)[@"supported_features"] integerValue];
            NSMutableArray *buttons = [NSMutableArray array];
            NSArray *specs = @[
                @[@"arrow-up", @"open_cover", @1, @"Apri"],
                @[@"stop", @"stop_cover", @8, @"Ferma"],
                @[@"arrow-down", @"close_cover", @2, @"Chiudi"]
            ];
            for (NSArray *spec in specs) {
                if (!(features & [spec[2] integerValue])) continue;
                UIButton *button = NineRoundButton(spec[0], 72,
                    NTHex(0x926BC7, .2f), NTText());
                button.accessibilityIdentifier = spec[1];
                button.accessibilityLabel = spec[3];
                [button addTarget:self
                           action:@selector(coverButton:)
                 forControlEvents:UIControlEventTouchUpInside];
                [self.card addSubview:button];
                [buttons addObject:button];
            }
            self.roundButtons = buttons;
            break;
        }

        case NineInfoKindClimate: {
            UIButton *minus = NineRoundButton(@"minus", 64,
                NTHex(0xFF8100, .2f), NTText());
            minus.tag = -1;
            minus.accessibilityLabel = @"Diminuisci temperatura";
            UIButton *plus = NineRoundButton(@"plus", 64,
                NTHex(0xFF8100, .2f), NTText());
            plus.tag = 1;
            plus.accessibilityLabel = @"Aumenta temperatura";
            for (UIButton *button in @[minus, plus]) {
                [button addTarget:self
                           action:@selector(temperatureStep:)
                 forControlEvents:UIControlEventTouchUpInside];
                [self.card addSubview:button];
            }
            self.roundButtons = @[minus, plus];
            self.pendingTemperature = NAN;
            break;
        }

        case NineInfoKindMedia:
            [self buildMediaControls];
            break;

        case NineInfoKindVacuum:
            [self buildVacuumControls];
            break;

        case NineInfoKindAction: {
            NSString *title = [domain isEqualToString:@"scene"] ? @"Attiva"
                : [domain isEqualToString:@"script"] ? @"Esegui" : @"Premi";
            UIButton *run = NinePillButton(title, NTPrimary(), [UIColor whiteColor]);
            [run addTarget:self
                    action:@selector(runAction)
          forControlEvents:UIControlEventTouchUpInside];
            [self.card addSubview:run];
            self.pillButtons = @[run];
            [self buildBigIcon];
            break;
        }

        case NineInfoKindNAS: {
            [self buildBigIcon];

            UIButton *power = NinePillButton(@"", NTPrimary(), [UIColor whiteColor]);
            [power addTarget:self
                      action:@selector(nasGraceful)
            forControlEvents:UIControlEventTouchUpInside];

            UIButton *force = NinePillButton(@"Arresto forzato VM",
                NTHex(0xDB4437, .18f), NTHex(0xFF6E60, 1));
            [force addTarget:self
                      action:@selector(nasForce)
            forControlEvents:UIControlEventTouchUpInside];

            [self.card addSubview:power];
            [self.card addSubview:force];
            self.pillButtons = @[power, force];
            break;
        }

        default: {
            [self buildBigIcon];
            self.attributesLabel = [self labelWithFont:NTFont(14)
                                                 color:NTSecondaryText()];
            self.attributesLabel.numberOfLines = 0;
            self.attributesLabel.adjustsFontSizeToFitWidth = NO;
            break;
        }
    }
}

- (void)buildBigIcon {
    self.bigIconCircle = [[UIView alloc] init];
    self.bigIconCircle.layer.cornerRadius = 48;
    [self.card addSubview:self.bigIconCircle];

    self.bigIcon = [[NineIconView alloc]
        initWithFrame:CGRectMake(0, 0, 96, 96) iconSize:52];
    [self.bigIconCircle addSubview:self.bigIcon];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGSize size = self.bounds.size;
    for (UIView *view in self.subviews) {
        if (view != self.card) view.frame = self.bounds;
    }

    CGFloat width = MIN((CGFloat)420, size.width - 24);
    CGFloat desired = self.kind == NineInfoKindMedia && self.remoteButtons.count
        ? 640 : 560;
    CGFloat height = MIN(desired, size.height - 40);

    self.card.frame = CGRectMake(floorf((size.width - width) / 2),
                                 floorf((size.height - height) / 2),
                                 width, height);

    self.closeButton.frame = CGRectMake(8, 10, 44, 44);
    self.titleLabel.frame = CGRectMake(60, 12, width - 76, 24);
    self.subtitleLabel.frame = CGRectMake(60, 35, width - 76, 18);

    self.stateLabel.frame = CGRectMake(20, 72, width - 40, 38);
    self.detailLabel.frame = CGRectMake(20, 110, width - 40, 18);
    self.footerLabel.frame = CGRectMake(20, height - 28, width - 40, 16);

    CGFloat top = 140;
    CGFloat bottom = height - 40;
    CGFloat area = bottom - top;
    CGFloat midX = width / 2;

    switch (self.kind) {
        case NineInfoKindLight: {
            CGFloat sliderHeight = MAX(120, area - 76);
            self.slider.frame = CGRectMake(midX - 60, top, 120, sliderHeight);
            self.powerButton.center = CGPointMake(midX, top + sliderHeight + 40);
            break;
        }

        case NineInfoKindToggle: {
            CGFloat toggleHeight = MIN((CGFloat)300, area - 10);
            self.toggle.frame = CGRectMake(midX - 60,
                top + (area - toggleHeight) / 2, 120, toggleHeight);
            break;
        }

        case NineInfoKindCover: {
            NSUInteger count = self.roundButtons.count;
            CGFloat spacing = 88;
            CGFloat startY = top + (area - spacing * count) / 2 + 44;
            for (NSUInteger i = 0; i < count; i++) {
                UIButton *button = self.roundButtons[i];
                button.center = CGPointMake(midX, startY + spacing * i);
            }
            break;
        }

        case NineInfoKindClimate: {
            CGFloat y = top + area / 2 - 20;
            [self.roundButtons[0] setCenter:CGPointMake(midX - 110, y)];
            [self.roundButtons[1] setCenter:CGPointMake(midX + 110, y)];
            self.stateLabel.frame = CGRectMake(midX - 70, y - 30, 140, 60);
            self.detailLabel.frame = CGRectMake(20, 80, width - 40, 40);
            break;
        }

        case NineInfoKindMedia:
            [self layoutMediaWithTop:top width:width];
            break;

        case NineInfoKindVacuum:
            [self layoutVacuumWithTop:top width:width];
            break;

        case NineInfoKindAction:
            self.bigIconCircle.frame = CGRectMake(midX - 48, top + 20, 96, 96);
            [self.pillButtons[0] setFrame:
                CGRectMake(midX - 110, top + 160, 220, 48)];
            break;

        case NineInfoKindNAS:
            self.bigIconCircle.frame = CGRectMake(midX - 48, top + 10, 96, 96);
            [self.pillButtons[0] setFrame:
                CGRectMake(midX - 130, top + 140, 260, 50)];
            [self.pillButtons[1] setFrame:
                CGRectMake(midX - 130, top + 202, 260, 44)];
            break;

        default:
            self.bigIconCircle.frame = CGRectMake(midX - 48, top + 10, 96, 96);
            {
                CGFloat maxHeight = MAX(20, area - 130);
                CGSize fit = [self.attributesLabel sizeThatFits:
                    CGSizeMake(width - 48, maxHeight)];
                self.attributesLabel.frame = CGRectMake(24, top + 124,
                    width - 48, MIN(maxHeight, ceilf(fit.height)));
            }
            break;
    }
}

#pragma mark - Stato

- (void)updateEntity:(NSDictionary *)entity {
    if (![entity isKindOfClass:[NSDictionary class]]) return;
    self.entity = entity;
    [self refresh];
}

- (void)refreshNAS {
    if (self.kind == NineInfoKindNAS) [self refresh];
}

- (NSString *)attributesText {
    NSDictionary *attrs = NEAttributes(self.entity);
    NSString *domain = NEDomain(self.entityID);
    NSMutableArray *lines = [NSMutableArray array];

    if ([domain isEqualToString:@"weather"]) {
        NSArray *specs = @[
            @[@"humidity", @"Umidità", @"%"],
            @[@"pressure", @"Pressione", @"pressure_unit"],
            @[@"wind_speed", @"Vento", @"wind_speed_unit"],
            @[@"visibility", @"Visibilità", @"visibility_unit"],
            @[@"dew_point", @"Punto di rugiada", @"temperature_unit"]
        ];
        for (NSArray *spec in specs) {
            NSNumber *value = attrs[spec[0]];
            if (![value isKindOfClass:[NSNumber class]]) continue;
            NSString *unit = [spec[2] length] <= 2 ? spec[2]
                : ([attrs[spec[2]] isKindOfClass:[NSString class]]
                    ? attrs[spec[2]] : @"");
            [lines addObject:[NSString stringWithFormat:@"%@: %@ %@",
                spec[1], NEFormatNumber(value.doubleValue, 1), unit]];
        }
    } else if ([domain isEqualToString:@"person"] ||
               [domain isEqualToString:@"device_tracker"]) {
        NSString *source = attrs[@"source"];
        if ([source isKindOfClass:[NSString class]])
            [lines addObject:[@"Origine: " stringByAppendingString:source]];
    }

    return [lines componentsJoinedByString:@"\n"];
}

- (void)refresh {
    NSDictionary *entity = self.entity;
    NSString *name = NEName(entity, self.registry);
    UIColor *color = NEIconColor(entity);
    BOOL unavailable = NEIsUnavailable(entity);
    BOOL active = NEIsActive(entity);

    self.titleLabel.text = self.nas
        ? ([NineNASAdapter configuredTitle] ?: name) : name;
    self.subtitleLabel.text = self.area.length ? self.area : @"Senza stanza";
    self.stateLabel.text = NEStateText(entity, self.registry);
    self.stateLabel.textColor = NTText();

    NSString *changed = NERelativeTime(entity[@"last_changed"]);
    self.detailLabel.text = changed
        ? [@"Ultima modifica: " stringByAppendingString:changed] : @"";

    UIColor *activeColor = NEActiveColor(entity);

    switch (self.kind) {
        case NineInfoKindLight: {
            self.slider.fillColor = activeColor;
            if (!self.slider.isTracking &&
                (!self.sliderReleaseDate ||
                 -[self.sliderReleaseDate timeIntervalSinceNow] > 2)) {
                self.slider.value = active ? NEBrightnessPercent(entity) : 0;
            }
            self.slider.enabled = !unavailable;
            self.powerButton.backgroundColor = active
                ? [activeColor colorWithAlphaComponent:.25f]
                : NTHex(0x9E9E9E, .2f);
            [self.powerButton setTitleColor:active ? activeColor : NTText()
                                   forState:UIControlStateNormal];
            self.powerButton.enabled = !unavailable;
            break;
        }

        case NineInfoKindToggle:
            self.toggle.fillColor = activeColor;
            self.toggle.on = active;
            self.toggle.enabled = !unavailable;
            self.toggle.alpha = unavailable ? .4f : 1;
            break;

        case NineInfoKindCover:
            for (UIButton *button in self.roundButtons) {
                button.enabled = !unavailable;
                button.alpha = unavailable ? .4f : 1;
            }
            break;

        case NineInfoKindClimate: {
            NSDictionary *attrs = NEAttributes(entity);
            double target = isnan(self.pendingTemperature)
                ? [attrs[@"temperature"] doubleValue] : self.pendingTemperature;
            NSString *unit = [attrs[@"temperature_unit"] isKindOfClass:[NSString class]]
                ? attrs[@"temperature_unit"] : @"°";
            self.stateLabel.text = [NSString stringWithFormat:@"%@ %@",
                NEFormatNumber(target, 1), unit];
            self.stateLabel.font = NTMediumFont(36);
            self.detailLabel.numberOfLines = 2;
            self.detailLabel.text = NEStateText(entity, self.registry);
            for (UIButton *button in self.roundButtons) {
                button.enabled = !unavailable;
            }
            break;
        }

        case NineInfoKindMedia:
        case NineInfoKindVacuum:
            [self refreshDeviceControls];
            break;

        case NineInfoKindNAS: {
            // Il livello è aggiornato dalla dashboard.
            NSString *nasChanged = NERelativeTime(self.nas.lastChanged);
            self.detailLabel.text = nasChanged
                ? [@"Ultima modifica: " stringByAppendingString:nasChanged] : @"";
            self.stateLabel.text = [self.nas statusText];
            self.stateLabel.textColor = [self.nas color];
            self.bigIcon.iconName = [self.nas iconName];
            self.bigIcon.textColor = [self.nas color];
            self.bigIconCircle.backgroundColor =
                [[self.nas color] colorWithAlphaComponent:.2f];

            UIButton *power = self.pillButtons[0];
            UIButton *force = self.pillButtons[1];
            BOOL on = self.nas.poweredOn;
            [power setTitle:on ? @"Spegni NAS (graceful)" : @"Accendi NAS"
                   forState:UIControlStateNormal];
            power.backgroundColor = on ? NTHex(0xFFA600, .22f) : NTPrimary();
            [power setTitleColor:on ? NTWarning() : [UIColor whiteColor]
                        forState:UIControlStateNormal];
            power.enabled = [NineNASAdapter gracefulService] != nil &&
                self.nas.level != NineNASLevelUnknown;
            power.alpha = power.enabled ? 1 : .4f;
            force.hidden = ![NineNASAdapter forceService] ||
                self.nas.level == NineNASLevelOff;
            break;
        }

        case NineInfoKindAction:
        default:
            self.bigIcon.iconName = NEIconName(entity, self.registry);
            self.bigIcon.textColor = color;
            self.bigIconCircle.backgroundColor =
                [color colorWithAlphaComponent:.2f];
            self.attributesLabel.text = [self attributesText];
            [self setNeedsLayout];
            for (UIButton *button in self.pillButtons) {
                button.enabled = !unavailable;
                button.alpha = unavailable ? .4f : 1;
            }
            break;
    }
}

#pragma mark - Azioni

- (void)call:(NSString *)service data:(NSDictionary *)data {
    [self.delegate moreInfo:self
                callService:service
                     domain:NEDomain(self.entityID)
                   entityID:self.entityID
                       data:data ?: @{}];
}

- (void)sliderMoved {
    self.stateLabel.text = [NSString stringWithFormat:@"%ld%%",
        (long)lroundf(self.slider.value)];
}

- (void)sliderReleased {
    self.sliderReleaseDate = [NSDate date];
    NSInteger percent = MAX(1, MIN(100, lroundf(self.slider.value)));
    [self call:@"turn_on" data:@{@"brightness_pct": @(percent)}];
}

- (void)togglePower {
    [self call:NEIsActive(self.entity) ? @"turn_off" : @"turn_on" data:nil];
}

- (void)toggleChanged {
    [self call:self.toggle.on ? @"turn_on" : @"turn_off" data:nil];
}

- (void)coverButton:(UIButton *)button {
    [self call:button.accessibilityIdentifier data:nil];
}

- (void)temperatureStep:(UIButton *)button {
    NSDictionary *attrs = NEAttributes(self.entity);
    double step = [attrs[@"target_temp_step"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"target_temp_step"] doubleValue] : 0.5;
    double minimum = [attrs[@"min_temp"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"min_temp"] doubleValue] : 7;
    double maximum = [attrs[@"max_temp"] isKindOfClass:[NSNumber class]]
        ? [attrs[@"max_temp"] doubleValue] : 35;
    if (step <= 0 || !isfinite(step)) step = 0.5;

    double current = isnan(self.pendingTemperature)
        ? [attrs[@"temperature"] doubleValue] : self.pendingTemperature;

    self.pendingTemperature =
        MAX(minimum, MIN(maximum, current + step * button.tag));
    [self refresh];

    [self.temperatureTimer invalidate];
    self.temperatureTimer = [NSTimer
        scheduledTimerWithTimeInterval:1.2
                                target:self
                              selector:@selector(commitTemperature)
                              userInfo:nil
                               repeats:NO];
}

- (void)commitTemperature {
    self.temperatureTimer = nil;
    if (isnan(self.pendingTemperature)) return;
    double value = self.pendingTemperature;
    self.pendingTemperature = NAN;
    [self call:@"set_temperature" data:@{@"temperature": @(value)}];
}

- (void)runAction {
    NSString *domain = NEDomain(self.entityID);
    NSString *service = [domain isEqualToString:@"button"] ||
                        [domain isEqualToString:@"input_button"]
        ? @"press" : @"turn_on";
    [self call:service data:nil];
}

- (void)nasGraceful {
    [self.delegate moreInfo:self nasPowerForce:NO];
}

- (void)nasForce {
    [self.delegate moreInfo:self nasPowerForce:YES];
}

#pragma mark - Media e aspirapolvere

// Bit di supported_features di Home Assistant.
static NSInteger const NineMediaPause = 1, NineMediaVolumeSet = 4,
    NineMediaVolumeMute = 8, NineMediaPrevious = 16, NineMediaNext = 32,
    NineMediaTurnOn = 128, NineMediaTurnOff = 256, NineMediaVolumeStep = 1024,
    NineMediaSelectSource = 2048, NineMediaPlay = 16384;

static NSInteger const NineVacuumTurnOn = 1, NineVacuumPause = 4,
    NineVacuumStop = 8, NineVacuumReturnHome = 16, NineVacuumFanSpeed = 32,
    NineVacuumLocate = 512, NineVacuumCleanSpot = 1024, NineVacuumStart = 8192;

- (NSInteger)features {
    return [NEAttributes(self.entity)[@"supported_features"] integerValue];
}

- (UIButton *)deviceButton:(NSString *)icon
                    action:(NSString *)action
                     label:(NSString *)label
                  diameter:(CGFloat)diameter
                   caption:(BOOL)caption {
    UIColor *tint = self.kind == NineInfoKindVacuum
        ? NTHex(0x009688, .22f) : NTHex(0x03A9F4, .2f);
    UIButton *button = NineRoundButton(icon, diameter, tint, NTText());
    button.accessibilityIdentifier = action;
    button.accessibilityLabel = label;
    [button addTarget:self
               action:@selector(deviceButtonTapped:)
     forControlEvents:UIControlEventTouchUpInside];

    if (caption) {
        UILabel *text = [[UILabel alloc]
            initWithFrame:CGRectMake(-20, diameter + 4, diameter + 40, 16)];
        text.text = label;
        text.font = NTFont(12);
        text.textColor = NTSecondaryText();
        text.textAlignment = NSTextAlignmentCenter;
        [button addSubview:text];
        button.clipsToBounds = NO;
    }

    [self.card addSubview:button];
    return button;
}

- (BOOL)remoteUsesADBNames {
    // L'integrazione Android TV (ADB) espone adb_response e usa i
    // nomi UP/DOWN/CENTER; Android TV Remote usa DPAD_UP ecc.
    return NEAttributes(self.entity)[@"adb_response"] != nil;
}

- (NSString *)remoteKey:(NSString *)name {
    if ([self remoteUsesADBNames]) return name;
    NSDictionary *map = @{@"UP": @"DPAD_UP", @"DOWN": @"DPAD_DOWN",
                          @"LEFT": @"DPAD_LEFT", @"RIGHT": @"DPAD_RIGHT",
                          @"CENTER": @"DPAD_CENTER"};
    return map[name] ?: name;
}

- (void)buildMediaControls {
    NSInteger features = [self features];
    NSMutableArray *transport = [NSMutableArray array];

    if (features & (NineMediaTurnOn | NineMediaTurnOff)) {
        [transport addObject:[self deviceButton:@"power" action:@"svc:__power"
            label:@"Accendi o spegni" diameter:52 caption:NO]];
    }
    if (features & NineMediaPrevious) {
        [transport addObject:[self deviceButton:@"skip-previous"
            action:@"svc:media_previous_track" label:@"Precedente"
            diameter:52 caption:NO]];
    }
    if (features & (NineMediaPause | NineMediaPlay)) {
        [transport addObject:[self deviceButton:@"play-pause"
            action:@"svc:media_play_pause" label:@"Riproduci o pausa"
            diameter:52 caption:NO]];
    }
    if (features & NineMediaNext) {
        [transport addObject:[self deviceButton:@"skip-next"
            action:@"svc:media_next_track" label:@"Successivo"
            diameter:52 caption:NO]];
    }
    self.transportButtons = transport;

    NSMutableArray *remote = [NSMutableArray array];

    if (self.related[@"remote"]) {
        // Croce direzionale: su, sinistra, OK, destra, giù.
        NSArray *pad = @[
            @[@"chevron-up", @"key:UP", @"Su"],
            @[@"chevron-left", @"key:LEFT", @"Sinistra"],
            @[@"circle-medium", @"key:CENTER", @"OK"],
            @[@"chevron-right", @"key:RIGHT", @"Destra"],
            @[@"chevron-down", @"key:DOWN", @"Giù"]
        ];
        for (NSArray *spec in pad) {
            [remote addObject:[self deviceButton:spec[0] action:spec[1]
                label:spec[2] diameter:56 caption:NO]];
        }

        NSArray *extra = @[
            @[@"arrow-left", @"key:BACK", @"Indietro"],
            @[@"home", @"key:HOME", @"Home"],
            @[@"menu", @"key:MENU", @"Menu"],
            @[@"volume-minus", @"key:VOLUME_DOWN", @"Volume giù"],
            @[@"volume-plus", @"key:VOLUME_UP", @"Volume su"]
        ];
        for (NSArray *spec in extra) {
            [remote addObject:[self deviceButton:spec[0] action:spec[1]
                label:spec[2] diameter:46 caption:NO]];
        }
    } else if (features & (NineMediaVolumeStep | NineMediaVolumeSet)) {
        [transport addObject:[self deviceButton:@"volume-minus"
            action:@"svc:volume_down" label:@"Volume giù" diameter:52 caption:NO]];
        [transport addObject:[self deviceButton:@"volume-plus"
            action:@"svc:volume_up" label:@"Volume su" diameter:52 caption:NO]];
        if (features & NineMediaVolumeMute) {
            [transport addObject:[self deviceButton:@"volume-off"
                action:@"svc:__mute" label:@"Silenzia" diameter:52 caption:NO]];
        }
        self.transportButtons = transport;
    }
    self.remoteButtons = remote;

    if (features & NineMediaSelectSource) {
        self.choiceButton = NinePillButton(@"Sorgente",
            NTHex(0x03A9F4, .16f), NTPrimary());
        [self.choiceButton addTarget:self action:@selector(chooseSource)
                    forControlEvents:UIControlEventTouchUpInside];
        [self.card addSubview:self.choiceButton];
    }

    if (!remote.count) [self buildBigIcon];
}

- (void)buildVacuumControls {
    NSInteger features = [self features];
    NSMutableArray *buttons = [NSMutableArray array];

    if (features & (NineVacuumStart | NineVacuumTurnOn)) {
        [buttons addObject:[self deviceButton:@"play" action:@"svc:start"
            label:@"Avvia" diameter:60 caption:YES]];
    }
    if (features & NineVacuumPause) {
        [buttons addObject:[self deviceButton:@"pause" action:@"svc:pause"
            label:@"Pausa" diameter:60 caption:YES]];
    }
    if (features & NineVacuumStop) {
        [buttons addObject:[self deviceButton:@"stop" action:@"svc:stop"
            label:@"Ferma" diameter:60 caption:YES]];
    }
    if (features & NineVacuumReturnHome) {
        [buttons addObject:[self deviceButton:@"home-import-outline"
            action:@"svc:return_to_base" label:@"Alla base"
            diameter:60 caption:YES]];
    }
    if (features & NineVacuumLocate) {
        [buttons addObject:[self deviceButton:@"map-marker"
            action:@"svc:locate" label:@"Trova" diameter:60 caption:YES]];
    }
    if (features & NineVacuumCleanSpot) {
        [buttons addObject:[self deviceButton:@"target"
            action:@"svc:clean_spot" label:@"Spot" diameter:60 caption:YES]];
    }
    self.transportButtons = buttons;

    NSArray *speeds = NEAttributes(self.entity)[@"fan_speed_list"];
    if ((features & NineVacuumFanSpeed) &&
        [speeds isKindOfClass:[NSArray class]] && speeds.count) {
        self.choiceButton = NinePillButton(@"Aspirazione",
            NTHex(0x009688, .18f), NTHex(0x4DB6AC, 1));
        [self.choiceButton addTarget:self action:@selector(chooseFanSpeed)
                    forControlEvents:UIControlEventTouchUpInside];
        [self.card addSubview:self.choiceButton];
    }

    [self buildBigIcon];
}

- (void)layoutRow:(NSArray *)buttons centerY:(CGFloat)y width:(CGFloat)width
          spacing:(CGFloat)spacing {
    NSUInteger count = buttons.count;
    if (!count) return;
    CGFloat step = MIN(spacing, (width - 40) / count);
    CGFloat start = width / 2 - step * (count - 1) / 2;
    for (NSUInteger i = 0; i < count; i++) {
        [buttons[i] setCenter:CGPointMake(start + step * i, y)];
    }
}

- (void)layoutMediaWithTop:(CGFloat)top width:(CGFloat)width {
    CGFloat midX = width / 2;

    if (!self.remoteButtons.count) {
        self.bigIconCircle.frame = CGRectMake(midX - 48, top + 10, 96, 96);
        [self layoutRow:self.transportButtons centerY:top + 160
                  width:width spacing:72];
        self.choiceButton.frame = CGRectMake(midX - 120, top + 214, 240, 44);
        return;
    }

    [self layoutRow:self.transportButtons centerY:top + 30 width:width spacing:72];

    // Croce direzionale centrata.
    CGFloat padY = top + 160;
    NSArray *pad = [self.remoteButtons subarrayWithRange:NSMakeRange(0, 5)];
    [pad[0] setCenter:CGPointMake(midX, padY - 66)];
    [pad[1] setCenter:CGPointMake(midX - 66, padY)];
    [pad[2] setCenter:CGPointMake(midX, padY)];
    [pad[3] setCenter:CGPointMake(midX + 66, padY)];
    [pad[4] setCenter:CGPointMake(midX, padY + 66)];

    NSArray *extra = [self.remoteButtons
        subarrayWithRange:NSMakeRange(5, self.remoteButtons.count - 5)];
    [self layoutRow:extra centerY:padY + 136 width:width spacing:66];

    self.choiceButton.frame = CGRectMake(midX - 120, padY + 182, 240, 44);
}

- (void)layoutVacuumWithTop:(CGFloat)top width:(CGFloat)width {
    CGFloat midX = width / 2;
    self.bigIconCircle.frame = CGRectMake(midX - 48, top + 6, 96, 96);
    [self layoutRow:self.transportButtons centerY:top + 160 width:width spacing:82];
    self.choiceButton.frame = CGRectMake(midX - 120, top + 236, 240, 44);
}

- (void)updateRelatedStates:(NSDictionary *)relatedStates {
    self.relatedStates = relatedStates ?: @{};
    [self refresh];
}

- (void)refreshDeviceControls {
    NSDictionary *entity = self.entity;
    NSDictionary *attrs = NEAttributes(entity);
    BOOL unavailable = NEIsUnavailable(entity);
    UIColor *color = NEIconColor(entity);

    self.bigIcon.iconName = NEIconName(entity, self.registry);
    self.bigIcon.textColor = color;
    self.bigIconCircle.backgroundColor = [color colorWithAlphaComponent:.2f];

    NSMutableArray *details = [NSMutableArray array];

    if (self.kind == NineInfoKindMedia) {
        NSString *artist = [attrs[@"media_artist"] isKindOfClass:[NSString class]]
            ? attrs[@"media_artist"] : nil;
        NSString *app = [attrs[@"app_name"] isKindOfClass:[NSString class]]
            ? attrs[@"app_name"] : nil;
        if (artist.length) [details addObject:artist];
        if (app.length) [details addObject:app];

        NSString *source = [attrs[@"source"] isKindOfClass:[NSString class]]
            ? attrs[@"source"] : nil;
        [self.choiceButton setTitle:source.length
            ? [@"Sorgente: " stringByAppendingString:source] : @"Scegli sorgente"
                           forState:UIControlStateNormal];
        NSArray *sources = attrs[@"source_list"];
        BOOL hasSources = [sources isKindOfClass:[NSArray class]] && sources.count;
        self.choiceButton.enabled = hasSources && !unavailable;
        self.choiceButton.alpha = self.choiceButton.enabled ? 1 : .4f;
    } else {
        NSString *batteryID = self.related[@"battery"];
        NSDictionary *battery = batteryID ? self.relatedStates[batteryID] : nil;
        id level = attrs[@"battery_level"];
        if (battery && !NEIsUnavailable(battery)) {
            [details addObject:[@"Batteria " stringByAppendingString:
                NEStateText(battery, nil)]];
        } else if ([level isKindOfClass:[NSNumber class]]) {
            [details addObject:[NSString stringWithFormat:@"Batteria %@ %%", level]];
        }

        NSString *speed = [attrs[@"fan_speed"] isKindOfClass:[NSString class]]
            ? attrs[@"fan_speed"] : nil;
        [self.choiceButton setTitle:speed.length
            ? [@"Aspirazione: " stringByAppendingString:speed] : @"Aspirazione"
                           forState:UIControlStateNormal];
        self.choiceButton.enabled = !unavailable;
        self.choiceButton.alpha = unavailable ? .4f : 1;
    }

    NSString *changed = NERelativeTime(entity[@"last_changed"]);
    if (changed) [details addObject:changed];
    self.detailLabel.text = [details componentsJoinedByString:@" · "];

    NSString *remoteID = self.related[@"remote"];
    BOOL remoteReady = remoteID && !unavailable &&
        ![NEStateValue(entity) isEqualToString:@"off"];

    for (UIButton *button in self.transportButtons) {
        button.enabled = !unavailable;
        button.alpha = unavailable ? .4f : 1;
    }
    for (UIButton *button in self.remoteButtons) {
        button.enabled = remoteReady;
        button.alpha = remoteReady ? 1 : .35f;
    }
}

- (void)deviceButtonTapped:(UIButton *)button {
    NSString *action = button.accessibilityIdentifier;

    if ([action hasPrefix:@"key:"]) {
        NSString *remoteID = self.related[@"remote"];
        if (!remoteID) return;
        NSString *key = [self remoteKey:[action substringFromIndex:4]];
        [self.delegate moreInfo:self
                    callService:@"send_command"
                         domain:@"remote"
                       entityID:remoteID
                           data:@{@"command": key}];
        return;
    }

    NSString *service = [action substringFromIndex:4];

    if ([service isEqualToString:@"__power"]) {
        service = [NEStateValue(self.entity) isEqualToString:@"off"]
            ? @"turn_on" : @"turn_off";
    } else if ([service isEqualToString:@"__mute"]) {
        BOOL muted = [NEAttributes(self.entity)[@"is_volume_muted"] boolValue];
        [self call:@"volume_mute" data:@{@"is_volume_muted": @(!muted)}];
        return;
    }

    [self call:service data:nil];
}

- (void)chooseSource {
    NSDictionary *attrs = NEAttributes(self.entity);
    NSArray *sources = attrs[@"source_list"];
    if (![sources isKindOfClass:[NSArray class]] || !sources.count) return;

    __weak typeof(self) weakSelf = self;
    [self.delegate moreInfo:self chooseFrom:sources title:@"Sorgente"
                    current:attrs[@"source"] source:self.choiceButton
                 completion:^(NSString *choice) {
        [weakSelf call:@"select_source" data:@{@"source": choice}];
    }];
}

- (void)chooseFanSpeed {
    NSDictionary *attrs = NEAttributes(self.entity);
    NSArray *speeds = attrs[@"fan_speed_list"];
    if (![speeds isKindOfClass:[NSArray class]] || !speeds.count) return;

    __weak typeof(self) weakSelf = self;
    [self.delegate moreInfo:self chooseFrom:speeds title:@"Aspirazione"
                    current:attrs[@"fan_speed"] source:self.choiceButton
                 completion:^(NSString *choice) {
        [weakSelf call:@"set_fan_speed" data:@{@"fan_speed": choice}];
    }];
}

#pragma mark - Presentazione

- (void)showInView:(UIView *)host {
    self.frame = host.bounds;
    [host addSubview:self];
    [self layoutIfNeeded];

    self.card.alpha = 0;
    self.card.transform = CGAffineTransformMakeScale(.94f, .94f);

    [UIView animateWithDuration:.2 animations:^{
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:.6f];
        self.card.alpha = 1;
        self.card.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    if (!self.superview) return;

    [self.temperatureTimer invalidate];
    if (!isnan(self.pendingTemperature) && self.kind == NineInfoKindClimate) {
        [self commitTemperature];
    }
    self.temperatureTimer = nil;

    [UIView animateWithDuration:.18 animations:^{
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        self.card.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self.delegate moreInfoDidClose:self];
    }];
}

@end
