//
//  DLCachePlayer.m
//  DLCachePlayer
//
//  Created by DoubleLight on 2017/11/2.
//  Copyright © 2017年 DoubleLight. All rights reserved.
//

#import "DLCachePlayer.h"

@implementation DLCachePlayer
{
    DLResourceLoader * currentLoader;
    DLResourceLoader * preloadLoader;
    AVPlayerItem * loadingPlayerItem;
}
@synthesize audioPlayer, delegate, tempFilePath;
@synthesize downloadState, playState;

+ (DLCachePlayer *)sharedInstance
{
    static DLCachePlayer * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DLCachePlayer alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.queueDL = dispatch_queue_create("resource_queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
        
        audioPlayer = [[AVPlayer alloc] init];
        if (@available(iOS 10.0, *))
        {
            audioPlayer.automaticallyWaitsToMinimizeStalling = NO;
        }
        downloadState = DLCachePlayerDownloadStateIdle;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemFailedToPlayEndTime:)
                                                     name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemPlaybackStall:)
                                                     name:AVPlayerItemPlaybackStalledNotification
                                                   object:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        
        self.retryTimes = 3;
        self.retryDelay = 1;
        self.tempFilePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"tmp"] stringByAppendingPathComponent:@"musicCahce"];
    }
    return self;
}

- (void)setDelegate:(NSObject<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate> *)setDelegate
{
    delegate = setDelegate;
}
- (void)setTempFilePath:(NSString *)setTempFilePath
{
    if (self.tempFilePath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
    }
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:setTempFilePath isDirectory:&isDir])
    {
        NSError * error;
        [[NSFileManager defaultManager] createDirectoryAtPath:setTempFilePath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error)
        {
            return;
        }
    }
    tempFilePath = setTempFilePath;
    
}

#pragma mark - Player Method

