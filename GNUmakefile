# GNUmakefile for SmallPlayer (GNUstep media player)
# Uses SmallStep (../SmallStep) and FFmpeg (libavformat, libavcodec, libavutil, libswscale)

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = SmallPlayer

SmallPlayer_OBJC_FILES = \
	Sources/App/main.m \
	Sources/App/AppDelegate.m \
	Sources/Player/SPPlayerEngine.m \
	Sources/Player/SPPlayerView.m

SmallPlayer_C_FILES = \
	Sources/Backend/SPFFmpegBackend.c

SmallPlayer_HEADER_FILES = \
	Sources/App/AppDelegate.h \
	Sources/Player/SPPlayerEngine.h \
	Sources/Player/SPPlayerView.h \
	Sources/Backend/SPFFmpegBackend.h

SmallPlayer_RESOURCE_FILES =

# SmallStep (sibling) + FFmpeg (pkg-config or fallback) + source dirs for cross-dir imports
SmallPlayer_INCLUDE_DIRS = -I. -ISources/App -ISources/Player -ISources/Backend -I../SmallStep -I../SmallStep/SmallStep/Core -I../SmallStep/SmallStep/Platform/Linux $(shell pkg-config --cflags libavformat libavcodec libavutil libswscale 2>/dev/null || echo "-I/usr/include")
SmallPlayer_LDFLAGS = -L../SmallStep/$(GNUSTEP_OBJ_DIR) -lSmallStep $(shell pkg-config --libs libavformat libavcodec libavutil libswscale 2>/dev/null || echo "-lavformat -lavcodec -lavutil -lswscale")
before-internal-all::
	$(MAKE) -C ../SmallStep

ADDITIONAL_OBJCFLAGS = -Wall

include $(GNUSTEP_MAKEFILES)/application.make
