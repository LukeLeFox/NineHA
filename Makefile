TARGET = iphone:clang:9.2:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa
TARGET_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/NineHA.entitlements

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = NineHA

NineHA_FILES = main.m \
	Sources/NineAuth.m \
	Sources/NineTheme.m \
	Sources/NineIcons.m \
	Sources/NineEntity.m \
	Sources/NineControls.m \
	Sources/NineNASAdapter.m \
	Sources/NineMoreInfoPanel.m \
	Sources/NineHomeDashboard.m \
	Sources/NineDashboard.m \
	Sources/NineServersController.m \
	Sources/NineRefreshSettingsController.m \
	Sources/NineAreasLoader.m \
	Sources/NineLiveSocket.m \
	ThirdParty/SocketRocket/SRWebSocket.m

NineHA_FRAMEWORKS = UIKit Foundation Security CFNetwork CoreText
NineHA_LIBRARIES = icucore
NineHA_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/ThirdParty/SocketRocket

# Comandi di collaudo via SSH (solo build locali: make DEBUGHOOKS=1).
ifeq ($(DEBUGHOOKS),1)
NineHA_CFLAGS += -DNINEHA_DEBUG_HOOKS=1
endif

include $(THEOS_MAKE_PATH)/application.mk
