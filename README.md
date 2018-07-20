# DLCachePlayer </br>
</br>
DLCachePlayer 提供播放音樂，並同時將檔案下載到本地的功能。</br>

## Features </br>
 * Support remote and local media URL. </br>
 * Buffer whole current playitem, and preload next playitem. </br>
 * Totaly seekable. </br>
 * Spoport .mp3 file. </br>
 * No playlist or queue, you can use own playlist structure. </br>

 ## How to use </br>
Implement `DLCachePlayerDataDelegate` and `DLCachePlayerStateDelegate` in your media module. </br>
```objective-c
#import "DLCachePlayer.h"

@interface ViewController : UIViewController<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate>
```
Set delegate for `DLCachePlayer` </br>
```objective-c
- (void)viewDidLoad 
{
    [DLCachePlayer sharedInstance].delegate = self;
}
```
Implement `playerGetCurrentPlayURL` and `playerGetPreloadPlayURL`, return your media URL in block.
```objective-c
- (void)playerGetCurrentPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block
{
    NSURL * playURL = @"your URL";
    block(playURL, YES);
}
```
Call `resetAndPlay` when you want to play.
```objective-c
[[DLCachePlayer sharedInstance] resetAndPlay];
```
Player will call `playerGetCurrentPlayURL`, play and buffer current playitem. </br>
After buffer finish, you can get media data in `playerDidFinishCache`, save it so you can play it locally next time. </br>
```objective-c
- (void)playerDidFinishCache:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent data:(NSData *)data
{
    
}
```

## ProgressSlider </br>
If you use a UISlider to show current progress, you can use `DLProgressSlider`. </br>
Implement `playerCacheProgress` and pass variables to update it's buffer progress.<\br>
```objective-c
- (void)playerCacheProgress:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent tasks:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    if (isCurrent)
    {
        [progressBar updateProgress:tasks totalBytes:totalBytes];
    }
}
```

## Other delegate </br>
Called when player current playitem changed, may update your UI here. </br>
```objective-c
- (void)playerPlayerItemChanged:(AVPlayerItem *)playerItem
```

Called when current playitem play finished, should increase your playlist index and call `resetAndPlay` here. </br>
```objective-c
- (void)playerDidReachEnd:(AVPlayerItem *)playerItem
```

Called when player state changed, may update your UI when `Stop`, `Playing` and `Pause`. </br>
```objective-c
- (void)playerDidPlayStateChanged:(DLCachePlayerPlayState)state
{
    switch (state)
    {
        case DLCachePlayerPlayStateStop:
            break;
        case DLCachePlayerPlayStateInit:
            break;
        case DLCachePlayerPlayStateReady:
            break;
        case DLCachePlayerPlayStatePlaying:
            break;
        case DLCachePlayerPlayStatePause:
            break;
    }
}
```
</br>

## Demo
<img src="https://i.imgur.com/wS8EIRX.gif" width="240" height="427"> Basic remote media play.

<img src="https://i.imgur.com/GG6NN0X.gif" width="240" height="427">  How preload worked. When next clicked, some progress already exist.

<img src="https://i.imgur.com/jO1RjT2.gif" width="240" height="427"> How seek worked. Player buffer progress after current time first.</br>

See more in Demo project.

## Licenses </br>
All source code is licensed under the MIT License. </br>
