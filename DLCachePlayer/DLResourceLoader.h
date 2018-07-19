//
//  DLResourceLoader.h
//  DLCachePlayer
//
//  Created by DoubleLight on 2017/11/10.
//  Copyright © 2017年 DoubleLight. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class DLResourceLoader;
@protocol DLResourceLoaderDelegate <NSObject>
@optional
- (void)loader:(DLResourceLoader *)loader loadingSuccess:(NSData *)data url:(NSURL *)url;
- (void)loader:(DLResourceLoader *)loader loadingFailWithError:(NSError *)error url:(NSURL *)url;
- (void)loader:(DLResourceLoader *)loader loadingProgress:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes;
@end

@interface DLResourceLoader : NSObject<AVAssetResourceLoaderDelegate, NSURLSessionDataDelegate>

@property (nonatomic, weak) id<DLResourceLoaderDelegate> delegate;
@property (nonatomic, weak) AVPlayerItem * playerItem;
@property (nonatomic, strong) NSString * originScheme;
@property (nonatomic, strong) NSMutableArray * tasks;
@property (nonatomic, assign) NSUInteger totalLength;

@property (nonatomic, assign, readonly) BOOL finished;
@property (nonatomic, assign, readonly) BOOL canceled;

- (void)stopLoading;

@end

@interface DLRequestTask : NSObject

@property (nonatomic, strong) NSURLSessionTask * task;
@property (nonatomic, strong) NSHTTPURLResponse * response;
@property (nonatomic, strong) NSURL * tempFileURL;
@property (nonatomic, strong) NSFileHandle * fileHandle;
@property (nonatomic, assign) NSUInteger requestOffset;
@property (nonatomic, assign) NSUInteger cacheLength;
@property (nonatomic, assign) NSUInteger requestEnd;
@property (nonatomic, assign) BOOL isLoading;

- (instancetype)initWithStart:(NSUInteger)start end:(NSUInteger)end;

- (NSUInteger)cacheEnd;
- (void)cancelLoading;

@end
