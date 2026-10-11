#import "NineControls.h"
#import "NineIcons.h"
#import "NineTheme.h"
#import "NineEntity.h"

#pragma mark - Tile

@interface NineTileView ()
@property (nonatomic, strong, readwrite) NineIconView *iconView;
@property (nonatomic, strong, readwrite) UIView *iconCircle;
@property (nonatomic, strong, readwrite) UILabel *nameLabel;
@property (nonatomic, strong, readwrite) UILabel *stateLabel;
@property (nonatomic, strong) UIButton *iconButton;
@end

@implementation NineTileView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = NTCard();
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
        self.layer.borderColor = NTBorder().CGColor;

        _iconCircle = [[UIView alloc]
            initWithFrame:CGRectMake(10, 10, 36, 36)];
        _iconCircle.layer.cornerRadius = 18;
        _iconCircle.userInteractionEnabled = NO;
        [self addSubview:_iconCircle];

        _iconView = [[NineIconView alloc]
            initWithFrame:_iconCircle.bounds iconSize:22];
        [_iconCircle addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = NTMediumFont(14);
        _nameLabel.textColor = NTText();
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_nameLabel];

        _stateLabel = [[UILabel alloc] init];
        _stateLabel.font = NTFont(12);
        _stateLabel.textColor = NTSecondaryText();
        [self addSubview:_stateLabel];

        _iconButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _iconButton.frame = CGRectMake(0, 0, 56, 56);
        [_iconButton addTarget:self
                        action:@selector(iconTapped)
              forControlEvents:UIControlEventTouchUpInside];
        _iconButton.hidden = YES;
        [self addSubview:_iconButton];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGFloat top = (height - 36) / 2;

    self.iconCircle.frame = CGRectMake(10, top, 36, 36);
    self.iconButton.frame = CGRectMake(0, 0, 56, height);

    CGFloat x = 56;
    CGFloat labelWidth = MAX(10, width - x - 10);

    self.nameLabel.frame = CGRectMake(x, height / 2 - 19, labelWidth, 20);
    self.stateLabel.frame = CGRectMake(x, height / 2 + 1, labelWidth, 17);
}

- (void)setIconTapEnabled:(BOOL)enabled {
    _iconTapEnabled = enabled;
    self.iconButton.hidden = !enabled;
}

- (void)iconTapped {
    if (self.onIconTap) self.onIconTap(self);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? NTCardPressed() : NTCard();
}

- (void)setName:(NSString *)name
          state:(NSString *)state
           icon:(NSString *)icon
          color:(UIColor *)color
         active:(BOOL)active
    unavailable:(BOOL)unavailable {

    self.nameLabel.text = name;
    self.stateLabel.text = state;
    self.iconView.iconName = icon;
    self.iconView.textColor = color;

    // Cerchio con il colore dello stato al 20%, come nel frontend.
    self.iconCircle.backgroundColor =
        [color colorWithAlphaComponent:unavailable ? .10f : .20f];

    self.nameLabel.textColor = unavailable ? NTSecondaryText() : NTText();

    self.accessibilityLabel =
        [NSString stringWithFormat:@"%@, %@", name ?: @"", state ?: @""];
}

@end

#pragma mark - Griglia valori

@implementation NineValueView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.iconCircle.hidden = YES;
        self.nameLabel.font = NTMediumFont(12);
        self.nameLabel.textColor = NTSecondaryText();
        self.stateLabel.font = NTMediumFont(21);
        self.stateLabel.adjustsFontSizeToFitWidth = YES;
        self.stateLabel.minimumScaleFactor = .6f;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    self.nameLabel.frame = CGRectMake(12, 9, width - 24, 16);
    self.stateLabel.frame = CGRectMake(12, 27, width - 24, 28);
}

- (void)setName:(NSString *)name
          state:(NSString *)state
           icon:(NSString *)icon
          color:(UIColor *)color
         active:(BOOL)active
    unavailable:(BOOL)unavailable {
    [super setName:name state:state icon:icon color:color
            active:active unavailable:unavailable];
    self.nameLabel.textColor = NTSecondaryText();
    self.stateLabel.textColor = unavailable ? NTDisabledText() : color;
}

@end

#pragma mark - Meteo

