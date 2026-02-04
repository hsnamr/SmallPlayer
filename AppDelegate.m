//
//  AppDelegate.m
//  SmallPlayer
//

#import "AppDelegate.h"
#import "SPPlayerEngine.h"
#import "SPPlayerView.h"
#import <SmallStep/SmallStep.h>

#if defined(GNUSTEP) && !__has_feature(objc_arc)
# define SPAutorelease(x) [(x) autorelease]
#else
# define SPAutorelease(x) (x)
#endif

@interface AppDelegate () <SPPlayerEngineDelegate>
@property (nonatomic, strong) NSWindow *mainWindow;
@property (nonatomic, strong) SPPlayerView *playerView;
@property (nonatomic, strong) SPPlayerEngine *playerEngine;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) NSButton *stopButton;
@property (nonatomic, strong) NSTextField *timeLabel;
@end

@implementation AppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _playerEngine = [[SPPlayerEngine alloc] init];
        [_playerEngine setDelegate:self];
    }
    return self;
}

- (void)applicationWillFinishLaunching {
    SSMainMenu *menu = [[SSMainMenu alloc] init];
    [menu setAppName:@"SmallPlayer"];
    NSArray *items = @[
        [SSMainMenuItem itemWithTitle:@"Open..." action:@selector(openFile:) keyEquivalent:@"o" modifierMask:NSCommandKeyMask target:self],
    ];
    [menu buildMenuWithItems:items quitTitle:@"Quit SmallPlayer" quitKeyEquivalent:@"q"];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [menu release];
#endif
}

- (void)applicationDidFinishLaunching {
    CGFloat width = 800;
    CGFloat height = 520;
    NSRect frame = NSMakeRect(100, 100, width, height);
    _mainWindow = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    [_mainWindow setTitle:@"SmallPlayer"];
    [_mainWindow setDelegate:self];
    [_mainWindow setReleasedWhenClosed:NO];

    NSView *contentView = [_mainWindow contentView];
    NSRect contentBounds = [contentView bounds];

    CGFloat toolbarHeight = 44;
    NSRect videoFrame = NSMakeRect(0, 0, contentBounds.size.width, contentBounds.size.height - toolbarHeight);
    _playerView = [[SPPlayerView alloc] initWithFrame:videoFrame];
    [_playerView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_playerView setPlayerEngine:_playerEngine];
    [contentView addSubview:_playerView];

    NSRect barFrame = NSMakeRect(0, contentBounds.size.height - toolbarHeight, contentBounds.size.width, toolbarHeight);
    NSView *toolbar = [[NSView alloc] initWithFrame:barFrame];
    [toolbar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

    _playPauseButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, 8, 80, 28)];
    [_playPauseButton setTitle:@"Play"];
    [_playPauseButton setButtonType:NSMomentaryPushButton];
    [_playPauseButton setBezelStyle:NSRoundedBezelStyle];
    [_playPauseButton setTarget:self];
    [_playPauseButton setAction:@selector(togglePlayPause:)];
    [toolbar addSubview:_playPauseButton];

    _stopButton = [[NSButton alloc] initWithFrame:NSMakeRect(98, 8, 60, 28)];
    [_stopButton setTitle:@"Stop"];
    [_stopButton setButtonType:NSMomentaryPushButton];
    [_stopButton setBezelStyle:NSRoundedBezelStyle];
    [_stopButton setTarget:self];
    [_stopButton setAction:@selector(stopPlayback:)];
    [toolbar addSubview:_stopButton];

    _timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(170, 10, 200, 24)];
    [_timeLabel setStringValue:@"00:00 / 00:00"];
    [_timeLabel setEditable:NO];
    [_timeLabel setBordered:NO];
    [_timeLabel setDrawsBackground:NO];
    [toolbar addSubview:_timeLabel];

    [contentView addSubview:toolbar];

    [_mainWindow makeKeyAndOrderFront:nil];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [_mainWindow release];
    [_playerView release];
    [_playPauseButton release];
    [_stopButton release];
    [_timeLabel release];
    [toolbar release];
#endif
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(id)sender {
    (void)sender;
    return YES;
}

- (void)applicationWillTerminate {
    [_playerEngine close];
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [_playerEngine close];
}

- (void)openFile:(id)sender {
    (void)sender;
    SSFileDialog *dialog = [SSFileDialog openDialog];
    [dialog setCanChooseFiles:YES];
    [dialog setCanChooseDirectories:NO];
    [dialog setAllowsMultipleSelection:NO];
    NSArray *urls = [dialog showModal];
    if (urls && [urls count] > 0) {
        NSURL *url = [urls objectAtIndex:0];
        NSString *path = [url path];
        if (path && [_playerEngine openFile:path]) {
            [_mainWindow setTitle:[NSString stringWithFormat:@"SmallPlayer - %@", [path lastPathComponent]]];
            [_playPauseButton setTitle:@"Play"];
            [self updateTimeLabel];
        }
    }
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [dialog release];
#endif
}

- (void)togglePlayPause:(id)sender {
    (void)sender;
    if ([_playerEngine isPlaying]) {
        [_playerEngine pause];
        [_playPauseButton setTitle:@"Play"];
    } else {
        [_playerEngine play];
        [_playPauseButton setTitle:@"Pause"];
    }
}

- (void)stopPlayback:(id)sender {
    (void)sender;
    [_playerEngine stop];
    [_playPauseButton setTitle:@"Play"];
    [self updateTimeLabel];
}

- (void)updateTimeLabel {
    double cur = [_playerEngine currentTime];
    double dur = [_playerEngine duration];
    NSString *curStr = [self timeStringFromSeconds:cur];
    NSString *durStr = (dur >= 0) ? [self timeStringFromSeconds:dur] : @"--:--";
    [_timeLabel setStringValue:[NSString stringWithFormat:@"%@ / %@", curStr, durStr]];
}

- (NSString *)timeStringFromSeconds:(double)sec {
    int s = (int)sec;
    int m = s / 60;
    s = s % 60;
    return [NSString stringWithFormat:@"%02d:%02d", m, s];
}

- (void)playerEngine:(SPPlayerEngine *)engine didUpdateFrame:(NSImage *)frame atTime:(double)timeSec {
    (void)engine;
    [_playerView setCurrentFrame:frame];
    [self updateTimeLabel];
}

- (void)playerEngineDidReachEnd:(SPPlayerEngine *)engine {
    (void)engine;
    [_playerEngine pause];
    [_playPauseButton setTitle:@"Play"];
    [self updateTimeLabel];
}

- (void)playerEngine:(SPPlayerEngine *)engine didFailWithError:(NSString *)error {
    (void)engine;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Playback error"];
    [alert setInformativeText:error ? error : @"Unknown error"];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
#if defined(GNUSTEP) && !__has_feature(objc_arc)
    [alert release];
#endif
}

@end
