libLightGramPlatform_FILES := $(shell find ../LightGramPlatform -type f -name '*.m' -print | sort)
libLightGramPlatform_FILES += ../thirdparty/quirc/quirc.c ../thirdparty/quirc/decode.c ../thirdparty/quirc/identify.c ../thirdparty/quirc/version_db.c
libLightGramPlatform_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(LIGHTGRAM_ROOT)/LightGramPlatform
ifeq ($(LIGHTGRAM_ARCH),armv6)
libLightGramPlatform_CFLAGS += -DLIGHTGRAM_ARMV6=1 -DLIGHTGRAM_IOS3_APPLICATION_BUILD=1 -I$(LIGHTGRAM_ROOT)/theos/compat/ios3 -I$(LIGHTGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(LIGHTGRAM_ROOT)/theos/compat/ios3/LightGramIOS3Compatibility.h
endif
libLightGramPlatform_OPTFLAG = -O3
libLightGramPlatform_LDFLAGS =
libLightGramPlatform_LINK_INPUTS =
