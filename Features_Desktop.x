// Features_Desktop.x — 桌面/Dock/文件夹/手势
// Hook 点全部对标 SystemX：
//   SBDockView setBackgroundAlpha: / layoutSubviews / _backgroundContrastDidChange:  (0x1bffc 等)
//   CSHomeAffordanceView layoutSubviews / pointInside:withEvent:                      (0x1cb6c 等)
//   SBRootFolderView / SBFolderView isPageControlHidden / setPageControlAlpha:        (0x219ac 等)
//   SBIconListGridLayoutConfiguration numberOfPortraitColumns  (Dock 5 图标, 0x1c29c:
//       读 ivar "_numberOfPortraitRows"，==1 的单行布局直接返回 5)
//   SBIconListFlowLayout numberOfColumns/Rows(3→4) / maximumIconCount  (文件夹 4×4)
//   SBHIconManager iconViewDisplaysLabel: / SBIconController iconManager:iconViewDisplaysLabel:
//   SBIconLabelImageParametersBuilder buildParameters  (文字阴影)
#import "Common.h"
#import "PrivateHeaders.h"
#import "Prefs.h"

// ============================================================
// 手势：双击/长按桌面空白锁屏
// SystemX 走 SBIconController gestureRecognizer:shouldReceiveTouch: 拦截 + 自带
// SBDoubleTapLockGestureTarget/SBLongPressLockGestureTarget 两个 target 类（见 hooks 表）。
// 这里用等价自实现：往 SBRootFolderView 上挂识别器，空白区域才放行。
// ============================================================
@interface SPLockGestureTarget : NSObject <UIGestureRecognizerDelegate>
@end

@implementation SPLockGestureTarget
- (void)handleDoubleTap:(UITapGestureRecognizer *)g {
    SPLockDevice();
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) SPLockDevice();
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    // 只拦"图标本体"；图标列表的背景（SBIconListView/SBRootFolderView）算空白区，必须放行，
    // 否则手势永远收不到触摸（旧版误用 containsString:@"Icon" 把列表自己也拦了）。
    UIView *v = touch.view;
    while (v && v != g.view) {
        NSString *cn = NSStringFromClass([v class]);
        if ([cn isEqualToString:@"SBIconView"] ||
            [cn containsString:@"Badge"] ||
            [cn containsString:@"Widget"] ||
            [cn containsString:@"IconImage"] ||
            [cn containsString:@"IconLabel"] ||
            [cn containsString:@"IconAccessory"]) {
            return NO;
        }
        v = v.superview;
    }
    return YES;
}
@end

static const void *kSPGestureMarker = &kSPGestureMarker;
static SPLockGestureTarget *gGestureTarget = nil;

static void SPInjectLockGestures(UIView *host) {
    if (!SPIsSpringBoard || !host) return;
    if (objc_getAssociatedObject(host, kSPGestureMarker)) return;
    objc_setAssociatedObject(host, kSPGestureMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!gGestureTarget) gGestureTarget = [[SPLockGestureTarget alloc] init];

    if (SPBool(kDoubleTapToLock)) {
        UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:gGestureTarget
                                                                            action:@selector(handleDoubleTap:)];
        t.numberOfTapsRequired = 2;
        t.cancelsTouchesInView = NO;
        t.delegate = gGestureTarget;
        [host addGestureRecognizer:t];
    }
    if (SPBool(kLongPressToLock)) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:gGestureTarget
                                                                                          action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.6;
        lp.cancelsTouchesInView = NO;
        lp.delegate = gGestureTarget;
        [host addGestureRecognizer:lp];
    }
}

// ============================================================
// 图标/小组件标签隐藏
// ============================================================
static BOOL SPLabelDecision(id iconView, BOOL orig) {
    if (!orig) return orig; // 系统本就不显示，别干预
    BOOL isWidget = NO;
    @try {
        NSString *vcn = NSStringFromClass([iconView class]);
        id icon = [iconView valueForKey:@"icon"];
        NSString *icn = icon ? NSStringFromClass([icon class]) : @"";
        isWidget = [vcn containsString:@"Widget"] || [icn containsString:@"Widget"];
    } @catch (NSException *e) {}
    if (isWidget && SPBool(kHideWidgetLabels))   return NO;
    if (!isWidget && SPBool(kHideHomeIconLabels)) return NO;
    return orig;
}

