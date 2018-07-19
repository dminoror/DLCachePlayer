//
//  DLCacheProgressView.h
//  DLCachePlayer
//
//  Created by DoubleLight on 2018/7/12.
//

#import <UIKit/UIKit.h>

@interface DLProgressSlider : UISlider

@property (nonatomic, strong) UIColor * cachedColor;

- (void)updateProgress:(NSMutableArray *)setTasks totalBytes:(NSUInteger)setTotalBytes;

@end
