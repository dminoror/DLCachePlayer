//
//  ViewController.h
//  DLCachePlayerDemo
//
//  Created by Hackinhisasi on 2018/7/19.
//  Copyright © 2018年 DoubleLight. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLCachePlayer.h"

@interface ViewController : UIViewController<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *musicTable;
- (IBAction)btnPlayPause_Clicked:(id)sender;

@end

