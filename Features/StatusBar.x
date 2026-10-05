// Features_StatusBar.x — 状态栏/日期时间/静音图标/5GA/伪装电量
// 全部对标 SystemX 的 hook 点：
//   STUIStatusBarTimeItem applyUpdate:toDisplayItem:      (SystemX fn=0x2475c)
//   _UIStatusBarTimeItem  applyUpdate:toDisplayItem:      (0x24f3c)
//   STUIStatusBarIndicatorQuietModeItem systemImageNameForUpdate: (0x1e9ec)
//   STUIStatusBarCellularNetworkTypeView setText:...      (0x1eb6c/0x1f2a8)
//   SBUIController batteryCapacity/batteryCapacityAsPercentage (0x25a14/0x25a68)
//   UIStatusBarBatteryPercentItemView updateForNewData:actions: (0x25824)
#import "../Common.h"
#import "../PrivateHeaders.h"
#import "../Prefs.h"

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
// 标记：该 displayItem 是我们的时间项（用于 _updateComputedTransform 里叠加上下偏移）
static const void *kSPTimeMarker = &kSPTimeMarker;

static NSDateFormatter *SPFormatter(NSString *fmt, BOOL english, BOOL isTime) {
    NSString *key = [NSString stringWithFormat:@"%@|%@", fmt, english ? @"en" : @"sys"];
    NSDateFormatter *__strong *slot = isTime ? &gTimeFmt : &gDateFmt;
    NSString *__strong *slotStr     = isTime ? &gTimeFmtStr : &gDateFmtStr;
    if (*slot && [*slotStr isEqualToString:key]) return *slot;
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = fmt;
    if (english) f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    *slot = f;
    *slotStr = key;
    return f;
}

