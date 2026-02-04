//
//  main.m
//  SmallPlayer
//
//  GNUstep media player using SmallStep and FFmpeg.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <SmallStep/SmallStep.h>
#import "AppDelegate.h"

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [SSHostApplication runWithDelegate:delegate];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
        [delegate release];
#endif
    }
    return 0;
}
