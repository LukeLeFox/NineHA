#import <UIKit/UIKit.h>

/*
 * Material Design Icons (le stesse icone del frontend Home Assistant),
 * caricate dal font incluso in Resources/MDI.
 */

UIFont *NineIconFont(CGFloat size);

// Accetta "mdi:lightbulb" oppure "lightbulb". Restituisce nil
// se l'icona non esiste nel font incluso.
NSString *NineIconGlyph(NSString *name);

@interface NineIconView : UILabel

@property (nonatomic, copy) NSString *iconName;

- (instancetype)initWithFrame:(CGRect)frame iconSize:(CGFloat)size;

@end

// Pulsante con sola icona, per barre e pannelli.
UIButton *NineIconButton(NSString *icon, CGFloat size, UIColor *color);
UIBarButtonItem *NineIconBarItem(NSString *icon, id target, SEL action);
