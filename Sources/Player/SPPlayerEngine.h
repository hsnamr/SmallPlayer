//
//  SPPlayerEngine.h
//  SmallPlayer
//
//  Configurable playback engine: delegates to a backend (FFmpeg, MPlayer, MEncoder).
//  Same API as before; backend is chosen via backendIdentifier (persisted in user default).
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SPPlayerEngine;

@protocol SPPlayerEngineDelegate <NSObject>
@optional
- (void)playerEngine:(SPPlayerEngine *)engine didUpdateFrame:(NSImage *)frame atTime:(double)timeSec;
- (void)playerEngineDidReachEnd:(SPPlayerEngine *)engine;
- (void)playerEngine:(SPPlayerEngine *)engine didFailWithError:(NSString *)error;
@end

@interface SPPlayerEngine : NSObject

@property (nonatomic, weak, nullable) id<SPPlayerEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) double currentTime;

/// Current backend identifier (e.g. @"ffmpeg", @"mplayer", @"mencoder"). Persisted in user default.
@property (nonatomic, copy) NSString *backendIdentifier;

/// All available backend identifiers.
+ (NSArray<NSString *> *)availableBackendIdentifiers;

/// Display name for a backend identifier.
+ (NSString *)displayNameForBackendIdentifier:(NSString *)identifier;

- (BOOL)openFile:(NSString *)path;
- (void)close;
- (void)play;
- (void)pause;
- (void)stop;
- (void)seekToTime:(double)timeSec;

- (nullable NSImage *)currentFrame;

@end

NS_ASSUME_NONNULL_END
