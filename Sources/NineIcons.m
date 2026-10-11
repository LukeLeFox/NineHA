#import "NineIcons.h"
#import "NineTheme.h"
#import <CoreText/CoreText.h>

static NSString *const NineIconFontName = @"MaterialDesignIcons";

static void NineIconRegisterFont(void) {
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSURL *url = [[NSBundle mainBundle]
            URLForResource:@"materialdesignicons-webfont"
             withExtension:@"ttf"
              subdirectory:@"MDI"];

        if (!url) {
            NSLog(@"NineHA Icons: font MDI mancante");
            return;
        }

        CFErrorRef error = NULL;

        if (!CTFontManagerRegisterFontsForURL(
                (__bridge CFURLRef)url,
                kCTFontManagerScopeProcess,
                &error)) {
            if (error) CFRelease(error);
        }
    });
}

static NSDictionary *NineIconCodepoints(void) {
    static NSDictionary *map;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSString *path = [[NSBundle mainBundle]
            pathForResource:@"mdi-codepoints"
                     ofType:@"plist"
                inDirectory:@"MDI"];

        map = path
            ? [NSDictionary dictionaryWithContentsOfFile:path]
            : nil;

        if (!map) map = @{};
    });

    return map;
}

UIFont *NineIconFont(CGFloat size) {
    NineIconRegisterFont();

    UIFont *font = [UIFont fontWithName:NineIconFontName size:size];
    return font ?: [UIFont systemFontOfSize:size];
}

NSString *NineIconGlyph(NSString *name) {
    if (![name isKindOfClass:[NSString class]] || !name.length)
        return nil;

    if ([name hasPrefix:@"mdi:"]) {
        name = [name substringFromIndex:4];
    } else if ([name rangeOfString:@":"].location != NSNotFound) {
        // Set di icone diversi da MDI non sono inclusi.
        return nil;
    }

    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });

    NSString *cached = [cache objectForKey:name];
    if (cached) return cached.length ? cached : nil;

    NSNumber *value = NineIconCodepoints()[name];
    NSString *glyph = @"";

    if ([value isKindOfClass:[NSNumber class]]) {
        uint32_t cp = value.unsignedIntValue;

        if (cp > 0xFFFF) {
            uint32_t v = cp - 0x10000;
            unichar pair[2] = {
                (unichar)(0xD800 + (v >> 10)),
                (unichar)(0xDC00 + (v & 0x3FF))
            };
            glyph = [NSString stringWithCharacters:pair length:2];
        } else {
            unichar single = (unichar)cp;
            glyph = [NSString stringWithCharacters:&single length:1];
        }
    }

    [cache setObject:glyph forKey:name];
    return glyph.length ? glyph : nil;
}

@implementation NineIconView {
    CGFloat _iconSize;
}

- (instancetype)initWithFrame:(CGRect)frame iconSize:(CGFloat)size {
    self = [super initWithFrame:frame];

    if (self) {
        _iconSize = size;
        self.font = NineIconFont(size);
        self.textAlignment = NSTextAlignmentCenter;
        self.backgroundColor = [UIColor clearColor];
        self.textColor = NTText();
        self.isAccessibilityElement = NO;
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame
                      iconSize:MIN(frame.size.width,
                                   frame.size.height) * .7f];
}

- (void)setIconName:(NSString *)iconName {
    if ([_iconName isEqualToString:iconName]) return;

    _iconName = [iconName copy];
    self.text = NineIconGlyph(iconName)
        ?: NineIconGlyph(@"help-circle-outline");
}

@end

UIButton *NineIconButton(NSString *icon, CGFloat size, UIColor *color) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];

    button.titleLabel.font = NineIconFont(size);
    [button setTitle:NineIconGlyph(icon)
            forState:UIControlStateNormal];
    [button setTitleColor:color ?: NTText()
                 forState:UIControlStateNormal];
    [button setTitleColor:[color ?: NTText()
                              colorWithAlphaComponent:.45]
                 forState:UIControlStateHighlighted];

    return button;
}

UIBarButtonItem *NineIconBarItem(NSString *icon, id target, SEL action) {
    UIButton *button = NineIconButton(icon, 24, NTText());
    button.frame = CGRectMake(0, 0, 44, 44);

    [button addTarget:target
               action:action
     forControlEvents:UIControlEventTouchUpInside];

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}
