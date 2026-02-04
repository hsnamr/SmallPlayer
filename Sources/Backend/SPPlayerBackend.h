//
//  SPPlayerBackend.h
//  SmallPlayer
//
//  Protocol for configurable playback backends (FFmpeg, MPlayer, MEncoder, mpv).
//  Backends open a file, decode video, and deliver frames to a delegate.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SPPlayerBackend;

/// Delegate for frame delivery and lifecycle (called on main thread where possible).
@protocol SPPlayerBackendDelegate <NSObject>
@optional
- (void)playerBackend:(id<SPPlayerBackend>)backend didDecodeFrame:(NSImage *)frame atTime:(double)timeSec;
- (void)playerBackendDidReachEnd:(id<SPPlayerBackend>)backend;
- (void)playerBackend:(id<SPPlayerBackend>)backend didFailWithError:(NSString *)error;
@end

/// Backend identifier (e.g. @"ffmpeg", @"mplayer", @"mencoder", @"mpv").
extern NSString * const SPPlayerBackendIdentifierFFmpeg;
extern NSString * const SPPlayerBackendIdentifierMPlayer;
extern NSString * const SPPlayerBackendIdentifierMEncoder;
extern NSString * const SPPlayerBackendIdentifierMpv;

/// Abstract playback backend: open file, play/pause/stop, deliver frames via delegate.
@protocol SPPlayerBackend <NSObject>

@property (nonatomic, weak, nullable) id<SPPlayerBackendDelegate> delegate;

/// Unique identifier for this backend (e.g. @"ffmpeg").
- (NSString *)backendIdentifier;

/// Human-readable name (e.g. @"FFmpeg").
- (NSString *)backendDisplayName;

- (BOOL)openFile:(NSString *)path;
- (void)close;
- (void)play;
- (void)pause;
- (void)stop;
- (void)seekToTime:(double)timeSec;

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) double currentTime;
- (nullable NSImage *)currentFrame;

@end

/// Factory: create a backend instance for the given identifier, or nil if unknown.
FOUNDATION_EXPORT id<SPPlayerBackend> SPPlayerBackendCreate(NSString *identifier);

/// All available backend identifiers.
FOUNDATION_EXPORT NSArray<NSString *> * SPPlayerBackendAvailableIdentifiers(void);

NS_ASSUME_NONNULL_END
