//
//  SPMpvBackend.m
//  SmallPlayer
//
//  mpv backend: mplayer -identify -frames 0 for W/H/FPS, then
//  mpv <file> --o=- --of=rawvideo --ovc=raw --ovcopts=format=rgb24 --no-audio
//  Reads raw RGB24, delivers via delegate.
//

#import "SPMpvBackend.h"
#import <stdlib.h>
#import <string.h>

#if defined(GNUSTEP) && !__has_feature(objc_arc)
# define SPAutorelease(x) [(x) autorelease]
#else
# define SPAutorelease(x) (x)
#endif

@interface SPMpvBackend ()
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

@implementation SPMpvBackend

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

- (NSString *)backendIdentifier { return SPPlayerBackendIdentifierMpv; }
- (NSString *)backendDisplayName { return @"mpv"; }

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

/* Run mplayer -identify -frames 0 <file> and parse ID_VIDEO_WIDTH, ID_VIDEO_HEIGHT, ID_VIDEO_FPS */
- (BOOL)getVideoSizeForPath:(NSString *)path width:(int *)outW height:(int *)outH fps:(double *)outFps {
    const char *cpath = [path fileSystemRepresentation];
    if (!cpath) return NO;
    NSTask *identifyTask = [[NSTask alloc] init];
    NSPipe *identifyPipe = [[NSPipe alloc] init];
    [identifyTask setLaunchPath:@"/usr/bin/mplayer"];
    [identifyTask setArguments:@[
        [NSString stringWithUTF8String:cpath],
        @"-identify",
        @"-frames", @"0",
        @"-nosound",
        @"-really-quiet"
    ]];
    [identifyTask setStandardOutput:[identifyPipe fileHandleForWriting]];
    [identifyTask setStandardError:[NSPipe pipe]];
    @try {
        [identifyTask launch];
    } @catch (NSException *e) {
        (void)e;
        return NO;
    }
    [[identifyPipe fileHandleForWriting] closeFile];
    NSData *data = [[identifyPipe fileHandleForReading] readDataToEndOfFile];
    [identifyTask waitUntilExit];
    if (!data || [data length] == 0) return NO;
    NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    if (!str) return NO;
    int w = 0, h = 0;
    double fps = 24.0;
    for (NSString *line in [str componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"ID_VIDEO_WIDTH="]) {
            w = [[line substringFromIndex:15] intValue];
        } else if ([line hasPrefix:@"ID_VIDEO_HEIGHT="]) {
            h = [[line substringFromIndex:17] intValue];
        } else if ([line hasPrefix:@"ID_VIDEO_FPS="]) {
            fps = [[line substringFromIndex:13] doubleValue];
            if (fps <= 0) fps = 24.0;
        }
    }
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [str release];
#endif
    if (w <= 0 || h <= 0) return NO;
    *outW = w;
    *outH = h;
    *outFps = fps;
    return YES;
}

- (void)readLoop {
    @autoreleasepool {
        NSString *path = _currentPath;
        if (!path) return;
        const char *cpath = [path fileSystemRepresentation];
        if (!cpath) return;

        int w = 0, h = 0;
        double fps = 24.0;
        if (![self getVideoSizeForPath:path width:&w height:&h fps:&fps]) {
            id<SPPlayerBackendDelegate> del = self.delegate;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([del respondsToSelector:@selector(playerBackend:didFailWithError:)])
                    [del playerBackend:self didFailWithError:@"mpv: could not get video size (mplayer -identify)"];
            });
            _playing = NO;
            return;
        }
        _frameW = w;
        _frameH = h;
        _fps = fps;

        NSTask *task = [[NSTask alloc] init];
        NSPipe *pipe = [[NSPipe alloc] init];
        [task setLaunchPath:@"/usr/bin/mpv"];
        [task setArguments:@[
            [NSString stringWithUTF8String:cpath],
            @"--o=-",
            @"--of=rawvideo",
            @"--ovc=raw",
            @"--ovcopts=format=rgb24",
            @"--no-audio",
            @"--really-quiet",
            @"--no-osc",
            @"--no-input-default-bindings"
        ]];
        [task setStandardOutput:[pipe fileHandleForWriting]];
        [task setStandardError:[NSPipe pipe]];
        @try {
            [task launch];
        } @catch (NSException *e) {
            id<SPPlayerBackendDelegate> del = self.delegate;
            NSString *err = [NSString stringWithFormat:@"mpv failed: %@", [e reason]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([del respondsToSelector:@selector(playerBackend:didFailWithError:)])
                    [del playerBackend:self didFailWithError:err];
            });
            _playing = NO;
            return;
        }
        [[pipe fileHandleForWriting] closeFile];
        NSFileHandle *fh = [pipe fileHandleForReading];

        size_t frameBytes = (size_t)w * (size_t)h * 3;
        uint8_t *rgb = malloc(frameBytes);
        if (!rgb) { _playing = NO; return; }

        _task = task;
        _pipe = pipe;
        NSUInteger frameCount = 0;

        while (_readThreadShouldRun && [task isRunning]) {
            NSData *d = [fh readDataOfLength:frameBytes];
            if (!d || [d length] != frameBytes) break;
            [d getBytes:rgb length:frameBytes];

            _currentTimeSec = (double)frameCount / _fps;

            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO
                colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w * 3 bitsPerPixel:24];
            if (rep && [rep bitmapData]) {
                memcpy([rep bitmapData], rgb, frameBytes);
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
