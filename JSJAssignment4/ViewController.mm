//
//  ViewController.m
//  JSJAssignment4
//
//  Created by ch484-mac7 on 3/5/15.
//  Copyright (c) 2015 SMU. All rights reserved.
//


#import "ViewController.h"
#import "AVFoundation/AVFoundation.h"
#import <opencv2/opencv.hpp>
#import <opencv2/highgui/cap_ios.h>
#import "CvVideoCameraMod.h"
using namespace cv;

#define COLOR_THRESHOLD 50
#define MOVING_AVERAGE_WINDOW_SIZE 5
#define PEAK_WINDOW_SIZE 3
#define HEART_RATE_SENSING_SECONDS 10

@interface ViewController () <CvVideoCameraDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *torchButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;

@property (strong, nonatomic) CvVideoCameraMod *videoCamera;
@property (nonatomic) BOOL torchIsOn;

@property (strong, nonatomic) NSMutableArray *averageRed;

@property (nonatomic) int count;

@end

@implementation ViewController

- (NSMutableArray*)averageRed {
    if (!_averageRed) {
        _averageRed = [[NSMutableArray alloc] init];
    }
    return _averageRed;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.videoCamera = [[CvVideoCameraMod alloc] initWithParentView:self.imageView];
    self.videoCamera.delegate = self;
    
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = NO;
    
    [self.videoCamera start];
    
    self.torchIsOn = NO;
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.videoCamera stop];
}

#ifdef __cplusplus
-(void) processImage:(Mat &)image{
    
    // Do some OpenCV stuff with the image
    Mat image_copy;
    Mat grayFrame, output;
    
    // get average pixel intensity
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    Scalar avgPixelIntensity = cv::mean( image_copy );
    
    float blue = avgPixelIntensity.val[0];
    float green = avgPixelIntensity.val[1];
    float red = avgPixelIntensity.val[2];
    
    if ((blue < COLOR_THRESHOLD && green < COLOR_THRESHOLD) || (green < COLOR_THRESHOLD && red < COLOR_THRESHOLD) || (blue < COLOR_THRESHOLD && red < COLOR_THRESHOLD)) {
        if ([self.averageRed count] == 1) {
            NSLog(@"Starting count.");
        }
        self.count++;
        if (self.count >= 50) {
            [self.averageRed addObject:[NSNumber numberWithFloat:red]];
        }
        if ([self.averageRed count] >= HEART_RATE_SENSING_SECONDS * 30) {
            NSLog(@"original %@", self.averageRed);
            [self performMovingAverageCalculation];
            NSLog(@"first %@", self.averageRed);
            [self performMovingAverageCalculation];
            NSLog(@"second %@", self.averageRed);
            [self performMovingAverageCalculation];
            NSLog(@"third %@", self.averageRed);
            int numPeaks = (int)[[self findPeaks:100] count];
            NSLog(@"%u", [self calculateHeartRate:numPeaks seconds:HEART_RATE_SENSING_SECONDS]);
            [self.averageRed removeAllObjects];
            self.count = 0;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.torchButton.enabled = NO;
            self.switchCameraButton.enabled = NO;
        });
    } else {
        self.count = 0;
        [self.averageRed removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.videoCamera.defaultAVCaptureDevicePosition != AVCaptureDevicePositionFront) {
                self.torchButton.enabled = YES;
            }
            self.switchCameraButton.enabled = YES;
        });
    }
}
#endif

- (IBAction)toggleTorch:(id)sender {
    self.torchIsOn = !self.torchIsOn;
    [self setTorchOn:self.torchIsOn];
}

- (void)setTorchOn: (BOOL) onOff
{
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        [device setTorchMode: onOff ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
        [device unlockForConfiguration];
    }
}

- (IBAction)switchCamera:(UIButton *)sender {
    if (self.videoCamera.defaultAVCaptureDevicePosition == AVCaptureDevicePositionFront) {
        self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
        self.torchButton.enabled = YES;
    } else {
        self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
        self.torchButton.enabled = NO;
        self.torchIsOn = NO;
        [self setTorchOn:self.torchIsOn];
    }
    
    [self.videoCamera stop];
    [self.videoCamera start];
}

- (void)performMovingAverageCalculation {
    NSMutableArray *tempAverageRed = [[NSMutableArray alloc] init];
    
    int half_window = MOVING_AVERAGE_WINDOW_SIZE/2;
    
    for (int i = 0; i < [self.averageRed count]; i++) {
        double sum = 0;
        int count = 0;
        
        for (int j = i - half_window; j <= i + half_window; j++) {
            if (j >= 0 && j < [self.averageRed count]) {
                sum += [self.averageRed[j] doubleValue];
                count++;
            }
        }
        
        tempAverageRed[i] = [NSNumber numberWithDouble:sum/count];
    }
    
    self.averageRed = tempAverageRed;
}

// Find the maximum index in an array given a starting index and length of subarray
- (int)maxIndex:(NSMutableArray*)data
     startIndex:(int)startIndex
         length:(int)length {
    float max = -1;
    int maxIndex = -1;
    for (int i = startIndex; i < startIndex + length; i++) {
        if ([data[i] floatValue] > max) {
            max = [data[i] floatValue];
            maxIndex = i;
        }
    }
    return maxIndex;
}

- (NSMutableArray*)findPeaks:(int)numPeaks {
    NSMutableArray *peaks = [[NSMutableArray alloc] init];
    for (int i = 0; i < [self.averageRed count] - PEAK_WINDOW_SIZE; i++) {
        int index = [self maxIndex:self.averageRed startIndex:i length:PEAK_WINDOW_SIZE];
        //NSLog(@"%u", index);
        // check the index is the midpoint
        if (index == i + (PEAK_WINDOW_SIZE - 1)/2) {
            //NSLog(@"index is midpoint");
            if ([peaks count] == numPeaks) {
                [self replaceSmallestValueInArrayWithValue:peaks value:self.averageRed[index]];
            } else {
                [peaks addObject:self.averageRed[index]];
            }
        }
    }
    return peaks;
}

- (void)replaceSmallestValueInArrayWithValue:(NSMutableArray*)array
                                       value:(NSNumber*)value {
    for (int i = 0; i < [array count]; i++) {
        if (array[i] < value) {
            NSNumber *tempValue = array[i];
            array[i] = value;
            value = tempValue;
        }
    }
}

- (int)calculateHeartRate:(int)heartBeats
                  seconds:(int)seconds {
    return heartBeats * 60 / seconds;
}

@end