@interface NineWeatherView ()
@property (nonatomic, strong) NineIconView *bigIcon;
@property (nonatomic, strong) UILabel *temperatureLabel;
@property (nonatomic, strong) UILabel *conditionLabel;
@property (nonatomic, strong) UILabel *detailsLabel;
@property (nonatomic, strong) NSMutableArray *days;
@property (nonatomic, strong) NSDictionary *entity;
@end

@implementation NineWeatherView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.iconCircle.hidden = YES;
        self.nameLabel.hidden = YES;
        self.stateLabel.hidden = YES;

        _bigIcon = [[NineIconView alloc] initWithFrame:CGRectZero iconSize:58];
        _bigIcon.textColor = NTPrimary();
        [self addSubview:_bigIcon];

        _temperatureLabel = [[UILabel alloc] init];
        _temperatureLabel.font = [UIFont systemFontOfSize:40 weight:UIFontWeightLight];
        _temperatureLabel.textColor = NTText();
        [self addSubview:_temperatureLabel];

        _conditionLabel = [[UILabel alloc] init];
        _conditionLabel.font = NTMediumFont(14);
        _conditionLabel.textColor = NTText();
        [self addSubview:_conditionLabel];

        _detailsLabel = [[UILabel alloc] init];
        _detailsLabel.font = NTFont(12);
        _detailsLabel.textColor = NTSecondaryText();
        _detailsLabel.numberOfLines = 2;
        [self addSubview:_detailsLabel];

        _days = [NSMutableArray array];
    }
    return self;
}

- (void)setName:(NSString *)name state:(NSString *)state icon:(NSString *)icon
          color:(UIColor *)color active:(BOOL)active unavailable:(BOOL)unavailable {
    // Il contenuto arriva da updateWithEntity:.
}

- (void)updateWithEntity:(NSDictionary *)entity {
    self.entity = entity;
    NSDictionary *attrs = NEAttributes(entity);
    NSString *condition = NEStateValue(entity);

    self.bigIcon.iconName = NEWeatherIcon(condition);
    self.conditionLabel.text = NEWeatherConditionText(condition);

    NSNumber *temperature = attrs[@"temperature"];
    NSString *unit = [attrs[@"temperature_unit"] isKindOfClass:[NSString class]]
        ? attrs[@"temperature_unit"] : @"°";
    self.temperatureLabel.text = [temperature isKindOfClass:[NSNumber class]]
        ? [NSString stringWithFormat:@"%@ %@",
            NEFormatNumber(temperature.doubleValue, 1), unit] : @"—";

    NSMutableArray *details = [NSMutableArray array];
    if ([attrs[@"humidity"] isKindOfClass:[NSNumber class]])
        [details addObject:[NSString stringWithFormat:@"Umidità %@ %%",
            NEFormatNumber([attrs[@"humidity"] doubleValue], 0)]];
    if ([attrs[@"wind_speed"] isKindOfClass:[NSNumber class]]) {
        NSString *windUnit = [attrs[@"wind_speed_unit"] isKindOfClass:[NSString class]]
            ? attrs[@"wind_speed_unit"] : @"";
        [details addObject:[NSString stringWithFormat:@"Vento %@ %@",
            NEFormatNumber([attrs[@"wind_speed"] doubleValue], 0), windUnit]];
    }
    self.detailsLabel.text = [details componentsJoinedByString:@"\n"];
    self.accessibilityLabel = [NSString stringWithFormat:@"Meteo, %@, %@",
        self.conditionLabel.text ?: @"", self.temperatureLabel.text ?: @""];

    [self rebuildDays];
}

- (void)setForecast:(NSArray *)forecast {
    _forecast = forecast;
    [self rebuildDays];
}