static void SPDateTimeApply(id displayItem) {
    if (!SPIsSpringBoard) return;
    if (!SPBool(kStatusBarDateTime)) return;
    if (!displayItem) return;

    id view = nil;
    @try { view = [displayItem valueForKey:@"view"]; } @catch (NSException *e) {}
    // 不绑定具体类：只要具备 label 能力就改写（STUI/_UI 两套状态栏都覆盖）
    if (![view isKindOfClass:[UIView class]]) return;
    if (![view respondsToSelector:@selector(setAttributedText:)] ||
        ![view respondsToSelector:@selector(setNumberOfLines:)]) return;
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
    // 前景色跟随系统（壁纸自适应），不要写死黑/白
    UIColor *fg = label.textColor;
    NSAttributedString *cur = label.attributedText;
    if (cur.length > 0) {
        UIColor *c = [cur attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
        if (c) fg = c;
    }
    if (!fg) fg = [UIColor labelColor];

    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineSpacing = 0;

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:timeStr
        attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:tSize weight:UIFontWeightSemibold],
                      NSForegroundColorAttributeName: fg,
                      NSParagraphStyleAttributeName: ps }];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:dateStr]
        attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:dSize weight:UIFontWeightRegular],
                      NSForegroundColorAttributeName: fg,
                      NSParagraphStyleAttributeName: ps }]];

    label.numberOfLines = 2;
    label.attributedText = attr;
    // 标记"这是我们的时间项"：上下偏移改由 _updateComputedTransform 统一叠加（防跳）
    objc_setAssociatedObject(displayItem, kSPTimeMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ============================================================
// 二、静音小图标（含自定义 SF Symbol + 响铃同步）
// ============================================================
static id SPSingleton(NSString *clsName) {
    Class c = NSClassFromString(clsName);
    if (!c) return nil;
    SEL s = NSSelectorFromString(@"sharedInstance");
    if ([c respondsToSelector:s]) return ((id (*)(id, SEL))objc_msgSend)(c, s);
    return nil;
}

// ---------- 静音状态跟踪（对标 SystemX：由 SBRingerControl 钩子维护状态字节 0x691a8）----------
static int gSPRingerKnown = -1; // -1 未知 / 0 未静音 / 1 静音

static void SPRingerRemember(BOOL muted) { gSPRingerKnown = muted ? 1 : 0; }

// 读系统当前是否静音：优先用钩子实时跟踪值；否则多路探测；
// 全部失败默认"未静音"（操作方定行为：确认静音才显示图标，没开静音一律不显示）。
static BOOL SPRingerMuted(void) {
    if (gSPRingerKnown >= 0) return (gSPRingerKnown == 1);
    id rc = SPSingleton(@"SBRingerControl");
    if (rc) {
        NSArray *selNames = @[@"isRingerMuted", @"ringerMuted", @"isMuted", @"muted"];
        for (NSString *name in selNames) {
            SEL s = NSSelectorFromString(name);
            if ([rc respondsToSelector:s]) {
                BOOL v = ((BOOL (*)(id, SEL))objc_msgSend)(rc, s);
                SPRingerRemember(v);
                return v;
            }
        }
        NSArray *keyNames = @[@"isRingerMuted", @"ringerMuted", @"isMuted", @"muted", @"_ringerMuted"];
        for (NSString *k in keyNames) {
            @try {
                id v = [rc valueForKey:k];
                if ([v isKindOfClass:[NSNumber class]]) {
                    SPRingerRemember([v boolValue]);
                    return [v boolValue];
                }
            } @catch (NSException *e) {}
        }
    }
    // AVSystemController 兜底（经典 API：getAttribute:forKey:[error:]）
    id av = SPSingleton(@"AVSystemController");
    if (av) {
        float val = 0;
        SEL s3 = NSSelectorFromString(@"getAttribute:forKey:error:");
        SEL s2 = NSSelectorFromString(@"getAttribute:forKey:");
        if ([av respondsToSelector:s3]) {
            ((BOOL (*)(id, SEL, void *, id, NSError *__autoreleasing *))objc_msgSend)(av, s3, &val, @"RingerMuted", NULL);
            SPRingerRemember(val != 0);
            return val != 0;
        }
        if ([av respondsToSelector:s2]) {
            ((BOOL (*)(id, SEL, void *, id))objc_msgSend)(av, s2, &val, @"RingerMuted");
            SPRingerRemember(val != 0);
            return val != 0;
        }
    }
    return NO;
}

// 静音状态实时跟踪：init 时读一次当前值；两个 setter 全路径覆盖（选择子签名取自 SystemX 注册表实证）
%hook SBRingerControl
- (id)initWithBannerManager:(id)bannerManager soundController:(id)soundController {
    id inst = %orig;
    if (inst) {
        SEL s = NSSelectorFromString(@"isRingerMuted");
        if ([inst respondsToSelector:s]) {
            SPRingerRemember(((BOOL (*)(id, SEL))objc_msgSend)(inst, s));
        }
    }
    return inst;
}
- (id)initWithHUDController:(id)hudController soundController:(id)soundController {
    id inst = %orig;
    if (inst) {
        SEL s = NSSelectorFromString(@"isRingerMuted");
        if ([inst respondsToSelector:s]) {
            SPRingerRemember(((BOOL (*)(id, SEL))objc_msgSend)(inst, s));
        }
    }
    return inst;
}
- (void)setRingerMuted:(BOOL)muted {
    SPRingerRemember(muted);
    %orig;
}
- (void)setRingerMuted:(BOOL)muted withFeedback:(id)feedback reason:(long long)reason clientType:(long long)clientType {
    SPRingerRemember(muted);
    %orig;
}
%end

void SPStatusBarFeaturesInit(void) {
    // 静音状态由 SBRingerControl 钩子维护（init 读取 + setter 实时跟踪），无需主动同步；
    // 注意：不做「开启功能就强制静音」的副作用（未静音时图标不显示，纯被动反映真实状态）。
    SPLog(@"statusbar features init");
}

// 上下偏移：叠加在系统每次重算 transform 之后（SystemX 同款做法，防"来回跳"）
%hook STUIStatusBarDisplayItem
- (void)_updateComputedTransform {
    %orig;
    if (![objc_getAssociatedObject(self, kSPTimeMarker) boolValue]) return;
    double offY = SPFloat(kSBCDateTimeOffsetY);
    if (fabs(offY) < 0.0001) return;
    id view = nil;
    @try { view = [self valueForKey:@"view"]; } @catch (NSException *e) {}
    if (![view isKindOfClass:[UIView class]]) return;
    UIView *v = (UIView *)view;
    v.transform = CGAffineTransformTranslate(v.transform, 0, offY);
}
%end

%hook _UIStatusBarDisplayItem
- (void)_updateComputedTransform {
    %orig;
    if (![objc_getAssociatedObject(self, kSPTimeMarker) boolValue]) return;
    double offY = SPFloat(kSBCDateTimeOffsetY);
    if (fabs(offY) < 0.0001) return;
    id view = nil;
    @try { view = [self valueForKey:@"view"]; } @catch (NSException *e) {}
    if (![view isKindOfClass:[UIView class]]) return;
    UIView *v = (UIView *)view;
    v.transform = CGAffineTransformTranslate(v.transform, 0, offY);
}
%end

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
    if (SPIsSpringBoard && SPBool(kSilentStatusBarIcon) && SPRingerMuted()) {
        NSString *sym = SPString(kSilentStatusBarIconSymbol, @"bell.slash.fill");
        return sym.length ? sym : @"bell.slash.fill";
    }
    return %orig;
}
%end

%hook _UIStatusBarIndicatorQuietModeItem
- (id)systemImageNameForUpdate:(id)update {
    if (SPIsSpringBoard && SPBool(kSilentStatusBarIcon) && SPRingerMuted()) {
        NSString *sym = SPString(kSilentStatusBarIconSymbol, @"bell.slash.fill");
        return sym.length ? sym : @"bell.slash.fill";
    }
    return %orig;
}
%end

// 借"专注/静音"数据项上屏：静音时给条目挂 focusName 标记，系统即显示 quiet-mode 图标。
// ⚠️ 签名必须与真机完全一致（focusName/imageName 是 C 字符串、data 是原始指针）：
// 用 id 声明会被 ARC 插 objc_retain → 对非对象指针段错误（曾导致 SpringBoard 安全模式）。
%hook _UIStatusBarDataQuietModeEntry
- (id)initFromData:(id *)data type:(int)type focusName:(const char *)focusName
    maxFocusLength:(int)mfl imageName:(const char *)imageName maxImageLength:(int)mil boolValue:(BOOL)bv {
    id inst = %orig(data, type, focusName, mfl, imageName, mil, bv);
    if (inst && SPIsSpringBoard && SPBool(kSilentStatusBarIcon) && SPRingerMuted()) {
        @try { [inst setFocusName:@"!Mute"]; } @catch (NSException *e) {}
    }
    return inst;
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
