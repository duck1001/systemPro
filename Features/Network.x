// Network.x — 彻底关闭 WiFi 和蓝牙（对标 SystemX disconnectWiFiBT，全局 0x68ac8）
// 蓝牙：控制中心开关动作时若处于「已连接」（KVC _state == 3），在系统正常切换后再强制断电射频。
// WiFi：控制中心 WiFi 动作后，若 WiFi 已处于关闭 → 强制彻底断电（多选择器降级，均 respondsToSelector 守卫）。
#import "../Common.h"
#import "../PrivateHeaders.h"
#import "../Prefs.h"

static BOOL SPNetworkEnabled(void) {
    return SPIsSpringBoard && SPBool(kDisconnectWiFiBT);
}

static id SPSharedInstance(NSString *clsName) {
    Class c = NSClassFromString(clsName);
    if (!c) return nil;
    SEL s = NSSelectorFromString(@"sharedInstance");
    if ([c respondsToSelector:s]) return ((id (*)(id, SEL))objc_msgSend)(c, s);
    return nil;
}

static void SPForceSetBool(id obj, NSString *selName, BOOL val) {
    if (!obj) return;
    SEL s = NSSelectorFromString(selName);
    if (![obj respondsToSelector:s]) return;
    @try { ((void (*)(id, SEL, BOOL))objc_msgSend)(obj, s, val); } @catch (NSException *e) {}
}

static BOOL SPReadBool(id obj, NSString *selName, BOOL *ok) {
    SEL s = NSSelectorFromString(selName);
    if (obj && [obj respondsToSelector:s]) {
        @try {
            BOOL v = ((BOOL (*)(id, SEL))objc_msgSend)(obj, s);
            if (ok) *ok = YES;
            return v;
        } @catch (NSException *e) {}
    }
    if (ok) *ok = NO;
    return NO;
}

#pragma mark - 蓝牙：已连接时关开关 = 彻底断电

%hook BluetoothManager
- (void)bluetoothStateActionWithCompletion:(id)completion {
    BOOL wasConnected = NO;
    if (SPNetworkEnabled()) {
        @try {
            id st = [self valueForKey:@"_state"];
            if ([st isKindOfClass:[NSNumber class]]) wasConnected = ([st integerValue] == 3);
        } @catch (NSException *e) {}
    }
    %orig;
    if (wasConnected) {
        // 系统只做了「断开/关到明天」→ 再强制把射频也关掉
        SPForceSetBool(self, @"setEnabled:", NO);
        SPForceSetBool(self, @"setPowered:", NO);
    }
}
%end

#pragma mark - WiFi：CC 动作后若已关 = 彻底断电

%hook WFControlCenterStateMonitor
- (void)performAction:(id)action {
    %orig;
    if (!SPNetworkEnabled()) return;

    BOOL known = NO, on = NO;
    id wm = SPSharedInstance(@"SBWiFiManager");
    if (wm) {
        on = SPReadBool(wm, @"isWiFiEnabled", &known);
        if (!known) on = SPReadBool(wm, @"wifiEnabled", &known);
        if (!known) on = SPReadBool(wm, @"isEnabled", &known);
    }
    if (!known) {
        id rm = SPSharedInstance(@"WirelessRadioManager");
        if (rm) {
            on = SPReadBool(rm, @"isWiFiEnabled", &known);
            if (!known) on = SPReadBool(rm, @"wifiEnabled", &known);
        }
    }
    if (known && !on) {
        // WiFi 已关 → 彻底断电（多路降级）
        SPForceSetBool(wm, @"setWiFiEnabled:", NO);
        SPForceSetBool(wm, @"setPowered:", NO);
        id rm = SPSharedInstance(@"WirelessRadioManager");
        SPForceSetBool(rm, @"setWiFiEnabled:", NO);
        SPForceSetBool(rm, @"setWiFiUserPreferenceEnabled:", NO);
    }
}
%end
