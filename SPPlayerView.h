//
//  SPPlayerView.h
//  SmallPlayer
//
//  Custom NSView that displays the current video frame from SPPlayerEngine.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SPPlayerEngine;

@interface SPPlayerView : NSView

@property (nonatomic, weak, nullable) SPPlayerEngine *playerEngine;

/// Update the displayed frame (call from main thread when engine delivers a new frame).
- (void)setCurrentFrame:(nullable NSImage *)frame;

@end

NS_ASSUME_NONNULL_END