// ============================================================
// Hooks
// ============================================================
%hook SBDockView
- (void)setBackgroundAlpha:(double)alpha {
    if (SPBool(kTransparentDock)) alpha = 0.0;
    %orig(alpha);
}
- (void)layoutSubviews {
    %orig;
    if (SPBool(kTransparentDock)) {
        for (UIView *v in self.subviews) {
            NSString *cn = NSStringFromClass([v class]);
            if ([cn containsString:@"Background"] || [cn containsString:@"Platter"]) {
                v.alpha = 0.0;
            }
        }
    }
}
- (void)_backgroundContrastDidChange:(BOOL)changed {
    if (SPBool(kTransparentDock)) return; // 透明模式忽略对比度刷新
    %orig(changed);
}
%end

// 悬浮 Dock 的底板（对齐 SystemX：SBFloatingDockPlatterView×2）
%hook SBFloatingDockPlatterView
- (void)layoutSubviews {
    %orig;
    if (SPBool(kTransparentDock)) {
        for (UIView *v in self.subviews) {
            NSString *cn = NSStringFromClass([v class]);
            if ([cn containsString:@"Background"] || [cn containsString:@"Material"]) {
                v.alpha = 0.0;
            }
        }
    }
}
%end

%hook CSHomeAffordanceView
- (void)layoutSubviews {
    %orig;
    if (SPBool(kHideHomeBar)) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (SPBool(kHideHomeBar)) return NO;
    return %orig;
}
%end

// Home Bar 的 pill 本体（对齐 SystemX：取 ivar "_pillView" 只隐藏药丸，保留手势区域）
%hook SBHomeGrabberView
- (void)layoutSubviews {
    %orig;
    if (SPBool(kHideHomeBar)) {
        id pill = SPReadIvarObject(self, "_pillView");
        if (pill) {
            ((UIView *)pill).hidden = YES;
        } else {
            self.hidden = YES; // 兜底：没有 _pillView 的版本整体隐藏
        }
    }
}
%end

%hook SBRootFolderView
- (void)didMoveToWindow {
    %orig;
    SPInjectLockGestures(self);
}
- (BOOL)isPageControlHidden {
    if (SPBool(kHideHomePageDots)) return YES;
    return %orig;
}
- (void)setPageControlHidden:(BOOL)hidden {
    if (SPBool(kHideHomePageDots)) return; // 吞掉"显示"调用
    %orig(hidden);
}
- (void)setPageControlAlpha:(double)alpha {
    if (SPBool(kHideHomePageDots)) alpha = 0.0;
    %orig(alpha);
}
%end

%hook SBFolderView
- (BOOL)isPageControlHidden {
    if (SPBool(kHideHomePageDots)) return YES;
    return %orig;
}
- (void)setPageControlHidden:(BOOL)hidden {
    if (SPBool(kHideHomePageDots)) return;
    %orig(hidden);
}
- (void)setPageControlAlpha:(double)alpha {
    if (SPBool(kHideHomePageDots)) alpha = 0.0;
    %orig(alpha);
}
%end

// 文件夹滚动附件里的圆点（对齐 SystemX：滚动附件指针置空）
%hook SBFolderScrollAccessoryView
- (id)_pageIndicatorsView {
    if (SPBool(kHideHomePageDots)) return nil;
    return %orig;
}
%end

// Dock 5 图标：单行布局（_numberOfPortraitRows == 1）时列数 3/4 → 5
%hook SBIconListGridLayoutConfiguration
- (long)numberOfPortraitColumns {
    long cols = %orig;
    if (SPBool(kFiveIconDock)) {
        long rows = SPReadIvarLong(self, "_numberOfPortraitRows");
        if (rows == 1) return 5;
    }
    return cols;
}
%end

// 文件夹 4×4：列/行 3→4；maximumIconCount 放宽到 32（对齐 SystemX 的 0x23148）
%hook SBIconListFlowLayout
- (long)numberOfColumnsForOrientation:(long)orientation {
    long c = %orig;
    if (SPBool(kFolder4x4) && c == 3) c = 4;
    return c;
}
- (long)numberOfRowsForOrientation:(long)orientation {
    long c = %orig;
    if (SPBool(kFolder4x4) && c == 3) c = 4;
    return c;
}
- (unsigned long)maximumIconCount {
    if (SPBool(kFolder4x4)) return 32;
    return %orig;
}
%end

%hook SBHIconManager
- (BOOL)iconViewDisplaysLabel:(id)iconView {
    BOOL o = %orig;
    return SPLabelDecision(iconView, o);
}
%end

%hook SBIconController
- (BOOL)iconManager:(id)manager iconViewDisplaysLabel:(id)iconView {
    BOOL o = %orig;
    return SPLabelDecision(iconView, o);
}
%end

%hook SBIconLabelImageParametersBuilder
- (id)buildParameters {
    id p = %orig;
    if (SPBool(kHideHomeIconLabelShadow) && [p respondsToSelector:@selector(setDropsShadow:)]) {
        [p setDropsShadow:NO];
    }
    return p;
}
%end