- (void)resetAndPlay
{
    [self setupCurrentPlayerItem];
}
- (void)pause
{
    if (playState == DLCachePlayerPlayStatePlaying)
    {
        [self.audioPlayer pause];
        [self playerDidPlayStateChanged:DLCachePlayerPlayStatePause];
    }
}
- (void)resume
{
    [self.audioPlayer play];
}
- (void)stop
{
    [self.audioPlayer pause];
    if (self.audioPlayer.currentItem)
    {
        [self seekToTimeInterval:0 completionHandler:^(BOOL finished) {
            [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
        }];
    }
    else
    {
        [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
    }
}
- (void)seekToTimeInterval:(NSTimeInterval)timeInterval completionHandler:(void (^)(BOOL finished))completionHandler
{
    int32_t timeScale = self.audioPlayer.currentItem.duration.timescale;
    CMTime time = CMTimeMakeWithSeconds(timeInterval, timeScale);
    __block BOOL isPlaying = [self isPlaying];
    if (isPlaying)
        [self pause];
    __block void (^weakBlock)(BOOL finished) = completionHandler;
    __weak DLCachePlayer * weakSelf = self;
    [self.audioPlayer seekToTime:time completionHandler:^(BOOL finished) {
        if (isPlaying)
            [weakSelf resume];
        SAFE_BLOCK(weakBlock, finished);
    }];
}

- (BOOL)isPlaying
{
    return self.audioPlayer.rate != 0.f;
}

- (NSTimeInterval)currentTime
{
    if (self.audioPlayer.currentItem)
    {
        NSTimeInterval time = CMTimeGetSeconds(self.audioPlayer.currentTime);
        if (time == time)  // check isnan
            return time;
    }
    return 0;
}
- (NSTimeInterval)currentDuration
{
    if (self.audioPlayer.currentItem)
    {
        NSTimeInterval time = CMTimeGetSeconds(self.audioPlayer.currentItem.duration);
        if (time == time)
            return time;
    }
    return 0;
}

- (void)cachedProgress:(AVPlayerItem *)playerItem result:(void (^)(NSMutableArray * tasks, NSUInteger totalBytes))result
{
    if ([playerItem isEqual:currentLoader.playerItem])
    {
        SAFE_BLOCK(result, currentLoader.tasks, currentLoader.totalLength);
    }
    else if ([playerItem isEqual:preloadLoader.playerItem])
    {
        SAFE_BLOCK(result, preloadLoader.tasks, preloadLoader.totalLength);
    }
    else
    {
        SAFE_BLOCK(result, nil, 0);
    }
}

#pragma mark - Private Method

- (void)setupCurrentPlayerItem
{
    if (!currentLoader.finished)
    {
        [currentLoader stopLoading];
    }
    [audioPlayer replaceCurrentItemWithPlayerItem:nil];
    [self playerDidPlayStateChanged:DLCachePlayerPlayStateInit];
    __weak __typeof__(self) weakSelf = self;
    if ([self.delegate respondsToSelector:@selector(playerGetCurrentPlayURL:)])
    {
        [self.delegate playerGetCurrentPlayURL:^AVPlayerItem *(NSURL *url, BOOL cache) {
            if (url.absoluteString.length > 0)
            {
                downloadState = DLCachePlayerDownloadStateCurrent;
                if ([url isFileURL] || !cache)
                {
                    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithURL:url];
                    [audioPlayer replaceCurrentItemWithPlayerItem:playerItem];
                    [audioPlayer play];
                    [weakSelf setupPreloadPlayerItem];
                    return playerItem;
                }
                else if ([loadingPlayerItem.asset isKindOfClass:[AVURLAsset class]] &&
                         [((AVURLAsset *)loadingPlayerItem.asset).URL.resourceSpecifier isEqualToString:url.resourceSpecifier])
                {
                    currentLoader = ((DLResourceLoader *)((AVURLAsset *)loadingPlayerItem.asset).resourceLoader.delegate);
                    [audioPlayer replaceCurrentItemWithPlayerItem:loadingPlayerItem];
                    [audioPlayer play];
                    if ([self currentTime] > 0)
                    {
                        [self seekToTimeInterval:0 completionHandler:nil];
                    }
                    if (currentLoader.finished)
                    {
                        [weakSelf setupPreloadPlayerItem];
                    }
                    return loadingPlayerItem;
                }
                else
                {
                    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[self customSchemeURL:url] options:nil];
                    if (!preloadLoader.finished)
                    {
                        [preloadLoader stopLoading];
                    }
                    currentLoader = [[DLResourceLoader alloc] init];
                    currentLoader.originScheme = url.scheme;
                    currentLoader.delegate = self;
                    [asset.resourceLoader setDelegate:currentLoader queue:self.queueDL];
                    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithAsset:asset];
                    currentLoader.playerItem = playerItem;
                    loadingPlayerItem = playerItem;
                    [audioPlayer replaceCurrentItemWithPlayerItem:playerItem];
                    [audioPlayer play];
                    return playerItem;
                }
            }
            else
            {
                [weakSelf playerFailToPlay:[NSError errorWithDomain:DLCachePlayerErrorDomain code:DLCachePlayerErrorInvalidURL userInfo:@{ @"info" : @"setupCurrentPlayerItem" }]];
                [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
                return nil;
            }
        }];
    }
}
- (void)setupPreloadPlayerItem
{
    if ([self.delegate respondsToSelector:@selector(playerGetPreloadPlayURL:)])
    {
        [self.delegate playerGetPreloadPlayURL:^AVPlayerItem *(NSURL *url, BOOL cache) {
            if (url.absoluteString.length > 0)
            {
                downloadState = DLCachePlayerDownloadStateProload;
                if ([url isFileURL] || !cache)
                {
                    return [AVPlayerItem playerItemWithURL:url];
                }
                else if ([loadingPlayerItem.asset isKindOfClass:[AVURLAsset class]] &&
                         [((AVURLAsset *)loadingPlayerItem.asset).URL.resourceSpecifier isEqualToString:url.resourceSpecifier])
                {
                    preloadLoader = ((DLResourceLoader *)((AVURLAsset *)loadingPlayerItem.asset).resourceLoader.delegate);
                    return loadingPlayerItem;
                }
                else
                {
                    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[self customSchemeURL:url] options:nil];
                    if (!preloadLoader.finished)
                    {
                        [preloadLoader stopLoading];
                    }
                    preloadLoader = [[DLResourceLoader alloc] init];
                    preloadLoader.originScheme = url.scheme;
                    preloadLoader.delegate = self;
                    [asset.resourceLoader setDelegate:preloadLoader queue:self.queueDL];
                    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithAsset:asset];
                    preloadLoader.playerItem = playerItem;
                    loadingPlayerItem = playerItem;
                    NSArray * keys = @[@"duration"];
                    [((AVURLAsset *)playerItem.asset) loadValuesAsynchronouslyForKeys:keys completionHandler:nil];
                    return playerItem;
                }
            }
            else
            {
                return nil;
            }
        }];
    }
}

- (NSURL *)customSchemeURL:(NSURL *)url
{
    NSURLComponents * components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"cache";
    return [components URL];
}

#pragma mark - DLResourceLoader Delegate

- (void)loader:(DLResourceLoader *)loader loadingSuccess:data url:(NSURL *)url
{
    BOOL isCurrent = [loader isEqual:currentLoader];
    [self playerDidFinishCache:loadingPlayerItem isCurrent:isCurrent data:data];
    if (self.downloadState == DLCachePlayerDownloadStateCurrent)
    {
        [self setupPreloadPlayerItem];
    }
    downloadState = DLCachePlayerDownloadStateIdle;
}
- (void)loader:(DLResourceLoader *)loader loadingFailWithError:(NSError *)error url:(NSURL *)url
{
    BOOL isCurrent = [loader isEqual:currentLoader];
    [self playerDidFail:loadingPlayerItem isCurrent:isCurrent error:error];
    if (!isCurrent)
    {
        loadingPlayerItem = nil;
        [preloadLoader stopLoading];
        preloadLoader = nil;
    }
    downloadState = DLCachePlayerDownloadStateIdle;
}
- (void)loader:(DLResourceLoader *)loader loadingProgress:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    BOOL isCurrent = [loader isEqual:currentLoader];
    [self playerCacheProgress:loadingPlayerItem isCurrent:isCurrent tasks:tasks totalBytes:totalBytes];
}


