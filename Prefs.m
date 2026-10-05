// Prefs.m — 开关读取器实现
// 设计（与 SystemX 一致的三层）：
//  1) dictionaryWithContentsOfFile 直读 plist（快，主线程零成本）
//  2) CFPreferencesCopyAppValue 回退（plist 尚未落盘时）
//  3) Darwin 通知 com.sytem.pro.prefschanged 触发重载（设置面板改完即生效）
#import "Prefs.h"
#import "Common.h"

static void SPPrefsChangedCallback(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation SPPrefs {
    NSDictionary *_cache;
}

+ (instancetype)shared {
    static SPPrefs *gShared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gShared = [[SPPrefs alloc] init];
        [gShared load];
        [gShared observeReload];
    });
    return gShared;
}

- (void)load {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:SPPreferencesPath()];
    if (![d isKindOfClass:[NSDictionary class]]) d = @{};
    @synchronized (self) {
        _cache = d;
    }
    SPLog(@"prefs loaded: %lu keys", (unsigned long)d.count);
}

- (void)observeReload {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    (__bridge const void *)self,
                                    SPPrefsChangedCallback,
                                    CFSTR("com.sytem.pro.prefschanged"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (id)valueFor:(NSString *)key {
    if (!SPGatePassed) return nil; // 门禁未过：一切开关视为关闭
    @synchronized (self) {
        id v = _cache[key];
        if (v) return v;
    }
    // 回退 1：重读一次盘（面板刚写完、缓存未更新时）
    NSDictionary *fresh = [NSDictionary dictionaryWithContentsOfFile:SPPreferencesPath()];
    if ([fresh isKindOfClass:[NSDictionary class]]) {
        @synchronized (self) { _cache = fresh; }
        id v2 = fresh[key];
        if (v2) return v2;
    }
    // 回退 2：CFPreferences（部分环境有效；roothide 下可能为空，故放在最后）
    CFPropertyListRef p = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                    CFSTR("com.sytem.pro"));
    return (__bridge_transfer id)p;
}

- (BOOL)boolFor:(NSString *)key {
    id v = [self valueFor:key];
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v boolValue];
    return NO;
}

- (long)intFor:(NSString *)key {
    id v = [self valueFor:key];
    if ([v isKindOfClass:[NSNumber class]]) return [v longValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue]; // 面板以字符串存数字
    return 0;
}
- (double)floatFor:(NSString *)key  { id v = [self valueFor:key]; return [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : 0; }

- (NSString *)stringFor:(NSString *)key default:(NSString *)def {
    id v = [self valueFor:key];
    if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
    return def;
}

@end

static void SPPrefsChangedCallback(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[SPPrefs shared] load];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SPPrefsReloaded" object:nil];
}

// ---------- C 便捷入口 ----------
BOOL SPBool(NSString *key)        { return [[SPPrefs shared] boolFor:key]; }
long SPInt(NSString *key)         { return [[SPPrefs shared] intFor:key]; }
double SPFloat(NSString *key)     { return [[SPPrefs shared] floatFor:key]; }
NSString *SPString(NSString *key, NSString *def) { return [[SPPrefs shared] stringFor:key default:def]; }
