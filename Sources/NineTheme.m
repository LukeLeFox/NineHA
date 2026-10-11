#import "NineTheme.h"

UIColor *NTHex(unsigned int rgb, CGFloat alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:alpha];
}

UIColor *NTBackground(void)    { return NTHex(0x111111, 1); }
UIColor *NTCard(void)          { return NTHex(0x1C1C1C, 1); }
UIColor *NTCardPressed(void)   { return NTHex(0x2A2A2A, 1); }
UIColor *NTBorder(void)        { return NTHex(0xE1E1E1, .12); }
UIColor *NTHeader(void)        { return NTHex(0x101010, 1); }
UIColor *NTText(void)          { return NTHex(0xE1E1E1, 1); }
UIColor *NTSecondaryText(void) { return NTHex(0x9B9B9B, 1); }
UIColor *NTDisabledText(void)  { return NTHex(0x6F6F6F, 1); }
UIColor *NTPrimary(void)       { return NTHex(0x03A9F4, 1); }
UIColor *NTInactive(void)      { return NTHex(0x9E9E9E, 1); }
UIColor *NTError(void)         { return NTHex(0xDB4437, 1); }
UIColor *NTSuccess(void)       { return NTHex(0x43A047, 1); }
UIColor *NTWarning(void)       { return NTHex(0xFFA600, 1); }

UIFont *NTFont(CGFloat size) {
    return [UIFont systemFontOfSize:size];
}

UIFont *NTMediumFont(CGFloat size) {
    if ([UIFont respondsToSelector:
            @selector(systemFontOfSize:weight:)]) {
        return [UIFont systemFontOfSize:size
                                 weight:UIFontWeightMedium];
    }
    return [UIFont boldSystemFontOfSize:size];
}

UIFont *NTBoldFont(CGFloat size) {
    return [UIFont boldSystemFontOfSize:size];
}

void NTStyleTableView(UITableView *tableView) {
    tableView.backgroundColor = NTBackground();
    tableView.backgroundView = nil;
    tableView.separatorColor = NTHex(0xE1E1E1, .10);
    tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;

    if ([tableView respondsToSelector:
            @selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
}

void NTStyleCell(UITableViewCell *cell) {
    cell.backgroundColor = NTCard();
    cell.textLabel.textColor = NTText();
    cell.detailTextLabel.textColor = NTSecondaryText();
    cell.tintColor = NTPrimary();

    UIView *selected = [[UIView alloc] init];
    selected.backgroundColor = NTCardPressed();
    cell.selectedBackgroundView = selected;
}

void NTStyleNavigationBar(UINavigationBar *bar) {
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    bar.barTintColor = NTHeader();
    bar.tintColor = NTText();
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName: NTText(),
        NSFontAttributeName: NTMediumFont(19)
    };
}

void NTApplyAppearance(void) {
    NTStyleNavigationBar([UINavigationBar appearance]);

    [[UITableViewHeaderFooterView appearance]
        setTintColor:NTBackground()];

    [[UILabel appearanceWhenContainedInInstancesOfClasses:
        @[[UITableViewHeaderFooterView class]]]
        setTextColor:NTSecondaryText()];

    [[UISwitch appearance] setOnTintColor:NTPrimary()];
    [[UISlider appearance] setMinimumTrackTintColor:NTPrimary()];
}
