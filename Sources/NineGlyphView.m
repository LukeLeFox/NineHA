#import "NineGlyphView.h"
#import <math.h>

static void NLine(CGContextRef c,
                  CGFloat x1, CGFloat y1,
                  CGFloat x2, CGFloat y2) {
    CGContextMoveToPoint(c, x1, y1);
    CGContextAddLineToPoint(c, x2, y2);
    CGContextStrokePath(c);
}

@implementation NineGlyphView

@synthesize entityID = _entityID;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setEntityID:(NSString *)entityID {
    _entityID = [entityID copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (!c) return;

    CGFloat side = MIN(rect.size.width, rect.size.height);
    CGFloat scale = side / 32.0f;

    CGContextSaveGState(c);
    CGContextTranslateCTM(
        c, (rect.size.width-side)/2,
        (rect.size.height-side)/2);
    CGContextScaleCTM(c, scale, scale);

    UIColor *color = self.tintColor ?: [UIColor whiteColor];
    CGContextSetStrokeColorWithColor(c, color.CGColor);
    CGContextSetFillColorWithColor(c, color.CGColor);
    CGContextSetLineWidth(c, 2.3f);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);

    NSString *e = self.entityID ?: @"";

    if ([e hasPrefix:@"light."]) {
        // Lampadina
        CGContextAddArc(c, 16, 12, 8, 0, 2*M_PI, 0);
        CGContextStrokePath(c);
        NLine(c, 12, 22, 20, 22);
        NLine(c, 13, 26, 19, 26);
    }
    else if ([e hasPrefix:@"weather_condition."]) {
        NSString *condition =
            [e substringFromIndex:
                [@"weather_condition." length]];

        BOOL sunny =
            [condition rangeOfString:@"sunny"].location
                != NSNotFound ||
            [condition isEqualToString:@"clear-night"];

        BOOL partly =
            [condition rangeOfString:@"partly"].location
                != NSNotFound;

        BOOL rainy =
            [condition rangeOfString:@"rain"].location
                != NSNotFound ||
            [condition rangeOfString:@"pour"].location
                != NSNotFound;

        BOOL snowy =
            [condition rangeOfString:@"snow"].location
                != NSNotFound;

        BOOL lightning =
            [condition rangeOfString:@"lightning"].location
                != NSNotFound;

        if (sunny || partly) {
            CGContextStrokeEllipseInRect(
                c, CGRectMake(7, 5, 11, 11));

            NLine(c, 12.5, 1, 12.5, 4);
            NLine(c, 12.5, 17, 12.5, 20);
            NLine(c, 2, 10.5, 5, 10.5);
            NLine(c, 20, 10.5, 23, 10.5);
        }

        if (!sunny || partly) {
            CGContextAddArc(c, 12, 19, 6,
                            M_PI, M_PI * 1.9, 0);
            CGContextAddArc(c, 19, 16, 7,
                            M_PI * 1.05, M_PI * 1.9, 0);
            CGContextAddArc(c, 24, 21, 5,
                            -M_PI * .5, M_PI * .5, 0);
            NLine(c, 7, 24, 25, 24);
        }

        if (rainy) {
            NLine(c, 11, 27, 9, 30);
            NLine(c, 18, 27, 16, 30);
            NLine(c, 25, 27, 23, 30);
        }

        if (snowy) {
            CGContextFillEllipseInRect(
                c, CGRectMake(9, 27, 2.5, 2.5));
            CGContextFillEllipseInRect(
                c, CGRectMake(17, 27, 2.5, 2.5));
            CGContextFillEllipseInRect(
                c, CGRectMake(25, 27, 2.5, 2.5));
        }

        if (lightning) {
            CGContextMoveToPoint(c, 18, 23);
            CGContextAddLineToPoint(c, 14, 29);
            CGContextAddLineToPoint(c, 18, 28);
            CGContextAddLineToPoint(c, 15, 32);
            CGContextStrokePath(c);
        }
    }
    else if ([e hasPrefix:@"fan."]) {
        CGContextStrokeEllipseInRect(
            c, CGRectMake(13, 13, 6, 6));

        CGContextAddEllipseInRect(
            c, CGRectMake(14, 3, 6, 12));
        CGContextAddEllipseInRect(
            c, CGRectMake(18, 16, 11, 6));
        CGContextAddEllipseInRect(
            c, CGRectMake(3, 17, 11, 6));

        CGContextStrokePath(c);
    }
    else if ([e hasPrefix:@"vacuum."]) {
        CGContextStrokeEllipseInRect(
            c, CGRectMake(5, 6, 22, 22));
        NLine(c, 10, 12, 22, 12);
        CGContextFillEllipseInRect(
            c, CGRectMake(14, 20, 4, 4));
        NLine(c, 8, 29, 5, 32);
        NLine(c, 24, 29, 27, 32);
    }
    else if ([e hasPrefix:@"media_player."]) {
        CGContextStrokeRect(
            c, CGRectMake(4, 6, 24, 20));

        CGContextMoveToPoint(c, 13, 11);
        CGContextAddLineToPoint(c, 13, 21);
        CGContextAddLineToPoint(c, 21, 16);
        CGContextClosePath(c);
        CGContextStrokePath(c);
    }
    else if ([e hasPrefix:@"switch."] ||
             [e hasPrefix:@"input_boolean."]) {
        // Interruttore di alimentazione
        CGContextAddArc(c, 16, 17, 10,
                        -M_PI*0.35, M_PI*1.35, 0);
        CGContextStrokePath(c);
        NLine(c, 16, 4, 16, 17);
    }
    else if ([e hasPrefix:@"climate."]) {
        // Termometro
        CGContextStrokeRect(c, CGRectMake(13, 5, 6, 17));
        CGContextStrokeEllipseInRect(c, CGRectMake(10, 19, 12, 12));
        NLine(c, 16, 12, 16, 25);
    }
    else if ([e hasPrefix:@"cover."]) {
        // Tapparella
        CGContextStrokeRect(c, CGRectMake(5, 5, 22, 22));
        for (int y = 10; y <= 22; y += 4) {
            NLine(c, 7, y, 25, y);
        }
    }
    else if ([e hasPrefix:@"sensor."]) {
        // Grafico sensore
        NLine(c, 5, 26, 27, 26);
        NLine(c, 5, 26, 5, 7);
        NLine(c, 8, 22, 14, 17);
        NLine(c, 14, 17, 19, 19);
        NLine(c, 19, 19, 26, 8);
    }
    else if ([e hasPrefix:@"binary_sensor."]) {
        // Indicatore binario
        CGContextStrokeEllipseInRect(c, CGRectMake(6, 6, 20, 20));
        CGContextFillEllipseInRect(c, CGRectMake(12, 12, 8, 8));
    }
    else if ([e hasPrefix:@"menu.list"]) {
        for (int y = 8; y <= 24; y += 8) {
            CGContextFillEllipseInRect(c, CGRectMake(5, y-2, 4, 4));
            NLine(c, 13, y, 27, y);
        }
    }
    else if ([e hasPrefix:@"menu.refresh"]) {
        CGContextAddArc(c, 16, 16, 10,
                        M_PI*.3, M_PI*1.8, 0);
        CGContextStrokePath(c);
        NLine(c, 25, 8, 25, 15);
        NLine(c, 25, 15, 19, 13);
    }
    else if ([e hasPrefix:@"menu.server"]) {
        CGContextStrokeRect(c, CGRectMake(5, 5, 22, 9));
        CGContextStrokeRect(c, CGRectMake(5, 18, 22, 9));
        CGContextFillEllipseInRect(c, CGRectMake(8, 8, 3, 3));
        CGContextFillEllipseInRect(c, CGRectMake(8, 21, 3, 3));
    }
    else if ([e hasPrefix:@"menu.settings"]) {
        CGContextStrokeEllipseInRect(c, CGRectMake(8, 8, 16, 16));
        CGContextStrokeEllipseInRect(c, CGRectMake(13, 13, 6, 6));
        NLine(c, 16, 3, 16, 8);
        NLine(c, 16, 24, 16, 29);
        NLine(c, 3, 16, 8, 16);
        NLine(c, 24, 16, 29, 16);
    }
    else {
        // Casa: icona generica/Home
        NLine(c, 4, 15, 16, 5);
        NLine(c, 16, 5, 28, 15);
        NLine(c, 8, 13, 8, 27);
        NLine(c, 24, 13, 24, 27);
        NLine(c, 8, 27, 24, 27);
    }

    CGContextRestoreGState(c);
}

@end
