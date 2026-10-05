// PrivateHeaders.h — 需要 hook 的私有类声明（有签名就按签名，没把握的按编译期认得出的保守签名）
// 只声明"我们要 hook 的方法"，避免引入 iSH 上无法编译的私有头。
#ifndef SP_PRIVATE_HEADERS_H
#define SP_PRIVATE_HEADERS_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ---------- SpringBoard ----------
@interface CSHomeAffordanceView : UIView
- (void)layoutSubviews;
- (void)didMoveToWindow;
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;
@end

@interface SBDockView : UIView
- (void)setBackgroundAlpha:(double)alpha;
- (void)layoutSubviews;
- (void)_backgroundContrastDidChange:(BOOL)changed;
@end

@interface SBRootFolderView : UIView
- (void)didMoveToWindow;
- (BOOL)isPageControlHidden;
- (void)setPageControlHidden:(BOOL)hidden;
- (void)setPageControlAlpha:(double)alpha;
@end

@interface SBFolderView : UIView
- (BOOL)isPageControlHidden;
- (void)setPageControlHidden:(BOOL)hidden;
- (void)setPageControlAlpha:(double)alpha;
@end

@interface SBFolderScrollAccessoryView : UIView
- (id)_pageIndicatorsView;
@end

@interface SBFloatingDockPlatterView : UIView
- (void)layoutSubviews;
@end

@interface SBIconListGridLayoutConfiguration : NSObject
- (long)numberOfPortraitColumns;
@end

@interface SBIconListFlowLayout : NSObject
- (long)numberOfColumnsForOrientation:(long)orientation;
- (long)numberOfRowsForOrientation:(long)orientation;
- (unsigned long)maximumIconCount;
@end

@interface SBHIconManager : NSObject
- (BOOL)iconViewDisplaysLabel:(id)iconView;
- (void)presentTodayOverlay;
- (void)presentTodayOverlayForIconDragManager:(id)manager;
@end

@interface SBIconController : NSObject
- (BOOL)iconManager:(id)manager iconViewDisplaysLabel:(id)iconView;
- (void)iconManager:(id)manager rootFolderController:(id)controller
    didEndOverscrollOnLastPageWithVelocity:(CGPoint)velocity translation:(CGPoint)translation;
- (void)iconManager:(id)manager rootFolderController:(id)controller
    didOverscrollOnLastPageByAmount:(double)amount;
@end

@interface SBSearchGesture : NSObject
- (void)revealAnimated:(BOOL)animated;
- (BOOL)searchScrollViewShouldRecognize:(id)scrollView;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (int)batteryCapacity;
- (int)batteryCapacityAsPercentage;
- (void)updateBatteryState:(id)state;
- (void)ACPowerChanged;
- (void)possiblyWakeForPowerStatusChangeWithUnlockSource:(long)source;
- (void)lockDevice;
@end

@interface SBBacklightController : NSObject
- (void)turnOnScreenFullyWithBacklightSource:(int)source;
@end

@interface SBNCScreenController : NSObject
- (BOOL)canTurnOnScreenForNotificationRequest:(id)request;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
- (void)_setUILocked:(BOOL)locked;
- (void)_reallySetUILocked:(BOOL)locked;
@end

@interface SBBootDefaults : NSObject
- (BOOL)dontLockAfterCrash;
@end

@interface SBHomeGrabberView : UIView
- (void)layoutSubviews;
@end

@interface BCBatteryDevice : NSObject
- (long)percentCharge;
@end

@interface SBIconLabelImageParametersBuilder : NSObject
- (id)buildParameters;
@end

@interface SBIconLabelImageParameters : NSObject
- (BOOL)dropsShadow;
- (void)setDropsShadow:(BOOL)dropsShadow;
@end

// ---------- 状态栏（iOS 15/16 STUI* 与 17+ _UI* 两套名字都留） ----------
@interface STUIStatusBarTimeItem : NSObject
- (id)applyUpdate:(id)update toDisplayItem:(id)displayItem;
@end

@interface _UIStatusBarTimeItem : NSObject
- (id)applyUpdate:(id)update toDisplayItem:(id)displayItem;
@end

// DisplayItem：上下偏移在 _updateComputedTransform 里叠（防跳；SystemX 同款）
@interface STUIStatusBarDisplayItem : NSObject
- (void)_updateComputedTransform;
@end

@interface _UIStatusBarDisplayItem : NSObject
- (void)_updateComputedTransform;
@end

@interface STUIStatusBarCellularNetworkTypeView : UIView
- (void)setText:(NSString *)text prefixLength:(long)prefixLength
    withStyleAttributes:(id)attributes forType:(long)type animated:(BOOL)animated;
@end

@interface _UIStatusBarCellularNetworkTypeView : UIView
- (void)setText:(NSString *)text prefixLength:(long)prefixLength
    withStyleAttributes:(id)attributes forType:(long)type animated:(BOOL)animated;
@end

@interface STUIStatusBarIndicatorQuietModeItem : NSObject
- (id)systemImageNameForUpdate:(id)update;
@end

// 真签名（实证自 iOS 反汇编）：focusName/imageName 是 C 字符串，data 是原始指针，
// 绝不能用 id 声明（ARC 会插 objc_retain，对非对象指针 = 段错误，SpringBoard 安全模式）
@interface _UIStatusBarDataQuietModeEntry : NSObject
// ⚠️ focusName/imageName 是真·C 字符串（const char *），data 是原始指针。
// 用 id 声明 → ARC 插 objc_retain → 对非对象指针段错误（安全模式）；传 NSString 也是错的（同一铁律）。
- (void)setFocusName:(const char *)name;
- (id)initFromData:(id *)data type:(int)type focusName:(const char *)focusName
    maxFocusLength:(int)mfl imageName:(const char *)imageName maxImageLength:(int)mil boolValue:(BOOL)bv;
@end

@interface UIStatusBarBatteryPercentItemView : UIView
- (id)updateForNewData:(id)data actions:(int)actions;
- (id)contentsImage;
- (void)didMoveToWindow;
@end

// ---------- 通用 UI（设置/电话/信息进程里生效） ----------
@interface _UIUITableViewCellSeparatorView : UIView
- (void)layoutSubviews;
@end

@interface _UITableViewCellSeparatorView : UIView
- (void)layoutSubviews;
@end

// ---------- 网络 / 蓝牙（WF + SB 私有类） ----------
@interface BluetoothManager : NSObject
- (void)bluetoothStateActionWithCompletion:(id)completion;
@end

@interface WFControlCenterStateMonitor : NSObject
- (void)performAction:(id)action;
- (BOOL)_airplaneModeEnabled;
@end

// ---------- 相册 ----------
@interface PUDeletePhotosActionController : NSObject
- (BOOL)shouldSkipDeleteConfirmation;
@end

@interface PXPhotoKitDeletePhotosActionController : NSObject
- (BOOL)shouldSkipDeleteConfirmation;
@end

@interface PXPhotosViewModel : NSObject
- (BOOL)allowsSelectAllAction;
@end

@interface PXCuratedLibraryZoomLevelControl : UIView
- (void)layoutSubviews;
@end

@interface PHAssetCollection : NSObject
- (BOOL)px_isUserCreated;
@end

#endif
