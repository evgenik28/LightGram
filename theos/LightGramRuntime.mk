libLightGramRuntime_FILES = ../LightGramRuntime/LGRuntime.m ../LightGramRuntime/LGDatabaseRuntime.m ../LightGramRuntime/LGCPUProfiler.m ../LightGramRuntime/LGDeviceTier.m ../LightGramRuntime/LGLaunchProfile.m ../LightGramRuntime/LGRemoteClock.m ../LightGramRuntime/LGUpdateArchive.m ../LightGramRuntime/LGDiagnostics.m ../LightGramRuntime/LGCrashSections.m ../LightGramRuntime/LGLogCatalog.m
libLightGramRuntime_CFLAGS = -fobjc-arc -fblocks -std=gnu99 -I$(LIGHTGRAM_ROOT)/LightGramRuntime
ifeq ($(LIGHTGRAM_ARCH),armv6)
libLightGramRuntime_CFLAGS += -DLIGHTGRAM_ARMV6=1 -I$(LIGHTGRAM_ROOT)/theos/generated/armv6/dependency-sources/libdispatch-libdispatch-187.10 -I$(LIGHTGRAM_ROOT)/theos/generated/armv6/dependency-sources/libclosure-libclosure-38 -include $(LIGHTGRAM_ROOT)/theos/compat/ios3/LightGramIOS3Compatibility.h
endif
ifeq ($(LIGHTGRAM_ARCH),arm64)
libLightGramRuntime_CFLAGS += -DOS_OBJECT_USE_OBJC=0
endif
libLightGramRuntime_OPTFLAG = -O3
libLightGramRuntime_LDFLAGS =
libLightGramRuntime_LINK_INPUTS =