- (void)rebuildDays {
    for (UIView *view in self.days) [view removeFromSuperview];
    [self.days removeAllObjects];

    static NSDateFormatter *parser, *weekday;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        parser = [[NSDateFormatter alloc] init];
        parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        weekday = [[NSDateFormatter alloc] init];
        weekday.locale = [NSLocale localeWithLocaleIdentifier:@"it_IT"];
        weekday.dateFormat = @"EEE";
    });

    NSUInteger count = MIN((NSUInteger)5, self.forecast.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSDictionary *day = self.forecast[i];
        if (![day isKindOfClass:[NSDictionary class]]) continue;

        UIView *column = [[UIView alloc] init];
        column.userInteractionEnabled = NO;

        UILabel *name = [[UILabel alloc] init];
        NSString *iso = [day[@"datetime"] isKindOfClass:[NSString class]]
            ? [day[@"datetime"] stringByReplacingOccurrencesOfString:@"Z"
                                                          withString:@"+00:00"] : nil;
        NSRange fraction = iso ? [iso rangeOfString:@"\\.[0-9]+"
                                            options:NSRegularExpressionSearch]
                               : NSMakeRange(NSNotFound, 0);
        if (fraction.location != NSNotFound)
            iso = [iso stringByReplacingCharactersInRange:fraction withString:@""];
        NSDate *date = iso ? [parser dateFromString:iso] : nil;
        name.text = date ? [[weekday stringFromDate:date] capitalizedString] : @"";
        name.font = NTMediumFont(12);
        name.textColor = NTSecondaryText();
        name.textAlignment = NSTextAlignmentCenter;
        [column addSubview:name];

        NineIconView *icon = [[NineIconView alloc] initWithFrame:CGRectZero iconSize:22];
        icon.iconName = NEWeatherIcon(day[@"condition"]);
        icon.textColor = NTPrimary();
        [column addSubview:icon];

        UILabel *range = [[UILabel alloc] init];
        NSNumber *high = day[@"temperature"], *low = day[@"templow"];
        range.text = [high isKindOfClass:[NSNumber class]]
            ? ([low isKindOfClass:[NSNumber class]]
                ? [NSString stringWithFormat:@"%@° / %@°",
                    NEFormatNumber(high.doubleValue, 0), NEFormatNumber(low.doubleValue, 0)]
                : [NSString stringWithFormat:@"%@°", NEFormatNumber(high.doubleValue, 0)])
            : @"";
        range.font = NTFont(12);
        range.textColor = NTText();
        range.textAlignment = NSTextAlignmentCenter;
        range.adjustsFontSizeToFitWidth = YES;
        range.minimumScaleFactor = .7f;
        [column addSubview:range];

        [self addSubview:column];
        [self.days addObject:column];
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;

    self.bigIcon.frame = CGRectMake(12, 14, 70, 70);
    self.temperatureLabel.frame = CGRectMake(90, 14, width - 190, 46);
    self.conditionLabel.frame = CGRectMake(92, 58, width - 194, 20);
    self.detailsLabel.frame = CGRectMake(width - 112, 22, 100, 40);
    self.detailsLabel.textAlignment = NSTextAlignmentRight;

    if (!self.days.count) return;

    // Riga delle previsioni sotto un divisore.
    CGFloat top = 98;
    CGFloat columnWidth = (width - 16) / self.days.count;
    for (NSUInteger i = 0; i < self.days.count; i++) {
        UIView *column = self.days[i];
        column.frame = CGRectMake(8 + columnWidth * i, top, columnWidth, 74);
        UILabel *name = column.subviews[0];
        UIView *icon = column.subviews[1];
        UILabel *range = column.subviews[2];
        name.frame = CGRectMake(0, 0, columnWidth, 16);
        icon.frame = CGRectMake((columnWidth - 28) / 2, 18, 28, 28);
        range.frame = CGRectMake(2, 48, columnWidth - 4, 16);
    }
}

@end

#pragma mark - Orologio

@interface NineClockView ()
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation NineClockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = NTCard();
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
        self.layer.borderColor = NTBorder().CGColor;

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:54
                                                           weight:UIFontWeightLight];
        _timeLabel.textColor = NTText();
        _timeLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel.adjustsFontSizeToFitWidth = YES;
        _timeLabel.minimumScaleFactor = .5f;
        [self addSubview:_timeLabel];

        _dateLabel = [[UILabel alloc] init];
        _dateLabel.font = NTFont(15);
        _dateLabel.textColor = NTSecondaryText();
        _dateLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_dateLabel];

        self.isAccessibilityElement = YES;
        [self tick];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.timeLabel.frame = CGRectMake(12, height / 2 - 44, width - 24, 62);
    self.dateLabel.frame = CGRectMake(12, height / 2 + 20, width - 24, 20);
}

