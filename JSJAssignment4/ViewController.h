//
//  ViewController.h
//  JSJAssignment4
//
//  Created by ch484-mac7 on 3/5/15.
//  Copyright (c) 2015 SMU. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

typedef enum heartMonitorState {
    WAITING,
    CALIBRATING,
    MEASURING,
    DISPLAYING
} HeartMonitorState;

@end

