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

#define COLOR_THRESHOLD 30

@interface ViewController () <CvVideoCameraDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *torchButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;

@property (strong, nonatomic) CvVideoCameraMod *videoCamera;
@property (nonatomic) BOOL torchIsOn;

@property (strong, nonatomic) NSMutableArray *averageRed;
@property (strong, nonatomic) NSMutableArray *averageGreen;
@property (strong, nonatomic) NSMutableArray *averageBlue;

@property (nonatomic) int count;

@end

@implementation ViewController

- (NSMutableArray*)averageRed {
    if (!_averageRed) {
        _averageRed = [[NSMutableArray alloc] init];
    }
    return _averageRed;
}

- (NSMutableArray*)averageGreen {
    if (!_averageGreen) {
        _averageGreen = [[NSMutableArray alloc] init];
    }
    return _averageGreen;
}

- (NSMutableArray*)averageBlue {
    if (!_averageBlue) {
        _averageBlue = [[NSMutableArray alloc] init];
    }
    return _averageBlue;
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
    
    //============================================
    // color inverter
    //    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    //
    //    // invert image
    //    bitwise_not(image_copy, image_copy);
    //    // copy back for further processing
    //    cvtColor(image_copy, image, CV_BGR2BGRA); //add back for display
    
    //============================================
    //access pixels
    //    static uint counter = 0;
    //    cvtColor(image, image_copy, CV_BGRA2BGR);
    //    for(int i=0;i<counter;i++){
    //        for(int j=0;j<counter;j++){
    //            uchar *pt = image_copy.ptr(i, j);
    //            pt[0] = 255;
    //            pt[1] = 0;
    //            pt[2] = 255;
    //
    //            pt[3] = 255;
    //            pt[4] = 0;
    //            pt[5] = 0;
    //        }
    //    }
    //    cvtColor(image_copy, image, CV_BGR2BGRA);
    //
    //    counter++;
    //    counter = counter>200 ? 0 : counter;
    
    //============================================
    // get average pixel intensity
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    Scalar avgPixelIntensity = cv::mean( image_copy );
    char text[50];
    sprintf(text,"Avg. B: %.1f, G: %.1f, R: %.1f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
    cv::putText(image, text, cv::Point(10, 20), FONT_HERSHEY_PLAIN, 1, Scalar::all(255), 1,2);
    
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
            [self.averageGreen addObject:[NSNumber numberWithFloat:green]];
            [self.averageBlue addObject:[NSNumber numberWithFloat:blue]];
        }
        if ([self.averageRed count] >= 300) {
            NSLog(@"%@", self.averageRed);
            [self.averageRed removeAllObjects];
            [self.averageGreen removeAllObjects];
            [self.averageBlue removeAllObjects];
            self.count = 0;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.torchButton.enabled = NO;
            self.switchCameraButton.enabled = NO;
        });
    } else {
        self.count = 0;
        [self.averageRed removeAllObjects];
        [self.averageGreen removeAllObjects];
        [self.averageBlue removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.videoCamera.defaultAVCaptureDevicePosition != AVCaptureDevicePositionFront) {
                self.torchButton.enabled = YES;
            }
            self.switchCameraButton.enabled = YES;
        });
    }
    
    
    //============================================
    // change the hue inside an image
    
    //convert to HSV
    //    cvtColor(image, image_copy, CV_BGRA2BGR);
    //    cvtColor(image_copy, image_copy, CV_BGR2HSV);
    //
    //    //grab  just the Hue chanel
    //    vector<Mat> layers;
    //    cv::split(image_copy,layers);
    //
    //    // shift the colors
    //    cv::add(layers[0],80.0,layers[0]);
    //
    //    // get back image from separated layers
    //    cv::merge(layers,image_copy);
    //
    //    cvtColor(image_copy, image_copy, CV_HSV2BGR);
    //    cvtColor(image_copy, image, CV_BGR2BGRA);
}
#endif

- (IBAction)toggleTorch:(id)sender {
    // you will need to fix the problem of video stopping when the torch is applied in this method
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


@end