#pragma mark - Player KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (object == self.audioPlayer && [keyPath isEqualToString:@"status"])
    {
        if (self.audioPlayer.status == AVPlayerStatusReadyToPlay)
        {
            //[self.audioPlayer play];
        }
        else if (self.audioPlayer.status == AVPlayerStatusFailed)
        {
            [self playerFailToPlay:self.audioPlayer.error];
        }
    }
    if (object == self.audioPlayer && [keyPath isEqualToString:@"rate"])
    {
        BOOL isPlaying = [self isPlaying];
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay)
        {
            if (isPlaying)
                [self playerDidPlayStateChanged:DLCachePlayerPlayStatePlaying];
        }
        [self playerPlayingChanged:isPlaying];
    }
    if (object == self.audioPlayer && [keyPath isEqualToString:@"currentItem"])
    {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        AVPlayerItem *lastPlayerItem = [change objectForKey:NSKeyValueChangeOldKey];
        if (lastPlayerItem != (id)[NSNull null])
        {
            @try {
                [lastPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
                [lastPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
            } @catch(id anException) {
                //do nothing, obviously it wasn't attached because an exception was thrown
            }
        }
        if (newPlayerItem != (id)[NSNull null])
        {
            [newPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [newPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            
            [self playerPlayerItemChanged:newPlayerItem];
        }
    }
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"])
    {
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusFailed)
        {
            [self playerFailToPlay:self.audioPlayer.currentItem.error];
        }
        else if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay)
        {
            [self playerReadyToPlay];
            [self playerDidPlayStateChanged:DLCachePlayerPlayStateReady];
            [self.audioPlayer play];
        }
    }
    /*
     if ([keyPath isEqualToString:@"loadedTimeRanges"] && self.audioPlayer.currentItem)
     {
     NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
     if (timeRanges && [timeRanges count])
     {
     CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
     CMTime time = CMTimeAdd(timerange.start, timerange.duration);
     NSLog(@"loadedRanged = %@", @(time.value / time.timescale));
     //[self playerCurrentItemLoading:time];
     }
     }*/
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
    [self playerDidReachEnd:notification.object];
}

- (void)playerItemFailedToPlayEndTime:(NSNotification *)notification
{
}

- (void)playerItemPlaybackStall:(NSNotification *)notification
{
    
}

#pragma mark - Delegate Callback

- (void)playerGetCurrentPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block
{
    if ([self.delegate respondsToSelector:@selector(playerGetCurrentPlayURL:)])
    {
        [self.delegate playerGetCurrentPlayURL:block];
    }
}
- (void)playerGetPreloadPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block
{
    if ([self.delegate respondsToSelector:@selector(playerGetPreloadPlayURL:)])
    {
        [self.delegate playerGetPreloadPlayURL:block];
    }
}
- (void)playerDidFinishCache:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent data:(NSData *)data
{
    if ([self.delegate respondsToSelector:@selector(playerDidFinishCache:isCurrent:data:)])
    {
        [self.delegate playerDidFinishCache:playerItem isCurrent:isCurrent data:data];
    }
}
- (void)playerDidFail:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent error:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(playerDidFail:isCurrent:error:)])
    {
        [self.delegate playerDidFail:playerItem isCurrent:isCurrent error:error];
    }
}
- (void)playerCacheProgress:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent tasks:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    if ([self.delegate respondsToSelector:@selector(playerCacheProgress:isCurrent:tasks:totalBytes:)])
    {
        [self.delegate playerCacheProgress:playerItem isCurrent:isCurrent tasks:tasks totalBytes:totalBytes];
    }
}

- (void)playerReadyToPlay
{
    if ([self.delegate respondsToSelector:@selector(playerReadyToPlay)])
    {
        [self.delegate playerReadyToPlay];
    }
}
- (void)playerFailToPlay:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(playerFailToPlay:)])
    {
        [self.delegate playerFailToPlay:error];
    }
}
- (void)playerPlayingChanged:(BOOL)isPlaying
{
    if ([self.delegate respondsToSelector:@selector(playerPlayingChanged:)])
    {
        [self.delegate playerPlayingChanged:isPlaying];
    }
}
- (void)playerPlayerItemChanged:(AVPlayerItem *)playerItem
{
    if ([self.delegate respondsToSelector:@selector(playerPlayerItemChanged:)])
    {
        [self.delegate playerPlayerItemChanged:playerItem];
    }
}
- (void)playerDidReachEnd:(AVPlayerItem *)playerItem
{
    if ([self.delegate respondsToSelector:@selector(playerDidReachEnd:)])
    {
        [self.delegate playerDidReachEnd:playerItem];
    }
}
- (void)playerDidPlayStateChanged:(DLCachePlayerPlayState)state
{
    playState = state;
    if ([self.delegate respondsToSelector:@selector(playerDidPlayStateChanged:)])
    {
        [self.delegate playerDidPlayStateChanged:playState];
    }
}

@end

