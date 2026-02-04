//
//  SPMplayerBackend.m
//  SmallPlayer
//
//  MPlayer backend: mplayer -vo yuv4mpeg:file=fd:1 -nosound -really-quiet <file>
//  Parses YUV4MPEG2 header and frames, converts YUV420 to RGB24, delivers via delegate.
//

#import "SPMplayerBackend.h"
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

#if defined(GNUSTEP) && !__has_feature(objc_arc)
# define SPAutorelease(x) [(x) autorelease]
#else
# define SPAutorelease(x) (x)
#endif

static void yuv420_to_rgb24(int w, int h, const uint8_t *y, const uint8_t *u, const uint8_t *v,
                            int ystride, int ustride, int vstride, uint8_t *rgb) {
    int i, j;
    for (j = 0; j < h; j++) {
        for (i = 0; i < w; i++) {
            int y0 = y[j * ystride + i];
            int ui = u[(j/2) * ustride + (i/2)];
            int vi = v[(j/2) * vstride + (i/2)];
            int c = y0 - 16;
            int d = ui - 128;
            int e = vi - 128;
            int r = (298 * c + 409 * e + 128) >> 8;
            int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
            int b = (298 * c + 516 * d + 128) >> 8;
            if (r < 0) r = 0; if (r > 255) r = 255;
            if (g < 0) g = 0; if (g > 255) g = 255;
            if (b < 0) b = 0; if (b > 255) b = 255;
            rgb[(j * w + i) * 3 + 0] = (uint8_t)r;
            rgb[(j * w + i) * 3 + 1] = (uint8_t)g;
            rgb[(j * w + i) * 3 + 2] = (uint8_t)b;
        }
    }
}

@interface SPMplayerBackend ()
@property (nonatomic, copy) NSString *currentPath;
@property (nonatomic, strong) NSTask *task;
@property (nonatomic, strong) NSPipe *pipe;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) double durationSec;
@property (nonatomic, assign) double currentTimeSec;
@property (nonatomic, assign) int frameW;
@property (nonatomic, assign) int frameH;
@property (nonatomic, assign) double fps;
@property (nonatomic, strong) NSImage *lastFrame;
@property (nonatomic, strong) NSLock *frameLock;
@property (nonatomic, strong) NSThread *readThread;
@property (nonatomic, assign) BOOL readThreadShouldRun;
@end

@implementation SPMplayerBackend

- (instancetype)init {
    self = [super init];
    if (self) {
        _playing = NO;
        _durationSec = -1.0;
        _currentTimeSec = 0.0;
        _frameW = 0;
        _frameH = 0;
        _fps = 24.0;
        _lastFrame = nil;
        _frameLock = [[NSLock alloc] init];
        _readThreadShouldRun = NO;
    }
    return self;
}

- (void)dealloc {
    [self close];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_currentPath release];
    [_lastFrame release];
    [_frameLock release];
    [super dealloc];
#endif
}

- (NSString *)backendIdentifier { return SPPlayerBackendIdentifierMPlayer; }
- (NSString *)backendDisplayName { return @"MPlayer"; }

- (BOOL)openFile:(NSString *)path {
    [self close];
    if (!path || [path length] == 0) return NO;
    _currentPath = [path copy];
    _durationSec = -1.0;
    _currentTimeSec = 0.0;
    _frameW = _frameH = 0;
    return YES;
}

- (void)close {
    _readThreadShouldRun = NO;
    _playing = NO;
    if (_readThread && [_readThread isExecuting]) {
        while ([_readThread isExecuting])
            [NSThread sleepForTimeInterval:0.02];
    }
    if (_task && [_task isRunning])
        [_task terminate];
    _task = nil;
    _pipe = nil;
    [_frameLock lock];
    _lastFrame = nil;
    [_frameLock unlock];
}

- (void)play {
    if (!_currentPath || _playing) return;
    _playing = YES;
    _readThreadShouldRun = YES;
    _readThread = [[NSThread alloc] initWithTarget:self selector:@selector(readLoop) object:nil];
    [_readThread start];
}

- (void)pause {
    _readThreadShouldRun = NO;
    _playing = NO;
    if (_task && [_task isRunning])
        [_task terminate];
    _task = nil;
}

- (void)stop {
    [self pause];
    _currentTimeSec = 0.0;
}

- (void)seekToTime:(double)timeSec {
    [self close];
    _currentTimeSec = timeSec;
    [self openFile:_currentPath];
    /* MPlayer yuv4mpeg doesn't support seek; we'd need to restart with -ss */
    (void)timeSec;
}

- (BOOL)isPlaying { return _playing; }
- (double)duration { return _durationSec; }
- (double)currentTime { return _currentTimeSec; }

- (NSImage *)currentFrame {
    [_frameLock lock];
    NSImage *img = _lastFrame;
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    if (img) img = [img retain];
#endif
    [_frameLock unlock];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    return [img autorelease];
#else
    return img;
#endif
}

