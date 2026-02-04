# SmallPlayer

A simple media player for **GNUstep**, built on [SmallStep](../SmallStep) and FOSS C/C++/Objective-C libraries.

## Features

- **File > Open** to open video files (any format supported by FFmpeg)
- **Play / Pause / Stop** controls
- Video display with aspect-ratio–preserving scaling
- Time display (current / duration)
- Uses **SmallStep** for cross-platform app host, menu, and file dialog

## Dependencies

- **GNUstep** (base, gui, back): [GNUstep](https://gnustep.org/)
- **SmallStep**: sibling project at `../SmallStep` (built automatically)
- **FFmpeg** (libavformat, libavcodec, libavutil, libswscale): [FFmpeg](https://ffmpeg.org/)

### Installing FFmpeg (Linux)

- **Debian/Ubuntu**: `sudo apt install libavformat-dev libavcodec-dev libavutil-dev libswscale-dev`
- **Fedora**: `sudo dnf install ffmpeg-devel`
- **Arch**: `sudo pacman -S ffmpeg`

## Build

From the SmallPlayer directory:

```bash
source /usr/share/GNUstep/Makefiles/GNUstep.sh   # or your GNUstep env
make
```

This builds SmallStep first (in `../SmallStep`), then SmallPlayer. The executable is created in `obj/` (or your `GNUSTEP_OBJ_DIR`).

**Note:** SmallStep uses Objective-C 2 features (`weak`, `nullable`, blocks). Build SmallStep with **clang** (and optionally ARC) if your default GNUstep toolchain uses GCC; otherwise build SmallStep separately with the right flags, then build SmallPlayer.

## Run

```bash
./obj/SmallPlayer
```

Use **File > Open** to select a video file, then **Play**.

## Project layout

```
SmallPlayer/
├── GNUmakefile
├── README.md
├── LICENSE
├── Sources/
│   ├── App/           # Application entry and delegate
│   │   ├── main.m
│   │   ├── AppDelegate.h
│   │   └── AppDelegate.m
│   ├── Player/        # Playback engine and video view
│   │   ├── SPPlayerEngine.h
│   │   ├── SPPlayerEngine.m
│   │   ├── SPPlayerView.h
│   │   └── SPPlayerView.m
│   └── Backend/       # FFmpeg C backend
│       ├── SPFFmpegBackend.h
│       └── SPFFmpegBackend.c
└── obj/               # Build output (created by make)
```

## Architecture

- **Sources/Backend** – **SPFFmpegBackend** (C): Thin wrapper over FFmpeg for open/demux/decode video → RGB24.
- **Sources/Player** – **SPPlayerEngine** (ObjC): Runs decode on a background thread, exposes current frame and playback state; delegate callbacks for UI updates. **SPPlayerView** (ObjC): Custom `NSView` that draws the current frame (centered, scaled).
- **Sources/App** – **AppDelegate**: Uses SmallStep’s `SSHostApplication`, `SSMainMenu`, `SSFileDialog`; creates main window with video view and toolbar (Play/Pause, Stop, time label).

## License

Same as SmallStep; see [SmallStep LICENSE](../SmallStep/LICENSE) and your chosen FFmpeg license (LGPL/GPL).
