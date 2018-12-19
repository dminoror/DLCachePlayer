//
//  ViewController.m
//  DLCachePlayerDemo
//
//  Created by Hackinhisasi on 2018/7/19.
//  Copyright © 2018年 DoubleLight. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    DLCachePlayer * player;
    NSMutableArray * resourceList;
    NSInteger currentIndex;
    NSTimer * progressTimer;
}

@end

@implementation ViewController
@synthesize currentProgressBar, preloadProgressBar;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    player = [DLCachePlayer sharedInstance];
    player.delegate = self;
    
    resourceList = [NSMutableArray new];
    NSURL * mp3PlayURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/dohProject/DLCachePlayer/master/DLCachePlayerDemo/Sample/1.%20sayonara%20memories.mp3"];
    NSURL * m4aPlayURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/dohProject/DLCachePlayer/master/DLCachePlayerDemo/Sample/2.%20kare.m4a"];
    NSURL * alacPlayURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/dohProject/DLCachePlayer/master/DLCachePlayerDemo/Sample/3.%20Departures%20(alac%20file).m4a"];
    NSURL * localPlayURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"4. The Glory Days" ofType:@"mp3"]];
    /// local file must use  [NSURL fileURLWithPath:]
    
    [resourceList addObject:mp3PlayURL];
    [resourceList addObject:m4aPlayURL];
    [resourceList addObject:alacPlayURL];
    [resourceList addObject:localPlayURL];
    [self.musicTable reloadData];
    
    progressTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(progressBar_Update) userInfo:nil repeats:YES];
}

#pragma mark - DLCachePlayerDataDelegate
- (void)playerGetCurrentPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block
{
    NSURL * playURL = [resourceList objectAtIndex:currentIndex];
    block(playURL, YES);
}

- (void)playerGetPreloadPlayURL:(AVPlayerItem * (^)(NSURL * url, BOOL cache))block
{
    NSInteger nextIndex = currentIndex + 1;
    if (nextIndex >= resourceList.count)
        nextIndex = 0;
    NSURL * playURL = [resourceList objectAtIndex:nextIndex];
    block(playURL, YES);
}

- (void)playerCacheProgress:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent tasks:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    if (isCurrent)
    {
        [currentProgressBar updateProgress:tasks totalBytes:totalBytes];
    }
    else
    {
        [preloadProgressBar updateProgress:tasks totalBytes:totalBytes];
    }
}

- (void)playerDidFinishCache:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent data:(NSData *)data
{
    NSLog(@"playerDidFinishCache, playerItem = %@, data length = %@", playerItem, @(data.length));
}
- (void)playerDidFail:(AVPlayerItem *)playerItem isCurrent:(BOOL)isCurrent error:(NSError *)error
{
    NSLog(@"playerDidFail, error = %@", error);
}

#pragma mark - DLCachePlayerStateDelegate
- (void)playerPlayerItemChanged:(AVPlayerItem *)playerItem
{
    NSLog(@"playerPlayerItemChanged, playerItem = %@", playerItem);
    AVURLAsset * asset = (AVURLAsset *)playerItem.asset;
    NSString * resourceName = [[asset.URL.absoluteString componentsSeparatedByString:@"/"] lastObject];
    resourceName = [resourceName stringByRemovingPercentEncoding];
    for (NSInteger index = 0; index < resourceList.count; index++)
    {
        UITableViewCell * cell = [self.musicTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        cell.selected = [cell.textLabel.text isEqualToString:resourceName];
    }
}
- (void)playerDidReachEnd:(AVPlayerItem *)playerItem
{
    NSLog(@"playerDidReachEnd, playerItem = %@", playerItem);
    [self btnNext_Clicked:nil];
}
- (void)playerDidPlayStateChanged:(DLCachePlayerPlayState)state
{
    NSLog(@"playerDidPlayStateChanged, state = %@", @(state));
    if (state == DLCachePlayerPlayStatePlaying)
    {
        self.btnPlayPause.selected = YES;
    }
    else if (state == DLCachePlayerPlayStatePause)
    {
        self.btnPlayPause.selected = NO;
    }
}
- (void)playerReadyToPlay
{
    NSLog(@"playerReadyToPlay");
}
- (void)playerFailToPlay:(NSError *)error
{
    NSLog(@"playerFailToPlay, error = %@", error);
}
- (void)playerPlayingChanged:(BOOL)isPlaying
{
    NSLog(@"playerPlayingChanged, isPlaying = %@", @(isPlaying));
}


#pragma mark - UITableView Delegate & DataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return resourceList.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"resourceCell" forIndexPath:indexPath];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"resourceCell"];
    }
    NSString * resourceName = ((NSURL *)[resourceList objectAtIndex:indexPath.row]).absoluteString;
    resourceName = [[resourceName componentsSeparatedByString:@"/"] lastObject];
    resourceName = [resourceName stringByRemovingPercentEncoding];
    cell.textLabel.text = resourceName;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    currentIndex = indexPath.row;
    [player resetAndPlay];
}

- (IBAction)btnPlayPause_Clicked:(id)sender
{
    if (player.playState == DLCachePlayerPlayStatePause)
    {
        [player resume];
    }
    else if (player.playState == DLCachePlayerPlayStatePlaying)
    {
        [player pause];
    }
    else if (player.playState == DLCachePlayerPlayStateStop)
    {
        [player resetAndPlay];
    }
}
- (IBAction)btnNext_Clicked:(id)sender
{
    currentIndex++;
    if (currentIndex >= resourceList.count)
        currentIndex = 0;
    [player resetAndPlay];
}
- (IBAction)btnPrev_Clicked:(id)sender
{
    currentIndex--;
    if (currentIndex < 0)
        currentIndex = resourceList.count - 1;
    [player resetAndPlay];
}
- (IBAction)progressBar_Changed:(id)sender
{
    [progressTimer invalidate];
    [player seekToTimeInterval:(currentProgressBar.value * [player currentDuration]) completionHandler:^(BOOL finished) {
        progressTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(progressBar_Update) userInfo:nil repeats:YES];
    }];
}
- (void)progressBar_Update
{
    self.currentProgressBar.value = [player currentTime] / [player currentDuration];
    [player cachedProgress:player.audioPlayer.currentItem result:^(NSMutableArray *tasks, NSUInteger totalBytes) {
        [currentProgressBar updateProgress:tasks totalBytes:totalBytes];
    }];
}

@end
