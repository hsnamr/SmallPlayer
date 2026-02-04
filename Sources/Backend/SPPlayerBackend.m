//
//  SPPlayerBackend.m
//  SmallPlayer
//
//  Backend protocol constants and factory.
//

#import "SPPlayerBackend.h"
#import "SPFFmpegPlayerBackend.h"
#import "SPMplayerBackend.h"
#import "SPMencoderBackend.h"
#import "SPMpvBackend.h"

NSString * const SPPlayerBackendIdentifierFFmpeg   = @"ffmpeg";
NSString * const SPPlayerBackendIdentifierMPlayer  = @"mplayer";
NSString * const SPPlayerBackendIdentifierMEncoder = @"mencoder";
NSString * const SPPlayerBackendIdentifierMpv      = @"mpv";

NSArray<NSString *> * SPPlayerBackendAvailableIdentifiers(void) {
    return @[ SPPlayerBackendIdentifierFFmpeg, SPPlayerBackendIdentifierMPlayer, SPPlayerBackendIdentifierMEncoder, SPPlayerBackendIdentifierMpv ];
}

id<SPPlayerBackend> SPPlayerBackendCreate(NSString *identifier) {
    if ([identifier isEqualToString:SPPlayerBackendIdentifierFFmpeg])
        return [[SPFFmpegPlayerBackend alloc] init];
    if ([identifier isEqualToString:SPPlayerBackendIdentifierMPlayer])
        return [[SPMplayerBackend alloc] init];
    if ([identifier isEqualToString:SPPlayerBackendIdentifierMEncoder])
        return [[SPMencoderBackend alloc] init];
    if ([identifier isEqualToString:SPPlayerBackendIdentifierMpv])
        return [[SPMpvBackend alloc] init];
    return nil;
}
