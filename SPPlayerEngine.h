//
//  SPPlayerEngine.h
//  SmallPlayer
//
//  Objective-C wrapper around FFmpeg backend: open file, decode video on background thread,
//  expose current frame for display. Play/pause/stop.
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
@property (nonatomic, readonly) double duration;   // seconds, or -1 if unknown
@property (nonatomic, readonly) double currentTime;

/// Open a media file (path). Returns YES on success.
- (BOOL)openFile:(NSString *)path;

/// Close current file and stop playback.
- (void)close;

/// Start or resume playback (decode loop runs on background thread).
- (void)play;

/// Pause decoding (keeps last frame visible).
- (void)pause;

/// Stop and reset to start.
- (void)stop;

/// Seek to time in seconds.
- (void)seekToTime:(double)timeSec;

/// Latest decoded frame (thread-safe). Nil if no frame yet.
- (nullable NSImage *)currentFrame;

@end

NS_ASSUME_NONNULL_END
