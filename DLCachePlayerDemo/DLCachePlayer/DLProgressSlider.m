//
//  DLCacheProgressView.m
//  DLCachePlayer
//
//  Created by DoubleLight on 2018/7/12.
//

#import "DLProgressSlider.h"
#import "DLResourceLoader.h"

@implementation DLProgressSlider
{
    UIColor * maxTrackColor;
    NSMutableArray * tasks;
    NSUInteger totalBytes;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.cachedColor = [UIColor darkGrayColor];
        self.continuous = NO;
    }
    return self;
}

- (void)setValue:(float)value
{
    [super setValue:value];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (!tasks) return;
    if (self.maximumTrackTintColor != [UIColor clearColor])
    {
        maxTrackColor = self.maximumTrackTintColor;
        self.maximumTrackTintColor = [UIColor clearColor];
    }
    CGRect track = [self trackRectForBounds:rect];
    CGContextRef maxTrack = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(maxTrack, maxTrackColor.CGColor);
    CGContextSetLineWidth(maxTrack, track.size.height);
    CGContextMoveToPoint(maxTrack, track.origin.x, rect.size.height / 2);
    CGContextAddLineToPoint(maxTrack, track.origin.x + track.size.width, rect.size.height / 2);
    CGContextStrokePath(maxTrack);
    
    CGFloat scale = track.size.width / totalBytes;
    for (DLRequestTask * task in tasks)
    {
        CGFloat begin = task.requestOffset * scale;
        CGFloat length = task.cacheLength * scale;
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(context, self.cachedColor.CGColor);
        CGContextSetLineWidth(context, track.size.height / 2);
        CGContextMoveToPoint(context, begin + track.origin.x, rect.size.height / 2);
        CGContextAddLineToPoint(context, begin + length + track.origin.x, rect.size.height / 2);
        CGContextStrokePath(context);
    }
}

- (void)updateProgress:(NSMutableArray *)setTasks totalBytes:(NSUInteger)setTotalBytes
{
    if (!setTasks) return;
    tasks = setTasks;
    totalBytes = setTotalBytes;
    __weak DLProgressSlider * weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf setNeedsDisplay];
    });
}

@end
