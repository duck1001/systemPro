// Common.h — systemPro 公共定义
// 架构对标 SystemX（思路参考，代码自研）：全局开关（读 com.sytem.pro plist）
// + 进程判定 + Darwin 通知热重载 + 少量 ObjC 运行时工具。
#ifndef SP_COMMON_H
#define SP_COMMON_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ---------- 基本信息 ----------
#define SP_DOMAIN        @"com.sytem.pro"
#define SP_PREFS_PATH    @"/var/mobile/Library/Preferences/com.sytem.pro.plist"
#define SP_NOTIFY_RELOAD "com.sytem.pro.prefschanged"

// 打包时把这里改成 1 可开启 dpkg 状态自检（对齐 SystemX 的思路：
// 读取 /var/jb/var/lib/dpkg/status，校验自己包名+作者，防止被改包）
#ifndef SP_ENABLE_INTEGRITY_CHECK
#define SP_ENABLE_INTEGRITY_CHECK 0
#endif

// ---------- 日志 ----------
#define SPLog(fmt, ...) NSLog(@"[systemPro] " fmt, ##__VA_ARGS__)

// ---------- 进程判定 ----------
extern BOOL SPIsSpringBoard;
extern BOOL SPIsPreferences;
extern BOOL SPIsPhotos;
extern BOOL SPIsPhone;
extern BOOL SPIsMessages;

// 自检门禁（SP_ENABLE_INTEGRITY_CHECK=1 且校验失败时整体禁用）
extern BOOL SPGatePassed;

// 各功能模块的一次性初始化（由主构造函数调用）
void SPStatusBarFeaturesInit(void);

// ---------- 开关读取（惰性加载 + Darwin 热重载 见 Prefs.m） ----------
BOOL  SPBool(NSString *key);
long  SPInt(NSString *key);
double SPFloat(NSString *key);
NSString *SPString(NSString *key, NSString *def);

// ---------- 工具 ----------
// 读取对象上的标量 ivar（对齐 SystemX 在 numberOfPortraitColumns 里的做法：
// class_getInstanceVariable + ivar_getOffset 直接取内存值）
long SPReadIvarLong(id obj, const char *name);
// 读取对象指针型 ivar（如 SBHomeGrabberView 的 _pillView）
id SPReadIvarObject(id obj, const char *name);
// 锁屏（多路降级，找不到 API 就静默放弃）
void SPLockDevice(void);

// ---------- 开关键名（与 prefs 面板一致） ----------
// General
#define kSilentStatusBarIcon        @"silentStatusBarIcon"
#define kSilentStatusBarIconSymbol  @"silentStatusBarIconSymbol"
#define kForce5GAStatusBar          @"force5GAStatusBar"
#define kFakeBatteryPercent         @"fakeBatteryPercent"
#define kNoLockAfterRespring        @"noLockAfterRespring"
#define kNotificationNoWake         @"notificationNoWakeEnabled"
#define kChargingWakeDisabled       @"disableLockScreenChargingWake"
// StatusBar/DateTime
#define kStatusBarDateTime          @"statusBarDateTimeEnabled"
#define kSBCDateTimeTimeFormat      @"statusBarDateTimeTimeFormat"
#define kSBCDateTimeDateFormat      @"statusBarDateTimeDateFormat"
#define kSBCDateTimeTimeFontSize    @"statusBarDateTimeTimeFontSize"
#define kSBCDateTimeDateFontSize    @"statusBarDateTimeDateFontSize"
#define kSBCDateTimeOffsetY         @"statusBarDateTimeOffsetY"
#define kSBCDateTimeEnglishDate     @"statusBarDateTimeEnglishDate"
// Desktop
#define kFiveIconDock               @"fiveIconDock"
#define kTransparentDock            @"transparentDock"
#define kHideHomeBar                @"hideHomeBar"
#define kHideHomePageDots           @"hideHomePageDots"
#define kHideWidgetLabels           @"hideWidgetLabels"
#define kHideHomeIconLabels         @"hideHomeIconLabels"
#define kHideHomeIconLabelShadow    @"hideHomeIconLabelShadow"
#define kDoubleTapToLock            @"doubleTapToLock"
#define kLongPressToLock            @"longPressToLock"
// Folder
#define kFolder4x4                  @"enableFolder4x4"
#define kFolderPreviewIconScale     @"folderPreviewIconScale"
// Disable
#define kDisableTodayView           @"disableTodayView"
#define kDisableAppLibrary          @"disableAppLibrary"
#define kDisableHomePullDownSearch  @"disableHomePullDownSearch"
#define kDisableSeparators          @"disableSeparators"
#define kDisablePhoneSeparators     @"disablePhoneSeparators"
#define kDisableMessagesSeparators  @"disableMessagesSeparators"
// Photos
#define kSkipDeleteConfirmation     @"skipDeleteConfirmation"
#define kHideZoomLevelControl       @"hideZoomLevelControl"
#define kAllowSelectAll             @"allowSelectAll"
#define kMarkAlbumNotUserCreated    @"markAlbumsAsNotUserCreated"
#define kPhotosDefaultSound         @"photosDefaultSound"       // 视频默认放音
// VPN / 网络 / 锁屏（0.0.3 功能轮）
#define kVPNTint                    @"colorizeVPNStatusBar"      // VPN 上色（默认绿，联动 WiFi/蜂窝）
#define kDisconnectWiFiBT           @"disconnectWiFiBT"         // 彻底关闭 WiFi 和蓝牙
#define kAutoDismissFaceID          @"autoDismissFaceID"        // 面容解锁进入主屏幕

// 设置面板里与系统分段的通用：分隔线在哪个进程被禁用
static inline BOOL SPSeparatorsDisabled(void) {
    if (SPIsPreferences && SPBool(kDisableSeparators))      return YES;
    if (SPIsPhone       && SPBool(kDisablePhoneSeparators)) return YES;
    if (SPIsMessages    && SPBool(kDisableMessagesSeparators)) return YES;
    return NO;
}

#endif