- (void)setTwelveHour:(BOOL)twelveHour {
    _twelveHour = twelveHour;
    [self tick];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.timer invalidate];
    self.timer = nil;

    if (self.window) {
        [self tick];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector(tick)
                                                    userInfo:nil
                                                     repeats:YES];
    }
}

- (void)tick {
    static NSDateFormatter *time24, *time12, *date;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLocale *italian = [NSLocale localeWithLocaleIdentifier:@"it_IT"];
        time24 = [[NSDateFormatter alloc] init];
        time24.locale = italian;
        time24.dateFormat = @"HH:mm:ss";
        time12 = [[NSDateFormatter alloc] init];
        time12.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        time12.dateFormat = @"h:mm:ss a";
        date = [[NSDateFormatter alloc] init];
        date.locale = italian;
        date.dateFormat = @"EEEE d MMMM";
    });

    NSDate *now = [NSDate date];
    self.timeLabel.text = [(self.twelveHour ? time12 : time24) stringFromDate:now];
    self.dateLabel.text = [[date stringFromDate:now] capitalizedString];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
        self.timeLabel.text, self.dateLabel.text];
}

- (void)dealloc {
    [_timer invalidate];
}

@end

#pragma mark - Badge

@interface NineBadgeView ()
@property (nonatomic, strong) NineIconView *icon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@end

@implementation NineBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = NTCard();
        self.layer.cornerRadius = 18;
        self.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
        self.layer.borderColor = NTBorder().CGColor;

        _icon = [[NineIconView alloc]
            initWithFrame:CGRectMake(10, 8, 20, 20) iconSize:18];
        [self addSubview:_icon];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = NTMediumFont(10);
        _titleLabel.textColor = NTSecondaryText();
        [self addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.font = NTMediumFont(12);
        _valueLabel.textColor = NTText();
        [self addSubview:_valueLabel];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }

    return self;
}

- (void)setIcon:(NSString *)icon
          color:(UIColor *)color
          title:(NSString *)title
          value:(NSString *)value {

    self.icon.iconName = icon;
    self.icon.textColor = color;
    self.titleLabel.text = title;
    self.valueLabel.text = value;

    CGFloat textWidth = MAX(
        [title ?: @"" sizeWithAttributes:
            @{NSFontAttributeName: self.titleLabel.font}].width,
        [value ?: @"" sizeWithAttributes:
            @{NSFontAttributeName: self.valueLabel.font}].width);

    textWidth = MIN((CGFloat)200, ceilf(textWidth));

    CGRect frame = self.frame;
    frame.size = CGSizeMake(36 + textWidth + 14, 36);
    self.frame = frame;

    if (title.length) {
        self.titleLabel.frame = CGRectMake(36, 4, textWidth, 13);
        self.valueLabel.frame = CGRectMake(36, 16, textWidth, 16);
    } else {
        self.titleLabel.frame = CGRectZero;
        self.valueLabel.frame = CGRectMake(36, 9, textWidth, 18);
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@ %@",
        title ?: @"", value ?: @""];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? NTCardPressed() : NTCard();
}

@end

#pragma mark - Slider verticale

@implementation NineBigSlider

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _fillColor = NTHex(0xFFC107, 1);
        _minimumValue = 1;
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitAdjustable;
    }

    return self;
}

- (void)setValue:(CGFloat)value {
    _value = MAX(0, MIN(100, value));
    self.accessibilityValue =
        [NSString stringWithFormat:@"%ld%%", (long)lroundf(_value)];
    [self setNeedsDisplay];
}

- (void)setFillColor:(UIColor *)fillColor {
    _fillColor = fillColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGRect bounds = self.bounds;
    CGFloat radius = MIN(bounds.size.width / 2.6f, 40);

    UIBezierPath *track =
        [UIBezierPath bezierPathWithRoundedRect:bounds
                                   cornerRadius:radius];

    [[self.fillColor colorWithAlphaComponent:.20f] setFill];
    [track fill];

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [track addClip];

    CGFloat fillHeight = bounds.size.height * self.value / 100.0f;
    [self.fillColor setFill];
    UIRectFill(CGRectMake(0, bounds.size.height - fillHeight,
                          bounds.size.width, fillHeight));

    // Maniglia orizzontale come nello slider HA.
    if (fillHeight > 14) {
        [[UIColor colorWithWhite:1 alpha:.85f] setFill];
        CGFloat handleWidth = bounds.size.width * .3f;
        UIBezierPath *handle = [UIBezierPath bezierPathWithRoundedRect:
            CGRectMake((bounds.size.width - handleWidth) / 2,
                       bounds.size.height - fillHeight + 8,
                       handleWidth, 4)
                                                          cornerRadius:2];
        [handle fill];
    }

    CGContextRestoreGState(context);
}

