//
//  AppDelegate.h
//  SmallPlayer
//
//  Application delegate: sets up main window, menu (File > Open, Quit), and player.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@protocol SSAppDelegate;

@interface AppDelegate : NSObject <SSAppDelegate, NSWindowDelegate>
@end
