// Prefs.h — 开关读取器（对标 SystemX：直接读 plist 文件 + CFPreferences 回退 + Darwin 热重载）
#import <Foundation/Foundation.h>

@interface SPPrefs : NSObject
+ (instancetype)shared;

- (void)load;          // 重新读盘
- (BOOL)boolFor:(NSString *)key;
- (long)intFor:(NSString *)key;
- (double)floatFor:(NSString *)key;
- (NSString *)stringFor:(NSString *)key default:(NSString *)def;

// 观察 com.sytem.pro.prefschanged（CFNotificationCenter，Darwin 通知跨进程）
- (void)observeReload;
@end
