//
//  SPMencoderBackend.h
//  SmallPlayer
//
//  MEncoder backend: gets dimensions via mplayer -identify, spawns mencoder -ovc raw
//  -vf format=rgb24 -of rawvideo -o -, reads raw RGB24 frames, delivers via delegate.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "SPPlayerBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPMencoderBackend : NSObject <SPPlayerBackend>
@end

NS_ASSUME_NONNULL_END
