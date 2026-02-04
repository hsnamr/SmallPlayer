//
//  SPPlayerEngine.m
//  SmallPlayer
//
//  Engine that forwards to the selected backend and adapts delegate callbacks.
//

#import "SPPlayerEngine.h"
#import "SPPlayerBackend.h"
#import <stdlib.h>
#import <string.h>

#if defined(GNUSTEP) && !__has_feature(objc_arc)
# define SPAutorelease(x) [(x) autorelease]
#else
# define SPAutorelease(x) (x)
#endif

static NSString * const SPPlayerBackendUserDefaultKey = @"PreferredBackend";

@interface SPPlayerEngine () <SPPlayerBackendDelegate>
@property (nonatomic, strong) id<SPPlayerBackend> backend;
@property (nonatomic, copy) NSString *currentPath;
@end

@implementation SPPlayerEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:SPPlayerBackendUserDefaultKey];
        if (!saved || [saved length] == 0)
            saved = SPPlayerBackendIdentifierFFmpeg;
        _backendIdentifier = [saved copy];
        self.backend = SPPlayerBackendCreate(_backendIdentifier);
        if (!_backend)
            self.backend = SPPlayerBackendCreate(SPPlayerBackendIdentifierFFmpeg);
        if (_backend)
            [_backend setDelegate:self];
        _currentPath = nil;
    }
    return self;
}

- (void)dealloc {
    [self close];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_backend release];
    [_backendIdentifier release];
    [_currentPath release];
    [super dealloc];
#endif
}

- (void)setBackendIdentifier:(NSString *)backendIdentifier {
    if (!backendIdentifier || [backendIdentifier isEqualToString:_backendIdentifier]) return;
    NSString *path = [_currentPath copy];
    [_backend close];
    _backendIdentifier = [backendIdentifier copy];
    [[NSUserDefaults standardUserDefaults] setObject:_backendIdentifier forKey:SPPlayerBackendUserDefaultKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.backend = SPPlayerBackendCreate(_backendIdentifier);
    if (!_backend)
        self.backend = SPPlayerBackendCreate(SPPlayerBackendIdentifierFFmpeg);
    if (_backend)
        [_backend setDelegate:self];
    if (path && [path length] > 0) {
        [_backend openFile:path];
        _currentPath = [path copy];
    } else {
        _currentPath = nil;
    }
}

+ (NSArray<NSString *> *)availableBackendIdentifiers {
    return SPPlayerBackendAvailableIdentifiers();
}

+ (NSString *)displayNameForBackendIdentifier:(NSString *)identifier {
    id<SPPlayerBackend> b = SPPlayerBackendCreate(identifier);
    if (b) {
        NSString *name = [b backendDisplayName];
        return name ? name : identifier;
    }
    return identifier;
}

- (BOOL)openFile:(NSString *)path {
    if (!_backend) return NO;
    [self close];
    if (![path length]) return NO;
    if (![_backend openFile:path]) {
        if ([_delegate respondsToSelector:@selector(playerEngine:didFailWithError:)])
            [_delegate playerEngine:self didFailWithError:@"Failed to open file"];
        return NO;
    }
    _currentPath = [path copy];
    return YES;
}

- (void)close {
    [_backend close];
    _currentPath = nil;
}

- (void)play {
    [_backend play];
}

- (void)pause {
    [_backend pause];
}

- (void)stop {
    [_backend stop];
}

- (void)seekToTime:(double)timeSec {
    [_backend seekToTime:timeSec];
}

- (BOOL)isPlaying { return [_backend isPlaying]; }
- (double)duration { return [_backend duration]; }
- (double)currentTime { return [_backend currentTime]; }

- (NSImage *)currentFrame {
    return [_backend currentFrame];
}

#pragma mark - SPPlayerBackendDelegate

- (void)playerBackend:(id<SPPlayerBackend>)backend didDecodeFrame:(NSImage *)frame atTime:(double)timeSec {
    (void)backend;
    if ([_delegate respondsToSelector:@selector(playerEngine:didUpdateFrame:atTime:)])
        [_delegate playerEngine:self didUpdateFrame:frame atTime:timeSec];
}

- (void)playerBackendDidReachEnd:(id<SPPlayerBackend>)backend {
    (void)backend;
    if ([_delegate respondsToSelector:@selector(playerEngineDidReachEnd:)])
        [_delegate playerEngineDidReachEnd:self];
}

- (void)playerBackend:(id<SPPlayerBackend>)backend didFailWithError:(NSString *)error {
    (void)backend;
    if ([_delegate respondsToSelector:@selector(playerEngine:didFailWithError:)])
        [_delegate playerEngine:self didFailWithError:error];
}

@end
