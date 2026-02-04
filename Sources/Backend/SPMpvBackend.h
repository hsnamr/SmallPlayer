//
//  SPMpvBackend.h
//  SmallPlayer
//
//  mpv backend: gets dimensions via mplayer -identify, spawns mpv encode mode
//  (--o=- --of=rawvideo --ovc=raw --ovcopts=format=rgb24 --no-audio), reads raw
//  RGB24 frames, delivers via delegate.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "SPPlayerBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPMpvBackend : NSObject <SPPlayerBackend>
@end

NS_ASSUME_NONNULL_END
