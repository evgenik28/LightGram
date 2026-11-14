libLightGramPlugins_FILES := $(shell find ../LightGramPlugins -maxdepth 1 -type f \( -name '*.m' -o -name '*.c' \) -print | sort)
libLightGramPlugins_CFLAGS = -Xclang -fobjc-runtime-has-weak -fobjc-arc -fblocks -std=gnu11 -I$(LIGHTGRAM_ROOT)/LightGramPlugins -I$(LIGHTGRAM_ROOT)/submodules/LegacyComponents -I$(LIGHTGRAM_ROOT)/theos/$(GENERATED_DIR)/python-include
libLightGramPlugins_OPTFLAG = -O2
libLightGramPlugins_LDFLAGS =
libLightGramPlugins_LINK_INPUTS =
