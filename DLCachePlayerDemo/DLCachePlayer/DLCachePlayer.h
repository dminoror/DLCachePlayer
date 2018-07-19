//
//  DLCachePlayer.h
//  DLCachePlayer
//
//  Created by DoubleLight on 2017/11/2.
//  Copyright © 2017年 DoubleLight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DLResourceLoader.h"

#define SAFE_BLOCK(block, ...)  if (block) { block(__VA_ARGS__); };

#define DLCachePlayerErrorDomain     @"DLCachePlayerErrorDomain"
#define DLCachePlayerErrorInvalidURL -500

typedef NS_ENUM(NSInteger, DLCachePlayerDownloadState) {
    DLCachePlayerDownloadStateIdle = 0,
    DLCachePlayerDownloadStateCurrent = 1,
    DLCachePlayerDownloadStateProload = 2
};
typedef NS_ENUM(NSInteger, DLCachePlayerPlayState) {
    DLCachePlayerPlayStateStop = 0,
    DLCachePlayerPlayStateInit,
    DLCachePlayerPlayStateReady,
    DLCachePlayerPlayStatePlaying,
    DLCachePlayerPlayStatePause,
};

@protocol DLCachePlayerDataDelegate <NSObject>
@optional

- (void)playerGetCurrentPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block;
- (void)playerGetPreloadPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block;
- (void)playerCacheProgress:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent tasks:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes;
- (void)playerDidFinishCache:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent data:(NSData *)data;
- (void)playerDidFail:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent error:(NSError *)error;
- (NSString *)playerTempFilePath;

@end

@protocol DLCachePlayerStateDelegate <NSObject>

- (void)playerPlayerItemChanged:(AVPlayerItem *)playerItem;
- (void)playerDidReachEnd:(AVPlayerItem *)playerItem;
- (void)playerDidPlayStateChanged:(DLCachePlayerPlayState)state;

- (void)playerReadyToPlay;
- (void)playerFailToPlay:(NSError *)error;
- (void)playerPlayingChanged:(BOOL)isPlaying;

@end

@interface DLCachePlayer : NSObject<DLResourceLoaderDelegate>

@property (nonatomic, strong, readonly) AVPlayer * audioPlayer;
@property (nonatomic, strong) dispatch_queue_t queueDL;
@property (nonatomic, weak, readonly) NSObject<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate> * delegate;
@property (nonatomic, assign, readonly) DLCachePlayerDownloadState downloadState;
@property (nonatomic, assign, readonly) DLCachePlayerPlayState playState;

@property (nonatomic, readonly) NSString * tempFilePath;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) CGFloat retryDelay;

+ (DLCachePlayer *)sharedInstance;
- (void)setDelegate:(NSObject<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate> *)setDelegate;

- (void)resetAndPlay;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)seekToTimeInterval:(NSTimeInterval)timeInterval completionHandler:(void (^)(BOOL finished))completionHandler;

- (BOOL)isPlaying;
- (NSTimeInterval)currentTime;
- (NSTimeInterval)currentDuration;
- (void)cachedProgress:(AVPlayerItem *)playerItem result:(void (^)(NSMutableArray * tasks, NSUInteger totalBytes))result;


@end
