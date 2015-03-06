//
//  CvVideoCameraMod.h
//  OpenCVObjC
//
//  Created by Eric Larson on 2/25/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <opencv2/highgui/cap_ios.h>

@protocol CvVideoCameraDelegateMod <CvVideoCameraDelegate>
@end

@interface CvVideoCameraMod : CvVideoCamera

//@property (nonatomic, retain) CALayer *customPreviewLayer;
- (void)updateOrientation;
- (void)layoutPreviewLayer;

@end
