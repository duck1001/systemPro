include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SystemProPrefs
SystemProPrefs_FILES = SystemProUI.m
SystemProPrefs_INSTALL_PATH = /Library/PreferenceBundles
SystemProPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I..
SystemProPrefs_FRAMEWORKS = UIKit Foundation QuartzCore
SystemProPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/systemPro.plist$(ECHO_END)
