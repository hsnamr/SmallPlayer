# SmallPlayer

A simple media player for **GNUstep**, built on [SmallStep](../SmallStep) and FOSS C/C++/Objective-C libraries.

## Features

- **File > Open** to open video files (formats depend on selected backend)
- **Play / Pause / Stop** controls
- Video display with aspect-ratio–preserving scaling
- Time display (current / duration)
- **Configurable backends**: **Backend** menu to choose FFmpeg, MPlayer, MEncoder, or mpv (choice persisted)
- Uses **SmallStep** for cross-platform app host, menu, and file dialog

## Dependencies

- **GNUstep** (base, gui, back): [GNUstep](https://gnustep.org/)
- **SmallStep**: sibling project at `../SmallStep` (built automatically)
- **FFmpeg** (for FFmpeg backend): libavformat, libavcodec, libavutil, libswscale — [FFmpeg](https://ffmpeg.org/)
- **MPlayer** (for MPlayer / MEncoder / mpv backends): [MPlayer](https://mplayerhq.hu/) — `mplayer` and `mencoder` in `PATH` (mpv backend uses `mplayer -identify` for dimensions)
- **mpv** (for mpv backend): [mpv](https://mpv.io/) — `mpv` in `PATH`

### Installing (Linux)

- **FFmpeg** (default backend):  
  Debian/Ubuntu: `sudo apt install libavformat-dev libavcodec-dev libavutil-dev libswscale-dev`  
  Fedora: `sudo dnf install ffmpeg-devel`  
  Arch: `sudo pacman -S ffmpeg`
- **MPlayer** (optional, for MPlayer/MEncoder backends and for mpv backend probe):  
  Debian/Ubuntu: `sudo apt install mplayer`  
  Fedora: `sudo dnf install mplayer`  
  Arch: `sudo pacman -S mplayer`
- **mpv** (optional, for mpv backend):  
  Debian/Ubuntu: `sudo apt install mpv`  
  Fedora: `sudo dnf install mpv`  
  Arch: `sudo pacman -S mpv`

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

Use **File > Open** to select a video file, then **Play**. Choose **Backend > FFmpeg / MPlayer / MEncoder / mpv** to switch backends (saved for next launch).

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
│   └── Backend/       # Configurable backends (protocol + implementations)
│       ├── SPPlayerBackend.h/m        # Protocol and factory
│       ├── SPFFmpegBackend.h/c       # FFmpeg C API
│       ├── SPFFmpegPlayerBackend.h/m # FFmpeg backend (ObjC)
│       ├── SPMplayerBackend.h/m      # MPlayer -vo yuv4mpeg
│       └── SPMencoderBackend.h/m     # MEncoder raw RGB24
└── obj/               # Build output (created by make)
```

## Architecture

- **Sources/Backend** – **SPPlayerBackend** protocol: open file, play/pause/stop, seek, deliver frames via delegate. **SPPlayerBackendCreate()** builds the active backend (FFmpeg, MPlayer, MEncoder, mpv). **SPFFmpegBackend** (C): FFmpeg open/decode → RGB24. **SPFFmpegPlayerBackend**: ObjC wrapper, decode thread, delegate callbacks. **SPMplayerBackend**: spawns `mplayer -vo yuv4mpeg:file=fd:1`, parses YUV4MPEG2, YUV→RGB, delegate. **SPMencoderBackend**: `mplayer -identify` for size, then `mencoder -ovc raw -vf format=rgb24 -of rawvideo -o -`, reads raw RGB24, delegate. **SPMpvBackend**: `mplayer -identify` for size, then `mpv --o=- --of=rawvideo --ovc=raw --ovcopts=format=rgb24 --no-audio`, reads raw RGB24, delegate.
- **Sources/Player** – **SPPlayerEngine**: Holds current backend (from user default), forwards all calls; implements **SPPlayerBackendDelegate** and forwards to app. **SPPlayerView**: Custom `NSView` for current frame (centered, scaled).
- **Sources/App** – **AppDelegate**: SmallStep host/menu/file dialog, main window, **Backend** menu (FFmpeg / MPlayer / MEncoder / mpv), Play/Pause/Stop, time label.

## License

Same as SmallStep; see [SmallStep LICENSE](../SmallStep/LICENSE) and your chosen FFmpeg license (LGPL/GPL).
