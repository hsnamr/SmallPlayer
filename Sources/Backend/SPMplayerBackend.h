//
//  SPMplayerBackend.h
//  SmallPlayer
//
//  MPlayer backend: spawns mplayer -vo yuv4mpeg:file=fd:1, reads YUV4MPEG2 stream,
//  converts to RGB, delivers frames via delegate.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "SPPlayerBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPMplayerBackend : NSObject <SPPlayerBackend>
@end

NS_ASSUME_NONNULL_END
