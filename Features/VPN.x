// VPN.x — VPN 上色（对标 SystemX colorizeVPNStatusBar，全局 0x691fa，门控 0x691fa && VPN活跃0x691fc）
// 逻辑（按操作方要求）：VPN 已连接时，状态栏的 VPN 文字 / WiFi 信号 / 蜂窝网络类型 一起上色，
// 默认绿色（systemGreen #34C759）；VPN 未连接时一律不改色。
// VPN 活跃检测：getifaddrs 扫 utun*（有地址 = 隧道在用）→ NEVPNManager.status 兜底（1.5s TTL 缓存）。
#import "../Common.h"
#import "../PrivateHeaders.h"
#import "../Prefs.h"
#import <ifaddrs.h>
#import <net/if.h>

#pragma mark - VPN 活跃检测

static BOOL gSPVPNCache = NO;
static NSTimeInterval gSPVPNCacheAt = 0;

static BOOL SPVPNActive(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gSPVPNCacheAt > 0 && now - gSPVPNCacheAt < 1.5) return gSPVPNCache;

    BOOL active = NO;
    struct ifaddrs *ifa = NULL;
    if (getifaddrs(&ifa) == 0) {
        for (struct ifaddrs *p = ifa; p != NULL; p = p->ifa_next) {
            if (!p->ifa_name || !p->ifa_addr) continue;
            if (strncmp(p->ifa_name, "utun", 4) != 0) continue;
            if (!(p->ifa_flags & IFF_UP)) continue;
            if (p->ifa_addr->sa_family != AF_INET && p->ifa_addr->sa_family != AF_INET6) continue;
            active = YES;   // 带地址且 UP 的 utun = VPN 隧道
            break;
        }
        freeifaddrs(ifa);
    }
    if (!active) {
        // 兜底：NEVPNManager.connection.status == 3（已连接）
        Class m = NSClassFromString(@"NEVPNManager");
        if (m && [m respondsToSelector:NSSelectorFromString(@"sharedManager")]) {
            id mgr = ((id (*)(id, SEL))objc_msgSend)(m, NSSelectorFromString(@"sharedManager"));
            if (mgr && [mgr respondsToSelector:NSSelectorFromString(@"connection")]) {
                id conn = ((id (*)(id, SEL))objc_msgSend)(mgr, NSSelectorFromString(@"connection"));
                if (conn && [conn respondsToSelector:NSSelectorFromString(@"status")]) {
                    long long st = ((long long (*)(id, SEL))objc_msgSend)(conn, NSSelectorFromString(@"status"));
                    if (st == 3) active = YES;
                }
            }
        }
    }
    gSPVPNCache = active;
    gSPVPNCacheAt = now;
    return active;
}

static UIColor *SPVPNColor(void) {
    return [UIColor systemGreenColor];   // 默认绿
}

static BOOL SPVPNColorGate(void) {
    return SPIsSpringBoard && SPBool(kVPNTint) && SPVPNActive();
}

// 状态栏文字视图：把整串的 NSAttributedString 重写成我们指定的颜色。
// SystemX 的真做法就是「在 setText:/applyStyleAttributes: 里构造带色属性串替换样式」，
// 光事后 setTextColor 会被系统随后重设样式冲掉（这就是之前"完全没上色"的原因）。
static NSAttributedString *SPVPNColorizedAttributed(NSAttributedString *src, UIColor *color) {
    if (![src isKindOfClass:[NSAttributedString class]]) return nil;
    NSMutableAttributedString *m = [src mutableCopy];
    if (!m) return nil;
    [m addAttribute:NSForegroundColorAttributeName value:color
              range:NSMakeRange(0, m.length)];
    return m;
}

// 只对显示 "VPN" 的串上色（其余状态栏文字一律不动）
static NSMutableAttributedString *SPVPNMaybeColorize(NSAttributedString *attr, NSString *plain) {
    if (!SPIsSpringBoard || !SPBool(kVPNTint) || !SPVPNActive()) return nil;
    NSString *text = plain;
    if (![text isKindOfClass:[NSString class]] && [attr isKindOfClass:[NSAttributedString class]]) {
        text = attr.string;
    }
    if (![text isKindOfClass:[NSString class]] || ![text containsString:@"VPN"]) return nil;

    UIColor *c = SPVPNColor();
    if ([attr isKindOfClass:[NSAttributedString class]] && attr.length > 0) {
        return (NSMutableAttributedString *)SPVPNColorizedAttributed(attr, c);
    }
    return [[NSMutableAttributedString alloc] initWithString:text
                                                  attributes:@{ NSForegroundColorAttributeName: c }];
}

#pragma mark - 钩子

// WiFi 信号条（STUI 老样式）
%hook STUIStatusBarWifiSignalView
- (void)setActiveColor:(id)color {
    UIColor *spc = color;
    if (SPVPNColorGate()) spc = SPVPNColor();
    %orig(spc);
}
- (void)setInactiveColor:(id)color {
    UIColor *spc = color;
    if (SPVPNColorGate()) spc = SPVPNColor();
    %orig(spc);
}
%end

// WiFi 信号条（_UI 新样式：颜色由 fillColor 决定）
%hook _UIStatusBarWifiItem
- (id)_fillColorForUpdate:(id)update entry:(id)entry {
    if (SPVPNColorGate()) return SPVPNColor();
    return %orig;
}
%end

// 蜂窝网络类型（5G/4G 那行）：走属性串通道 + 事后补色
%hook STUIStatusBarCellularNetworkTypeView
- (void)applyStyleAttributes:(id)attributes {
    %orig;
    if (SPVPNColorGate()) [(id)self setTextColor:SPVPNColor()];
}
%end

%hook _UIStatusBarCellularNetworkTypeView
- (void)applyStyleAttributes:(id)attributes {
    %orig;
    if (SPVPNColorGate()) [(id)self setTextColor:SPVPNColor()];
}
%end

// 状态栏文字（VPN 胶囊就在这层）：拦截带色属性串 + setText
%hook STUIStatusBarStringView
- (void)setText:(id)text {
    id out = text;
    NSAttributedString *colored = SPVPNMaybeColorize(nil, text);
    if (colored) out = colored;
    %orig(out);
}
- (void)applyStyleAttributes:(id)attributes {
    %orig;
    if (!SPVPNColorGate()) return;
    NSString *t = nil;
    @try { t = [(id)self text]; } @catch (NSException *e) {}
    if ([t isKindOfClass:[NSString class]] && [t containsString:@"VPN"]) {
        @try { [(id)self setTextColor:SPVPNColor()]; } @catch (NSException *e) {}
    }
}
%end

%hook _UIStatusBarStringView
- (void)setText:(id)text {
    id out = text;
    NSAttributedString *colored = SPVPNMaybeColorize(nil, text);
    if (colored) out = colored;
    %orig(out);
}
- (void)applyStyleAttributes:(id)attributes {
    %orig;
    if (!SPVPNColorGate()) return;
    NSString *t = nil;
    @try { t = [(id)self text]; } @catch (NSException *e) {}
    if ([t isKindOfClass:[NSString class]] && [t containsString:@"VPN"]) {
        @try { [(id)self setTextColor:SPVPNColor()]; } @catch (NSException *e) {}
    }
}
%end