- (void)updateWithTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:self];
    CGFloat height = MAX(1, self.bounds.size.height);
    CGFloat value = (1 - point.y / height) * 100.0f;
    self.value = MAX(self.minimumValue, MIN(100, value));
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateWithTouch:touch];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateWithTouch:touch];
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
}

- (void)accessibilityIncrement {
    self.value = MIN(100, self.value + 10);
    [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
}

- (void)accessibilityDecrement {
    self.value = MAX(self.minimumValue, self.value - 10);
    [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
}

@end

#pragma mark - Toggle verticale

@implementation NineBigToggle {
    NineIconView *_topIcon;
    NineIconView *_bottomIcon;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _fillColor = NTHex(0xFFC107, 1);
        _onIcon = @"power";
        _offIcon = @"power-off";

        _topIcon = [[NineIconView alloc] initWithFrame:CGRectZero iconSize:30];
        _bottomIcon = [[NineIconView alloc] initWithFrame:CGRectZero iconSize:30];
        [self addSubview:_topIcon];
        [self addSubview:_bottomIcon];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    _topIcon.frame = CGRectMake(0, h / 4 - 20, w, 40);
    _bottomIcon.frame = CGRectMake(0, h * 3 / 4 - 20, w, 40);
    [self refreshIcons];
}

- (void)refreshIcons {
    _topIcon.iconName = self.onIcon;
    _bottomIcon.iconName = self.offIcon;
    _topIcon.textColor = self.on ? [UIColor whiteColor] : NTSecondaryText();
    _bottomIcon.textColor = self.on ? NTSecondaryText() : [UIColor whiteColor];
    self.accessibilityValue = self.on ? @"Acceso" : @"Spento";
}

- (void)setOn:(BOOL)on {
    _on = on;
    [self refreshIcons];
    [self setNeedsDisplay];
}

- (void)setFillColor:(UIColor *)fillColor {
    _fillColor = fillColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGRect bounds = self.bounds;
    CGFloat radius = MIN(bounds.size.width / 2.6f, 40);

    UIBezierPath *track =
        [UIBezierPath bezierPathWithRoundedRect:bounds
                                   cornerRadius:radius];

    [(self.on ? [self.fillColor colorWithAlphaComponent:.20f]
              : NTHex(0x9E9E9E, .20f)) setFill];
    [track fill];

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [track addClip];

    CGFloat half = bounds.size.height / 2;
    CGRect knob = self.on
        ? CGRectMake(0, 0, bounds.size.width, half)
        : CGRectMake(0, half, bounds.size.width, half);

    [(self.on ? self.fillColor : NTHex(0x6F6F6F, 1)) setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(knob, 0, 0)
                                cornerRadius:radius] fill];

    CGContextRestoreGState(context);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint point = [touch locationInView:self];
    if (!CGRectContainsPoint(CGRectInset(self.bounds, -20, -20), point))
        return;

    BOOL wantsOn = point.y < self.bounds.size.height / 2;

    // Un tocco sulla metà già attiva inverte comunque lo stato.
    self.on = wantsOn == self.on ? !self.on : wantsOn;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (BOOL)accessibilityActivate {
    self.on = !self.on;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    return YES;
}

@end

UIButton *NineRoundButton(NSString *icon, CGFloat diameter,
                          UIColor *background, UIColor *tint) {
    UIButton *button = NineIconButton(icon, diameter * .45f, tint);
    button.frame = CGRectMake(0, 0, diameter, diameter);
    button.backgroundColor = background;
    button.layer.cornerRadius = diameter / 2;
    return button;
}

UIButton *NinePillButton(NSString *title, UIColor *background,
                         UIColor *textColor) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = background;
    button.layer.cornerRadius = 10;
    button.titleLabel.font = NTMediumFont(15);
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = .8f;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button setTitleColor:[textColor colorWithAlphaComponent:.5f]
                 forState:UIControlStateHighlighted];
    return button;
}
