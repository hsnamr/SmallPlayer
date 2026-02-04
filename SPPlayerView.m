//
//  SPPlayerView.m
//  SmallPlayer
//

#import "SPPlayerView.h"
#import "SPPlayerEngine.h"

@interface SPPlayerView ()
@property (nonatomic, strong, nullable) NSImage *currentFrame;
@property (nonatomic, strong, nullable) NSColor *backgroundColor;
@end

@implementation SPPlayerView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setWantsLayer:NO];
        [self setBackgroundColor:[NSColor blackColor]];
    }
    return self;
}

- (void)setBackgroundColor:(NSColor *)color {
    _backgroundColor = color;
    [self setNeedsDisplay:YES];
}

- (void)setCurrentFrame:(NSImage *)frame {
    _currentFrame = frame;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
    NSImage *img = _currentFrame;
    if (img && [img size].width > 0 && [img size].height > 0) {
        NSRect bounds = [self bounds];
        NSSize imgSize = [img size];
        NSRect destRect = NSMakeRect(0, 0, bounds.size.width, bounds.size.height);
        CGFloat scaleW = bounds.size.width / imgSize.width;
        CGFloat scaleH = bounds.size.height / imgSize.height;
        CGFloat scale = (scaleW < scaleH) ? scaleW : scaleH;
        CGFloat w = imgSize.width * scale;
        CGFloat h = imgSize.height * scale;
        destRect = NSMakeRect((bounds.size.width - w) / 2, (bounds.size.height - h) / 2, w, h);
        [img drawInRect:destRect
               fromRect:NSMakeRect(0, 0, imgSize.width, imgSize.height)
              operation:NSCompositingOperationSourceOver
               fraction:1.0];
    }
}

@end
