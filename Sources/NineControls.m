#import "NineControls.h"
#import "NineIcons.h"
#import "NineTheme.h"

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
