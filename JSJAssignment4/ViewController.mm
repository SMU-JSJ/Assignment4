//  Team JSJ - Jordan Kayse, Jessica Yeh, Story Zanetti
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

// Setup constants
#define COLOR_THRESHOLD 80
#define MOVING_AVERAGE_WINDOW_SIZE 5
#define PEAK_WINDOW_SIZE 3
#define HEART_RATE_SENSING_SECONDS 10
#define TORCH_ON_THRESHOLD 50
#define TORCH_OFF_THRESHOLD 90
#define CALIBRATION_THRESHOLD 60

@interface ViewController () <CvVideoCameraDelegate>

@property (weak, nonatomic) IBOutlet UILabel *heartLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIView *progress;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *progressHeightConstraint;

@property (strong, nonatomic) CvVideoCameraMod *videoCamera;
@property (strong, nonatomic) NSMutableArray *averageRed;

@property (nonatomic) BOOL torchIsOn;
@property (nonatomic) int thresholdCount;
@property (nonatomic) int torchOffCount;
@property (nonatomic) int heartRate;
@property (nonatomic) HeartMonitorState state;
@property (nonatomic) CGFloat progressValue;

@end

@implementation ViewController

@synthesize state = _state;

// Lazily instantiate averageRed
- (NSMutableArray*)averageRed {
    if (!_averageRed) {
        _averageRed = [[NSMutableArray alloc] init];
    }
    return _averageRed;
}

// When the state is set, the heart label is set to match the current state
- (void)setState:(HeartMonitorState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.heartLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:24];
        if (state == WAITING) {
            self.heartLabel.text = @"Place finger on camera.";
        } else if (state == CALIBRATING) {
            self.heartLabel.text = @"Calibrating...";
        } else if (state == MEASURING) {
            self.heartLabel.text = @"Hold still!";
        } else if (state == DISPLAYING) {
            self.heartLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:36];
            self.heartLabel.text = [NSString stringWithFormat:@"%u BPM", self.heartRate];
        }
    });
    
    _state = state;
}

// When the progress value is set, update the constraint for the height of the
// progress view
- (void)setProgressValue:(CGFloat)progressValue {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view removeConstraint:self.progressHeightConstraint];
        self.progressHeightConstraint = [NSLayoutConstraint constraintWithItem:self.progress
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeHeight
                                                                    multiplier:progressValue
                                                                      constant:0];
        
        [self.view addConstraint:self.progressHeightConstraint];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Creates and setups the video camera
    self.videoCamera = [[CvVideoCameraMod alloc] initWithParentView:self.imageView];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = NO;
    
    [self.videoCamera start];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.progressValue = 0;
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.videoCamera stop];
}

