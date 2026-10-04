// Tweak.x — systemPro 主入口
// 对标 SystemX 的核心流程：
//   1) 进程判定（5 个注入进程，各自只跑相关功能）
//   2) （可选）dpkg-status 自检门禁 —— 读 /var/jb/var/lib/dpkg/status，
//      校验"自己的包名 + install ok installed + 作者"三项，任何一项不符就整体摆烂。
//      SystemX 的对应实现在构造函数 0xb3e0~0xb5dc（字符串 Package/Status/Author/
//      Maintainer/install ok installed + /var/jb/var/lib/dpkg/status）。默认关，打包时开。
//   3) 加载开关（SPPrefs 惰性 + Darwin 热重载）
#import "Common.h"
#import "PrivateHeaders.h"
#import "Prefs.h"

BOOL SPIsSpringBoard = NO;
BOOL SPIsPreferences = NO;
BOOL SPIsPhotos      = NO;
BOOL SPIsPhone       = NO;
BOOL SPIsMessages    = NO;
BOOL SPGatePassed    = YES;

// ---------- 工具 ----------
long SPReadIvarLong(id obj, const char *name) {
    if (!obj) return -1;
    Ivar iv = class_getInstanceVariable(object_getClass(obj), name);
    if (!iv) return -1;
    ptrdiff_t off = ivar_getOffset(iv);
    const char *type = ivar_getTypeEncoding(iv);
    uint8_t *p = (uint8_t *)(__bridge void *)obj + off;
    if (!type) return -1;
    // 按 ivar 真实宽度读取（SystemX 直接按 8 字节读；这里更稳）
    switch (type[0]) {
        case 'q': case 'Q': case 'l': case 'L': return *(long *)p;
        case 'i': case 'I':                    return *(int *)p;
        case 's': case 'S':                    return *(short *)p;
        case 'c': case 'C':                    return *(signed char *)p;
        default:                               return *(long *)p;
    }
}

void SPLockDevice(void) {
    // 多路降级：不同系统上可用的锁屏入口不一样
    Class mgr = NSClassFromString(@"SBLockScreenManager");
    if (mgr) {
        id inst = [mgr respondsToSelector:@selector(sharedInstance)] ? [mgr sharedInstance] : nil;
        if ([inst respondsToSelector:@selector(lockUIFromSource:withOptions:)]) {
            [inst lockUIFromSource:0 withOptions:nil];
            return;
        }
    }
    Class uic = NSClassFromString(@"SBUIController");
    if (uic) {
        id inst = [uic respondsToSelector:@selector(sharedInstance)] ? [uic sharedInstance] : nil;
        if ([inst respondsToSelector:@selector(lockDevice)]) {
            [inst lockDevice];
            return;
        }
    }
    SPLog(@"lock: no available API");
}

id SPReadIvarObject(id obj, const char *name) {
    if (!obj) return nil;
    Ivar iv = class_getInstanceVariable(object_getClass(obj), name);
    if (!iv) return nil;
    ptrdiff_t off = ivar_getOffset(iv);
    id __unsafe_unretained *slot = (id __unsafe_unretained *)((uint8_t *)(__bridge void *)obj + off);
    return *slot;
}

// ---------- dpkg-status 自检（可选门禁） ----------
#if SP_ENABLE_INTEGRITY_CHECK
#define SP_PKG_ID     @"com.sytem.pro"
#define SP_PKG_AUTHOR @"operator"

static BOOL SPIntegrityCheckPasses(void) {
    NSArray *candidates = @[
        @"/var/jb/var/lib/dpkg/status",          // rootless
        @"/var/lib/dpkg/status",                  // 老式
        @"/var/mobile/Library/pkgmirror/DEBIAN.com.sytem.pro/control" // 只含 control 的兜底
    ];
    NSString *raw = nil;
    for (NSString *p in candidates) {
        raw = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
        if (raw.length) break;
    }
    if (!raw.length) { SPLog(@"integrity: no status file"); return NO; }

    // dpkg control 是 RFC822 段落格式：空行分段，段内 "Key: Value"
    BOOL found = NO;
    for (NSString *para in [raw componentsSeparatedByString:@"\n\n"]) {
        NSMutableDictionary *kv = [NSMutableDictionary dictionary];
        for (NSString *line in [para componentsSeparatedByString:@"\n"]) {
            NSRange r = [line rangeOfString:@":"];
            if (r.location == NSNotFound) continue;
            NSString *k = [line substringToIndex:r.location];
            NSString *v = [[line substringFromIndex:r.location + 1]
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            kv[k] = v;
        }
        if (![kv[@"Package"] isEqualToString:SP_PKG_ID]) continue;
        BOOL okStatus = [kv[@"Status"] isEqualToString:@"install ok installed"];
        BOOL okAuthor = [kv[@"Author"] containsString:SP_PKG_AUTHOR] ||
                        [kv[@"Maintainer"] containsString:SP_PKG_AUTHOR];
        if (okStatus && okAuthor) { found = YES; break; }
    }
    if (!found) SPLog(@"integrity: package check failed");
    return found;
}
#endif

// ---------- 构造函数 ----------
%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        SPIsSpringBoard = [bid isEqualToString:@"com.apple.springboard"];
        SPIsPreferences = [bid isEqualToString:@"com.apple.Preferences"];
        SPIsPhotos      = [bid isEqualToString:@"com.apple.mobileslideshow"];
        SPIsPhone       = [bid isEqualToString:@"com.apple.mobilephone"];
        SPIsMessages    = [bid isEqualToString:@"com.apple.MobileSMS"];
        SPLog(@"ctor: %@ (sb=%d prefs=%d photos=%d)", bid,
              SPIsSpringBoard, SPIsPreferences, SPIsPhotos);

#if SP_ENABLE_INTEGRITY_CHECK
        SPGatePassed = SPIntegrityCheckPasses();
        if (!SPGatePassed) { SPLog(@"gate failed, tweak inert"); return; }
#endif
        (void)[SPPrefs shared];        // 懒加载 + 挂 Darwin 通知
        SPStatusBarFeaturesInit();     // 状态栏模块的一次性初始化（响铃同步等）
    }
}
