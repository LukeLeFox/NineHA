#import <UIKit/UIKit.h>

@class NineIconView;

/*
 * Componenti grafici nativi che riproducono gli elementi
 * del frontend Home Assistant (tile card, badge, controlli
 * del pannello dettagli).
 */

// Tile card: icona in un cerchio colorato, nome e stato.
@interface NineTileView : UIControl

@property (nonatomic, copy) NSString *entityID;
@property (nonatomic, strong, readonly) NineIconView *iconView;
@property (nonatomic, strong, readonly) UIView *iconCircle;
@property (nonatomic, strong, readonly) UILabel *nameLabel;
@property (nonatomic, strong, readonly) UILabel *stateLabel;

// Tocco sull'icona (toggle rapido, come nell'app ufficiale).
@property (nonatomic, copy) void (^onIconTap)(NineTileView *tile);
@property (nonatomic, assign) BOOL iconTapEnabled;

- (void)setName:(NSString *)name
          state:(NSString *)state
           icon:(NSString *)icon
          color:(UIColor *)color
         active:(BOOL)active
    unavailable:(BOOL)unavailable;

@end

// Badge a pillola in cima alla dashboard.
@interface NineBadgeView : UIControl

@property (nonatomic, copy) NSString *entityID;

- (void)setIcon:(NSString *)icon
          color:(UIColor *)color
          title:(NSString *)title
          value:(NSString *)value;

@end

// Slider verticale grande (luminosità) come nel more-info HA.
@interface NineBigSlider : UIControl

@property (nonatomic, assign) CGFloat value;      // 0...100
@property (nonatomic, assign) CGFloat minimumValue;
@property (nonatomic, strong) UIColor *fillColor;

@end

// Interruttore verticale grande (on/off).
@interface NineBigToggle : UIControl

@property (nonatomic, assign, getter=isOn) BOOL on;
@property (nonatomic, strong) UIColor *fillColor;
@property (nonatomic, copy) NSString *onIcon;
@property (nonatomic, copy) NSString *offIcon;

@end

// Pulsante circolare con icona e didascalia facoltativa.
UIButton *NineRoundButton(NSString *icon, CGFloat diameter,
                          UIColor *background, UIColor *tint);

// Pulsante rettangolare arrotondato con testo.
UIButton *NinePillButton(NSString *title, UIColor *background,
                         UIColor *textColor);
