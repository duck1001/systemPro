// Features_Photos.x — 相册功能（只注入 com.apple.mobileslideshow）
// Hook 点对标 SystemX：
//   PUDeletePhotosActionController shouldSkipDeleteConfirmation          (0x131c8)
//   PXPhotoKitDeletePhotosActionController shouldSkipDeleteConfirmation  (0x131e8)
//   PXCuratedLibraryZoomLevelControl layoutSubviews/_updateSubviews       (0x133f4/0x13448)
//   PXPhotosViewModel allowsSelectAllAction                              (0x13390)
//   PHAssetCollection px_isUserCreated                                   (0x131a8, 隐藏"我的相簿"分组用)
#import "../Common.h"
#import "../PrivateHeaders.h"
#import "../Prefs.h"

%hook PUDeletePhotosActionController
- (BOOL)shouldSkipDeleteConfirmation {
    if (SPIsPhotos && SPBool(kSkipDeleteConfirmation)) return YES;
    return %orig;
}
%end

%hook PXPhotoKitDeletePhotosActionController
- (BOOL)shouldSkipDeleteConfirmation {
    if (SPIsPhotos && SPBool(kSkipDeleteConfirmation)) return YES;
    return %orig;
}
%end

%hook PXCuratedLibraryZoomLevelControl
- (void)layoutSubviews {
    %orig;
    if (SPIsPhotos && SPBool(kHideZoomLevelControl)) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}
%end

%hook PXPhotosViewModel
- (BOOL)allowsSelectAllAction {
    if (SPIsPhotos && SPBool(kAllowSelectAll)) return YES;
    return %orig;
}
%end

%hook PHAssetCollection
- (BOOL)px_isUserCreated {
    if (SPIsPhotos && SPBool(kMarkAlbumNotUserCreated)) return NO;
    return %orig;
}
%end

// ============================================================
// 视频默认放音：相册里播放器「首次」设置静音时抑制（仅拦系统默认那次；
// 用户后来手动点静音按钮不受影响 —— 靠 associated object 一次性标记区分）
// ============================================================
static const void *kSPMuteHandled = &kSPMuteHandled;

%hook AVPlayer
- (void)setMuted:(BOOL)muted {
    if (muted && SPIsPhotos && SPBool(kPhotosDefaultSound)) {
        if (!objc_getAssociatedObject(self, kSPMuteHandled)) {
            objc_setAssociatedObject(self, kSPMuteHandled, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            BOOL softNo = NO;
            %orig(softNo);
            return;
        }
    }
    %orig;
}
%end
