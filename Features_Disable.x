// Features_Disable.x — 禁用类（负一屏/资源库/下拉搜索/分隔线/通知不亮屏/充电不唤醒/注销不锁屏）
// Hook 点对标 SystemX：
//   SBSearchGesture revealAnimated: / searchScrollViewShouldRecognize:      (0x156f4/0x15654)
//   SBHIconManager presentTodayOverlay / presentTodayOverlayForIconDragManager: (0x155d0/0x15560)
//   SBIconController iconManager:rootFolderController:did(End)Overscroll...  (0x1527c/0x151d8)
//   _UI(UITableViewCell)SeparatorView layoutSubviews                        (0x11858)
//   SBNCScreenController canTurnOnScreenForNotificationRequest:              (0x14e60)
//   SBBacklightController turnOnScreenFullyWithBacklightSource:              (0x14e14)
//   SBLockScreenManager _setUILocked: / _reallySetUILocked:                  (0x1d31c/0x1d348)
#import "Common.h"
#import "PrivateHeaders.h"
#import "Prefs.h"

%hook SBSearchGesture
- (void)revealAnimated:(BOOL)animated {
    if (SPBool(kDisableTodayView)) return;               // 禁用负一屏
    %orig(animated);
}
- (BOOL)searchScrollViewShouldRecognize:(id)scrollView {
    if (SPBool(kDisableHomePullDownSearch)) return NO;   // 禁用桌面下拉搜索
    return %orig;
}
%end

%hook SBHIconManager
- (void)presentTodayOverlay {
    if (SPBool(kDisableTodayView)) return;
    %orig;
}
- (void)presentTodayOverlayForIconDragManager:(id)manager {
    if (SPBool(kDisableTodayView)) return;
    %orig(manager);
}
%end

%hook SBIconController
- (void)iconManager:(id)manager rootFolderController:(id)controller
    didEndOverscrollOnLastPageWithVelocity:(CGPoint)velocity translation:(CGPoint)translation {
    if (SPBool(kDisableAppLibrary)) return;            // 不进入资源库
    %orig(manager, controller, velocity, translation);
}
- (void)iconManager:(id)manager rootFolderController:(id)controller
    didOverscrollOnLastPageByAmount:(double)amount {
    if (SPBool(kDisableAppLibrary)) return;
    %orig(manager, controller, amount);
}
%end

// 分隔线：设置 / 电话 / 信息（按进程分别开关）
%hook _UIUITableViewCellSeparatorView
- (void)layoutSubviews {
    %orig;
    if (SPSeparatorsDisabled()) self.hidden = YES;
}
%end

%hook _UITableViewCellSeparatorView
- (void)layoutSubviews {
    %orig;
    if (SPSeparatorsDisabled()) self.hidden = YES;
}
%end

// 通知不亮屏：来源是通知请求时直接拒绝点亮
%hook SBNCScreenController
- (BOOL)canTurnOnScreenForNotificationRequest:(id)request {
    if (SPBool(kNotificationNoWake)) return NO;
    return %orig;
}
%end

// 充电不点亮（对齐 SystemX 的三个拦截点：电源状态唤醒入口 + 背光唤醒兜底）
%hook SBUIController
- (void)possiblyWakeForPowerStatusChangeWithUnlockSource:(long)source {
    if (SPBool(kChargingWakeDisabled)) return; // 电源事件不再触发唤醒
    %orig(source);
}
%end

%hook SBBacklightController
- (void)turnOnScreenFullyWithBacklightSource:(long)source {
    if (SPBool(kChargingWakeDisabled)) return; // 点亮请求直接吞掉（充电本身不受影响）
    %orig(source);
}
%end

// 注销/重启后不锁屏：挂钩 SBBootDefaults dontLockAfterCrash（与 SystemX 同点，干净可靠）
%hook SBBootDefaults
- (BOOL)dontLockAfterCrash {
    if (SPBool(kNoLockAfterRespring)) return YES;
    return %orig;
}
%end
