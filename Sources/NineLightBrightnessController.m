#import "NineLightBrightnessController.h"

@interface NineLightBrightnessController ()

@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UISlider *slider;

@end

@implementation NineLightBrightnessController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.lightName.length
        ? self.lightName : @"Luminosità";

    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.view.backgroundColor =
        [UIColor colorWithWhite:0.10 alpha:1];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Annulla"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(cancelTapped)];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Applica"
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(applyTapped)];

    self.percentLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    self.percentLabel.textAlignment =
        NSTextAlignmentCenter;

    self.percentLabel.font =
        [UIFont boldSystemFontOfSize:36];

    self.percentLabel.textColor =
        [UIColor whiteColor];

    [self.view addSubview:self.percentLabel];

    self.slider =
        [[UISlider alloc] initWithFrame:CGRectZero];

    self.slider.minimumValue = 1.0f;
    self.slider.maximumValue = 100.0f;

    self.slider.value =
        (float)MAX(1, MIN(100, self.initialPercent));

    self.slider.minimumTrackTintColor =
        [UIColor colorWithRed:0.97
                        green:0.72
                         blue:0.31
                        alpha:1];

    [self.slider addTarget:self
                    action:@selector(valueChanged)
          forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.slider];

    self.hintLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    self.hintLabel.numberOfLines = 0;
    self.hintLabel.textAlignment =
        NSTextAlignmentCenter;

    self.hintLabel.textColor =
        [UIColor colorWithWhite:0.70 alpha:1];

    self.hintLabel.font =
        [UIFont systemFontOfSize:14];

    self.hintLabel.text =
        @"Nessun comando viene inviato finché "
         "non premi Applica.";

    [self.view addSubview:self.hintLabel];

    [self valueChanged];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat margin = 25;

    CGFloat width = MAX(
        120,
        self.view.bounds.size.width - margin * 2
    );

    self.percentLabel.frame =
        CGRectMake(margin, 48, width, 56);

    self.slider.frame =
        CGRectMake(margin, 124, width, 48);

    self.hintLabel.frame =
        CGRectMake(margin, 195, width, 70);
}

- (void)valueChanged {
    NSInteger percent =
        (NSInteger)(self.slider.value + 0.5f);

    self.percentLabel.text =
        [NSString stringWithFormat:
            @"%ld%%", (long)percent];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (void)applyTapped {
    if (!self.onApply) return;

    NSInteger percent =
        (NSInteger)(self.slider.value + 0.5f);

    self.navigationItem.rightBarButtonItem.enabled = NO;

    self.onApply(MAX(1, MIN(100, percent)));
}

@end
