// Lock.x — 面容解锁进入主屏幕（对标 SystemX autoDismissFaceID，全局 0x68a78）
// 两个触发点（对齐 SystemX 的两条链）：
//   1) SBDashBoardLockScreenEnvironment biometricUnlockBehavior:requestsUnlock:withFeedback:
//      —— 系统请求解锁后，延时 ~0.22s 收起锁屏
//   2) SBUIBiometricResource biometricKitInterface:handleEvent:（event == 0x0a，FaceID 匹配）
//      —— 延时 ~0.2s 收起锁屏
// 共用 5 秒节流窗口：同一次解锁两条链只触发一次；下一次锁屏/解锁周期恢复正常触发。
#import "../Common.h"
#import "../PrivateHeaders.h"
#import "../Prefs.h"

static NSTimeInterval gSPFaceLastFire = 0;

static BOOL SPFaceThrottle(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - gSPFaceLastFire < 5.0) return NO;
    gSPFaceLastFire = now;
    return YES;
}

static id SPSharedInstanceLock(NSString *clsName) {
    Class c = NSClassFromString(clsName);
    if (!c) return nil;
    SEL s = NSSelectorFromString(@"sharedInstance");
    if ([c respondsToSelector:s]) return ((id (*)(id, SEL))objc_msgSend)(c, s);
    return nil;
}

// 收起锁屏 → 直接进系统（多路降级）
static void SPAutoDismissLockScreen(void) {
    if (!SPIsSpringBoard) return;

    id mgr = SPSharedInstanceLock(@"SBLockScreenManager");
    if (mgr) {
        SEL s2 = NSSelectorFromString(@"unlockUIFromSource:withOptions:");
        if ([mgr respondsToSelector:s2]) {
            @try { ((void (*)(id, SEL, long long, id))objc_msgSend)(mgr, s2, 0, nil); } @catch (NSException *e) {}
            return;
        }
        SEL s1 = NSSelectorFromString(@"unlockUIFromSource:");
        if ([mgr respondsToSelector:s1]) {
            @try { ((void (*)(id, SEL, long long))objc_msgSend)(mgr, s1, 0); } @catch (NSException *e) {}
            return;
        }
    }
    SPLog(@"autodismiss: no unlock API found");
}

#pragma mark - 钩子

%hook SBDashBoardLockScreenEnvironment
- (void)biometricUnlockBehavior:(long long)behavior requestsUnlock:(BOOL)requestsUnlock withFeedback:(id)feedback {
    %orig;
    if (!(SPIsSpringBoard && SPBool(kAutoDismissFaceID))) return;
    if (!requestsUnlock) return;
    if (!SPFaceThrottle()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SPAutoDismissLockScreen();
    });
}
%end

%hook SBUIBiometricResource
- (void)biometricKitInterface:(id)interface handleEvent:(unsigned long long)event {
    %orig;
    if (!(SPIsSpringBoard && SPBool(kAutoDismissFaceID))) return;
    if (event != 0x0a) return;   // 0x0a = FaceID 匹配
    if (!SPFaceThrottle()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SPAutoDismissLockScreen();
    });
}
%end
