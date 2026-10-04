TARGET = iphone:clang:9.2:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa
TARGET_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/NineHA.entitlements

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = NineHA

NineHA_FILES = main.m Sources/NineAuth.m Sources/NineDashboard.m Sources/NineTilesController.m Sources/NineGlyphView.m Sources/NineServersController.m
NineHA_FRAMEWORKS = UIKit Foundation Security
NineHA_CFLAGS = -fobjc-arc


NineHA_FILES += Sources/NineAreasLoader.m
NineHA_FILES += ThirdParty/SocketRocket/SRWebSocket.m
NineHA_CFLAGS += -I$(THEOS_PROJECT_DIR)/ThirdParty/SocketRocket
NineHA_FRAMEWORKS += CFNetwork
NineHA_LIBRARIES += icucore

NineHA_FILES += Sources/NineLovelaceLoader.m
NineHA_FILES += Sources/NineLovelaceController.m
NineHA_FRAMEWORKS += WebKit

NineHA_FILES += Sources/NineUnstableSettingsController.m

NineHA_FILES += Sources/NineLovelaceLive.m

NineHA_FILES += Sources/NineLovelaceActionEngine.m

NineHA_FILES += Sources/NineLightBrightnessController.m

include $(THEOS_MAKE_PATH)/application.mk
