# GNUmakefile for SmallPlayer (GNUstep media player)
# Uses SmallStep (../SmallStep) and FFmpeg (libavformat, libavcodec, libavutil, libswscale)

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = SmallPlayer

SmallPlayer_OBJC_FILES = \
	main.m \
	AppDelegate.m \
	SPPlayerEngine.m \
	SPPlayerView.m

SmallPlayer_C_FILES = \
	SPFFmpegBackend.c

SmallPlayer_HEADER_FILES = \
	AppDelegate.h \
	SPPlayerEngine.h \
	SPPlayerView.h

SmallPlayer_RESOURCE_FILES =

# SmallStep (sibling) + FFmpeg (pkg-config or fallback)
SmallPlayer_INCLUDE_DIRS = -I. -I../SmallStep -I../SmallStep/SmallStep/Core -I../SmallStep/SmallStep/Platform/Linux $(shell pkg-config --cflags libavformat libavcodec libavutil libswscale 2>/dev/null || echo "-I/usr/include")
SmallPlayer_LDFLAGS = -L../SmallStep/$(GNUSTEP_OBJ_DIR) -lSmallStep $(shell pkg-config --libs libavformat libavcodec libavutil libswscale 2>/dev/null || echo "-lavformat -lavcodec -lavutil -lswscale")
before-internal-all::
	$(MAKE) -C ../SmallStep

ADDITIONAL_OBJCFLAGS = -Wall

include $(GNUSTEP_MAKEFILES)/application.make
