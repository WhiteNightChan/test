TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ByeByeCommunityPostMaybe

$(TWEAK_NAME)_FILES = $(shell find . -type f \( -name "*.x" -o -name "*.xm" \))
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk