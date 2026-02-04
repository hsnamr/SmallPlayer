//
//  SPPlayerEngine.m
//  SmallPlayer
//

#import "SPPlayerEngine.h"
#import "SPFFmpegBackend.h"
#import <stdlib.h>
#import <string.h>

#if defined(GNUSTEP) && !__has_feature(objc_arc)
# define SPAutorelease(x) [(x) autorelease]
# define SPRetain(x)      [(x) retain]
# define SPRelease(x)     [(x) release]
#else
# define SPAutorelease(x) (x)
# define SPRetain(x)      (x)
# define SPRelease(x)     (void)0
#endif

@interface SPPlayerEngine ()
@property (nonatomic, assign) void *ffContext;  // SPFFContext*
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL decodeThreadShouldRun;
@property (nonatomic, assign) double durationSec;
@property (nonatomic, assign) double currentTimeSec;
@property (nonatomic, strong) NSImage *lastFrame;
@property (nonatomic, strong) NSLock *frameLock;
@property (nonatomic, assign) NSThread *decodeThread;
@end

@implementation SPPlayerEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _ffContext = NULL;
        _playing = NO;
        _decodeThreadShouldRun = NO;
        _durationSec = -1.0;
        _currentTimeSec = 0.0;
        _lastFrame = nil;
        _frameLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self close];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_lastFrame release];
    [_frameLock release];
    [super dealloc];
#endif
}

- (BOOL)openFile:(NSString *)path {
    [self close];
    const char *cpath = [path fileSystemRepresentation];
    if (!cpath) return NO;
    void *ctx = sp_ff_open(cpath);
    if (!ctx) {
        if ([_delegate respondsToSelector:@selector(playerEngine:didFailWithError:)]) {
            [_delegate playerEngine:self didFailWithError:@"Failed to open file"];
        }
        return NO;
    }
    _ffContext = ctx;
    _durationSec = sp_ff_duration(ctx);
    _currentTimeSec = 0.0;
    return YES;
}

- (void)close {
    _decodeThreadShouldRun = NO;
    _playing = NO;
    if (_decodeThread && [_decodeThread isExecuting]) {
        while ([_decodeThread isExecuting])
            [NSThread sleepForTimeInterval:0.02];
    }
    if (_ffContext) {
        sp_ff_close(_ffContext);
        _ffContext = NULL;
    }
    [_frameLock lock];
    _lastFrame = nil;
    [_frameLock unlock];
}

- (void)play {
    if (!_ffContext) return;
    if (_playing) return;
    _playing = YES;
    _decodeThreadShouldRun = YES;
    _decodeThread = [[NSThread alloc] initWithTarget:self selector:@selector(decodeLoop) object:nil];
    [_decodeThread start];
}

- (void)pause {
    _decodeThreadShouldRun = NO;
    _playing = NO;
}

- (void)stop {
    _decodeThreadShouldRun = NO;
    _playing = NO;
    if (_ffContext) {
        sp_ff_seek(_ffContext, 0.0);
        _currentTimeSec = 0.0;
    }
}

- (void)seekToTime:(double)timeSec {
    if (!_ffContext) return;
    sp_ff_seek(_ffContext, timeSec);
    _currentTimeSec = timeSec;
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

- (void)decodeLoop {
    @autoreleasepool {
        void *ctx = _ffContext;
        if (!ctx) return;
        int w = 0, h = 0;
        size_t buf_size = (size_t)1920 * 1080 * 3;
        uint8_t *rgb = malloc(buf_size);
        if (!rgb) return;
        while (_decodeThreadShouldRun && ctx) {
            size_t need = (w > 0 && h > 0) ? (size_t)w * (size_t)h * 3 : buf_size;
            if (buf_size < need) {
                buf_size = need;
                uint8_t *n = realloc(rgb, buf_size);
                if (!n) break;
                rgb = n;
            }
            int r = sp_ff_decode_next(ctx, rgb, buf_size, &w, &h, &_currentTimeSec);
            if (r == 1) {
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
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self->_delegate respondsToSelector:@selector(playerEngine:didUpdateFrame:atTime:)])
                            [self->_delegate playerEngine:self didUpdateFrame:frameCopy atTime:t];
                    });
                }
                usleep(33000);  /* ~30 fps pacing */
            } else if (r == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self->_delegate respondsToSelector:@selector(playerEngineDidReachEnd:)])
                        [self->_delegate playerEngineDidReachEnd:self];
                });
                break;
            } else {
                break;
            }
        }
        free(rgb);
    }
}

@end
