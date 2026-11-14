libLightGramUI_FILES := $(shell find ../LightGramUI -type f -name '*.m' -print | sort)
libLightGramUI_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(LIGHTGRAM_ROOT)/LightGramUI -I$(LIGHTGRAM_ROOT)/LightGramPlatform
ifeq ($(LIGHTGRAM_ARCH),armv6)
libLightGramUI_CFLAGS += -DLIGHTGRAM_ARMV6=1 -DLIGHTGRAM_IOS3_APPLICATION_BUILD=1 -I$(LIGHTGRAM_ROOT)/theos/compat/ios3 -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/openssl-OpenSSL_1_0_2h/include -I$(LIGHTGRAM_ROOT)/theos/compat/ios3/libdispatch -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libdispatch-libdispatch-187.10 -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/dependency-sources/libclosure-libclosure-38 -include $(LIGHTGRAM_ROOT)/theos/compat/ios3/LightGramIOS3Compatibility.h
endif
libLightGramUI_OPTFLAG = -O3
libLightGramUI_LDFLAGS =
libLightGramUI_LINK_INPUTS =
