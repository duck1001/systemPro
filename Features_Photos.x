// Features_Photos.x — 相册功能（只注入 com.apple.mobileslideshow）
// Hook 点对标 SystemX：
//   PUDeletePhotosActionController shouldSkipDeleteConfirmation          (0x131c8)
//   PXPhotoKitDeletePhotosActionController shouldSkipDeleteConfirmation  (0x131e8)
//   PXCuratedLibraryZoomLevelControl layoutSubviews/_updateSubviews       (0x133f4/0x13448)
//   PXPhotosViewModel allowsSelectAllAction                              (0x13390)
//   PHAssetCollection px_isUserCreated                                   (0x131a8, 隐藏"我的相簿"分组用)
#import "Common.h"
#import "PrivateHeaders.h"
#import "Prefs.h"

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