#ifdef __cplusplus
- (void)processImage:(Mat&)image {
    
    // Do some OpenCV stuff with the image
    Mat image_copy;
    Mat grayFrame, output;
    
    // get average pixel intensity
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    Scalar avgPixelIntensity = cv::mean(image_copy);
    
    // Get average values for blue, green, and red
    float blue = avgPixelIntensity.val[0];
    float green = avgPixelIntensity.val[1];
    float red = avgPixelIntensity.val[2];
    
    // If at least two of the average color values meet the threshold,
    // (a finger or an object is in front of the camera)
    if ((blue < COLOR_THRESHOLD && green < COLOR_THRESHOLD) ||
        (green < COLOR_THRESHOLD && red < COLOR_THRESHOLD) ||
        (blue < COLOR_THRESHOLD && red < COLOR_THRESHOLD)) {
        
        // Increase the count for how many times the color threshold has been met
        self.thresholdCount++;
        
        // If the calibration threshold is met, start measuring heart rate
        // Otherwise, if the threshold for turning the torch on is met, turn
        // the torch on and set the state to calibration mode
        if (self.thresholdCount >= CALIBRATION_THRESHOLD) {
            // The app is now in the measuring state
            self.state = MEASURING;
            // Add the average red value to the array
            [self.averageRed addObject:[NSNumber numberWithFloat:red]];
            // Update the progress
            self.progressValue = (CGFloat)[self.averageRed count] / (HEART_RATE_SENSING_SECONDS * 30);
        } else if (self.thresholdCount >= TORCH_ON_THRESHOLD) {
            // Turn torch on
            self.torchIsOn = YES;
            [self setTorchOn:self.torchIsOn];
            
            // Only set the state to calibrating if the state was originally
            // waiting or displaying
            if (self.state == WAITING || self.state == DISPLAYING) {
                self.state = CALIBRATING;
            }
        }
        
        // Stop measuring heart rate if the measuring time period has finished
        if ([self.averageRed count] >= HEART_RATE_SENSING_SECONDS * 30) {
            // Turn torch off
            self.torchIsOn = NO;
            [self setTorchOn:self.torchIsOn];
            
            // Smooth curve using a moving average filter
            [self performMovingAverageCalculation];
            [self performMovingAverageCalculation];
            [self performMovingAverageCalculation];
            
            // Get the number of peaks
            int numPeaks = (int)[[self findPeaks:100] count];
            
            // Output final heart rate
            self.heartRate = [self calculateHeartRate:numPeaks seconds:HEART_RATE_SENSING_SECONDS];
            
            // Change the state to displaying
            self.state = DISPLAYING;
            
            // Reset values
            [self.averageRed removeAllObjects];
            self.thresholdCount = 0;
        }
    } else {
        self.torchOffCount++;
        
        // If the threshold for turning the torch off has been reached
        if(self.torchOffCount >= TORCH_OFF_THRESHOLD) {
            // Turn torch off and reset the counter
            self.torchIsOn = NO;
            [self setTorchOn:self.torchIsOn];
            self.torchOffCount = 0;
            
            // If the app is not currently displaying a heart rate, change
            // the state back to waiting
            if (self.state != DISPLAYING) {
                self.state = WAITING;
            }
        }
        
        // Reset the progress and reset threshold count
        self.progressValue = 0;
        self.thresholdCount = 0;
        
        // Clear the average red array
        [self.averageRed removeAllObjects];
    }
}
#endif

// Turns the torch on and off
- (void)setTorchOn:(BOOL)onOff {
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        [device setTorchMode: onOff ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
        [device unlockForConfiguration];
    }
}

// Smooth the data in averageRed using a moving average filter
- (void)performMovingAverageCalculation {
    NSMutableArray *tempAverageRed = [[NSMutableArray alloc] init];
    
    int half_window = MOVING_AVERAGE_WINDOW_SIZE/2;
    
    // Loop through the averageRed array and smooth the data
    for (int i = 0; i < [self.averageRed count]; i++) {
        double sum = 0;
        int count = 0;
        
        // Iterate through the window size and average of the window
        for (int j = i - half_window; j <= i + half_window; j++) {
            if (j >= 0 && j < [self.averageRed count]) {
                sum += [self.averageRed[j] doubleValue];
                count++;
            }
        }
        
        // Set the midpoint of the window to the calculated average value
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

// Returns the array of the specified number of highest peaks in averageRed
- (NSMutableArray*)findPeaks:(int)numPeaks {
    NSMutableArray *peaks = [[NSMutableArray alloc] init];
    
    // Iterate through averageRed and locate all the peaks
    for (int i = 0; i < [self.averageRed count] - PEAK_WINDOW_SIZE; i++) {
        // Find the index of the largest value inside the peak window
        int index = [self maxIndex:self.averageRed startIndex:i length:PEAK_WINDOW_SIZE];
        // If this index is the midpoint of the window, it's a peak
        if (index == i + (PEAK_WINDOW_SIZE - 1)/2) {
            // If the peaks array is currently full, replace the smallest value
            // in the array with this new peak
            // Otherwise, just add the peak to the array
            if ([peaks count] == numPeaks) {
                [self replaceSmallestValueInArrayWithValue:peaks value:self.averageRed[index]];
            } else {
                [peaks addObject:self.averageRed[index]];
            }
        }
    }
    
    return peaks;
}

// Replace the smallest value in the given array with the given value
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

// Calculate heart rate using the number of heart beats in a given time window
- (int)calculateHeartRate:(int)heartBeats
                  seconds:(int)seconds {
    return heartBeats * 60 / seconds;
}

@end