- (void)readLoop {
    @autoreleasepool {
        NSString *path = _currentPath;
        if (!path) return;
        const char *cpath = [path fileSystemRepresentation];
        if (!cpath) return;

        NSTask *task = [[NSTask alloc] init];
        NSPipe *pipe = [[NSPipe alloc] init];
        [task setLaunchPath:@"/usr/bin/mplayer"];
        [task setArguments:@[
            [NSString stringWithUTF8String:cpath],
            @"-vo", @"yuv4mpeg:file=fd:1",
            @"-nosound",
            @"-really-quiet",
            @"-nofs",
            @"-noinput"
        ]];
        [task setStandardOutput:[pipe fileHandleForWriting]];
        [task setStandardError:[NSPipe pipe]];
        @try {
            [task launch];
        } @catch (NSException *e) {
            id<SPPlayerBackendDelegate> del = self.delegate;
            NSString *err = [NSString stringWithFormat:@"MPlayer failed: %@", [e reason]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([del respondsToSelector:@selector(playerBackend:didFailWithError:)])
                    [del playerBackend:self didFailWithError:err];
            });
            _playing = NO;
            return;
        }
        [[pipe fileHandleForWriting] closeFile];
        NSFileHandle *fh = [pipe fileHandleForReading];

        /* Parse YUV4MPEG2 header: "YUV4MPEG2 W%d H%d F%d:%d ..." */
        NSData *lineData = [fh readDataOfLength:256];
        if (!lineData || [lineData length] < 10) { _playing = NO; return; }
        NSString *header = [[NSString alloc] initWithData:lineData encoding:NSASCIIStringEncoding];
        int w = 0, h = 0, frNum = 24, frDen = 1;
        if (header) {
            NSScanner *s = [NSScanner scannerWithString:header];
            [s scanUpToString:@"W" intoString:NULL];
            if (![s isAtEnd]) {
                [s setScanLocation:[s scanLocation] + 1];
                [s scanInt:&w];
                [s scanUpToString:@"H" intoString:NULL];
                if (![s isAtEnd]) {
                    [s setScanLocation:[s scanLocation] + 1];
                    [s scanInt:&h];
                }
                [s scanUpToString:@"F" intoString:NULL];
                if (![s isAtEnd]) {
                    [s setScanLocation:[s scanLocation] + 1];
                    [s scanInt:&frNum];
                    [s scanString:@":" intoString:NULL];
                    [s scanInt:&frDen];
                }
            }
#if defined(GNUSTEP) && !__has_feature(objc_arc)
            [header release];
#endif
        }
        if (w <= 0 || h <= 0) { _playing = NO; return; }
        _frameW = w;
        _frameH = h;
        _fps = (frDen > 0) ? (double)frNum / (double)frDen : 24.0;

        size_t ySize = (size_t)w * (size_t)h;
        size_t uvSize = (size_t)(w/2) * (size_t)(h/2);
        size_t frameSize = ySize + uvSize * 2;
        uint8_t *yuv = malloc(frameSize);
        uint8_t *rgb = malloc((size_t)w * (size_t)h * 3);
        if (!yuv || !rgb) { free(yuv); free(rgb); _playing = NO; return; }

        _task = task;
        _pipe = pipe;
        NSUInteger frameCount = 0;

        while (_readThreadShouldRun && [task isRunning]) {
            /* Read "FRAME\n" */
            NSMutableData *frameHeader = [NSMutableData dataWithCapacity:8];
            for (;;) {
                NSData *one = [fh readDataOfLength:1];
                if (!one || [one length] != 1) break;
                uint8_t b;
                [one getBytes:&b length:1];
                [frameHeader appendBytes:&b length:1];
                if (b == '\n') break;
            }
            if ([frameHeader length] < 6) break;
            /* Read YUV420 frame */
            NSData *d = [fh readDataOfLength:frameSize];
            if (!d || [d length] != (NSUInteger)frameSize) break;
            [d getBytes:yuv length:frameSize];

            const uint8_t *y = yuv;
            const uint8_t *u = yuv + ySize;
            const uint8_t *v = yuv + ySize + uvSize;
            yuv420_to_rgb24(w, h, y, u, v, w, w/2, w/2, rgb);

            _currentTimeSec = (double)frameCount / _fps;

            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO
                colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w * 3 bitsPerPixel:24];
            if (rep && [rep bitmapData]) {
                memcpy([rep bitmapData], rgb, (size_t)(w * h * 3));
                NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize((CGFloat)w, (CGFloat)h)];
                [img addRepresentation:rep];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
                [rep release];
#endif
                [_frameLock lock];
                _lastFrame = SPAutorelease(img);
                [_frameLock unlock];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
                [img release];
#endif
                NSImage *frameCopy = [self currentFrame];
                double t = _currentTimeSec;
                id<SPPlayerBackendDelegate> del = self.delegate;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([del respondsToSelector:@selector(playerBackend:didDecodeFrame:atTime:)])
                        [del playerBackend:self didDecodeFrame:frameCopy atTime:t];
                });
            }
            frameCount++;
            usleep((useconds_t)(1000000.0 / _fps));
        }

        free(yuv);
        free(rgb);
        if (_readThreadShouldRun) {
            id<SPPlayerBackendDelegate> del = self.delegate;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([del respondsToSelector:@selector(playerBackendDidReachEnd:)])
                    [del playerBackendDidReachEnd:self];
            });
        }
        _task = nil;
        _playing = NO;
    }
}

@end
