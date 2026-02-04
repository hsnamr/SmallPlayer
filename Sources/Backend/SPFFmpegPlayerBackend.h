//
//  SPFFmpegPlayerBackend.h
//  SmallPlayer
//
//  FFmpeg-based backend: uses SPFFmpegBackend (C) for decode, delivers frames via delegate.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "SPPlayerBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPFFmpegPlayerBackend : NSObject <SPPlayerBackend>
@end

NS_ASSUME_NONNULL_END
