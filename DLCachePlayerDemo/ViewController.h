//
//  ViewController.h
//  DLCachePlayerDemo
//
//  Created by Hackinhisasi on 2018/7/19.
//  Copyright © 2018年 DoubleLight. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLCachePlayer.h"
#import "DLProgressSlider.h"

@interface ViewController : UIViewController<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *musicTable;


@property (weak, nonatomic) IBOutlet UIButton *btnPlayPause;
- (IBAction)btnPlayPause_Clicked:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
- (IBAction)btnNext_Clicked:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *btnPrev;
- (IBAction)btnPrev_Clicked:(id)sender;

@property (weak, nonatomic) IBOutlet DLProgressSlider *progressBar;
- (IBAction)progressBar_Changed:(id)sender;

@end

