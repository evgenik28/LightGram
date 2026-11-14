libLightGramUIBridge_FILES := $(shell find ../LightGramUIBridge -type f -name '*.m' -print | sort)
libLightGramUIBridge_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(LIGHTGRAM_ROOT)/LightGramUIBridge -I$(LIGHTGRAM_ROOT)/LightGramUI -I$(LIGHTGRAM_ROOT)/LightGramPlatform
ifeq ($(LIGHTGRAM_ARCH),armv6)
libLightGramUIBridge_CFLAGS += -DLIGHTGRAM_ARMV6=1 -DLIGHTGRAM_IOS3_APPLICATION_BUILD=1 -I$(LIGHTGRAM_ROOT)/theos/compat/ios3 -I$(LIGHTGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(LIGHTGRAM_ROOT)/theos/compat/ios3/LightGramIOS3Compatibility.h
endif
libLightGramUIBridge_OPTFLAG = -O3
libLightGramUIBridge_LDFLAGS =
libLightGramUIBridge_LINK_INPUTS =
