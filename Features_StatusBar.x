// Features_StatusBar.x — 状态栏/日期时间/静音图标/5GA/伪装电量
// 全部对标 SystemX 的 hook 点：
//   STUIStatusBarTimeItem applyUpdate:toDisplayItem:      (SystemX fn=0x2475c)
//   _UIStatusBarTimeItem  applyUpdate:toDisplayItem:      (0x24f3c)
//   STUIStatusBarIndicatorQuietModeItem systemImageNameForUpdate: (0x1e9ec)
//   STUIStatusBarCellularNetworkTypeView setText:...      (0x1eb6c/0x1f2a8)
//   SBUIController batteryCapacity/batteryCapacityAsPercentage (0x25a14/0x25a68)
//   UIStatusBarBatteryPercentItemView updateForNewData:actions: (0x25824)
#import "Common.h"
#import "PrivateHeaders.h"
#import "Prefs.h"

// ============================================================
// 一、日期时间（时间下方加一行日期，双行 UILabel 方案）
// SystemX 用「displayItem -> view -> isKindOfClass + associatedObject 标记」的方式
// 维护自己的标签（ctor 里 NSClassFromString(0x5db90) + objc_getAssociatedObject(0x69028d)），
// 这里用同一思路的简化版：直接重写 time label 的 attributedText。
// ============================================================
static NSDateFormatter *gTimeFmt = nil;
static NSDateFormatter *gDateFmt = nil;
static NSString *gTimeFmtStr = nil;
static NSString *gDateFmtStr = nil;

static NSDateFormatter *SPFormatter(NSString *fmt, BOOL english, BOOL isTime) {
    NSDateFormatter *__strong *slot = isTime ? &gTimeFmt : &gDateFmt;
    NSString *__strong *slotStr     = isTime ? &gTimeFmtStr : &gDateFmtStr;
    if (*slot && [*slotStr isEqualToString:fmt]) return *slot;
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = fmt;
    if (english) f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    *slot = f;
    *slotStr = [fmt copy];
    return f;
}

static void SPDateTimeApply(id displayItem) {
    if (!SPIsSpringBoard) return;
    if (!SPBool(kStatusBarDateTime)) return;
    if (!displayItem) return;

    id view = nil;
    @try { view = [displayItem valueForKey:@"view"]; } @catch (NSException *e) {}
    if (![view isKindOfClass:[UILabel class]]) return;
    UILabel *label = (UILabel *)view;

    NSDate *now = [NSDate date];
    NSString *tFmt = SPString(kSBCDateTimeTimeFormat, @"HH:mm");
    NSString *dFmt = SPString(kSBCDateTimeDateFormat,  @"E MM/dd");
    BOOL english = SPBool(kSBCDateTimeEnglishDate);

    NSDateFormatter *tf = SPFormatter(tFmt, NO, YES);
    NSDateFormatter *df = SPFormatter(dFmt, english, NO);
    NSString *timeStr = [tf stringFromDate:now];
    NSString *dateStr = [df stringFromDate:now];

    double tSize = SPFloat(kSBCDateTimeTimeFontSize);  if (tSize <= 0) tSize = 15.0;
    double dSize = SPFloat(kSBCDateTimeDateFontSize);  if (dSize <= 0) dSize = 10.0;
    double offY  = SPFloat(kSBCDateTimeOffsetY);

    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineSpacing = 0;

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:timeStr
        attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:tSize weight:UIFontWeightSemibold],
                      NSParagraphStyleAttributeName: ps }];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:dateStr]
        attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:dSize weight:UIFontWeightRegular],
                      NSParagraphStyleAttributeName: ps }]];

    label.numberOfLines = 2;
    label.attributedText = attr;
    label.transform = CGAffineTransformMakeTranslation(0, offY);
}

// ============================================================
// 二、静音小图标（含自定义 SF Symbol + 响铃同步）
// ============================================================
static void SPSetRingerMuted(BOOL muted) {
    Class asc = NSClassFromString(@"AVSystemController");
    if (!asc) return;
    id inst = ((id (*)(id, SEL))objc_msgSend)(asc, NSSelectorFromString(@"sharedAVSystemController"));
    SEL s = NSSelectorFromString(@"setAttribute:forKey:error:");
    if ([inst respondsToSelector:s]) {
        ((BOOL (*)(id, SEL, id, id, NSError *__autoreleasing *))objc_msgSend)(inst, s, @(muted), @"RingerMuted", NULL);
    }
}

static void SPSyncRingerState(void) {
    if (!SPIsSpringBoard) return;
    SPSetRingerMuted(SPBool(kSilentStatusBarIcon));
}

void SPStatusBarFeaturesInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"SPPrefsReloaded" object:nil queue:nil
        usingBlock:^(NSNotification *note) { SPSyncRingerState(); }];
    SPSyncRingerState();
}

%hook STUIStatusBarTimeItem
- (id)applyUpdate:(id)update toDisplayItem:(id)displayItem {
    id ret = %orig;
    SPDateTimeApply(displayItem);
    return ret;
}
%end

%hook _UIStatusBarTimeItem
- (id)applyUpdate:(id)update toDisplayItem:(id)displayItem {
    id ret = %orig;
    SPDateTimeApply(displayItem);
    return ret;
}
%end

%hook STUIStatusBarIndicatorQuietModeItem
- (id)systemImageNameForUpdate:(id)update {
    if (SPIsSpringBoard && SPBool(kSilentStatusBarIcon)) {
        NSString *sym = SPString(kSilentStatusBarIconSymbol, @"bell.slash.fill");
        return sym.length ? sym : @"bell.slash.fill";
    }
    return %orig;
}
%end

%hook STUIStatusBarCellularNetworkTypeView
- (void)setText:(NSString *)text prefixLength:(long)prefixLength
    withStyleAttributes:(id)attributes forType:(long)type animated:(BOOL)animated {
    if (SPBool(kForce5GAStatusBar) && [text isKindOfClass:[NSString class]] && [text isEqualToString:@"5G"]) {
        text = @"5GA";
    }
    %orig(text, prefixLength, attributes, type, animated);
}
%end

%hook _UIStatusBarCellularNetworkTypeView
- (void)setText:(NSString *)text prefixLength:(long)prefixLength
    withStyleAttributes:(id)attributes forType:(long)type animated:(BOOL)animated {
    if (SPBool(kForce5GAStatusBar) && [text isKindOfClass:[NSString class]] && [text isEqualToString:@"5G"]) {
        text = @"5GA";
    }
    %orig(text, prefixLength, attributes, type, animated);
}
%end

// ============================================================
// 三、伪装电量
// 对齐 SystemX 的四个覆盖面：UIDevice.batteryLevel / BCBatteryDevice.percentCharge /
// SBUIController.batteryCapacity(AsPercentage) / UIStatusBarBatteryPercentItemView
// ============================================================
static inline BOOL SPFakeBatteryValue(int *out) {
    long v = SPInt(kFakeBatteryPercent);
    if (v >= 1 && v <= 100) { if (out) *out = (int)v; return YES; }
    return NO;
}

%hook UIDevice
- (float)batteryLevel {
    int fake;
    if (SPFakeBatteryValue(&fake)) return fake / 100.0f;
    return %orig;
}
%end

%hook BCBatteryDevice
- (long)percentCharge {
    int fake;
    if (SPFakeBatteryValue(&fake)) return fake;
    return %orig;
}
%end

%hook SBUIController
- (int)batteryCapacityAsPercentage {
    int fake;
    if (SPFakeBatteryValue(&fake)) return fake;
    return %orig;
}
- (int)batteryCapacity {
    int fake;
    if (SPFakeBatteryValue(&fake)) return fake;
    return %orig;
}
%end

%hook UIStatusBarBatteryPercentItemView
- (id)updateForNewData:(id)data actions:(int)actions {
    id ret = %orig;
    int fake;
    if (SPFakeBatteryValue(&fake) && [self respondsToSelector:NSSelectorFromString(@"setText:")]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self, NSSelectorFromString(@"setText:"),
            [NSString stringWithFormat:@"%d%%", fake]);
    }
    return ret;
}
%end
