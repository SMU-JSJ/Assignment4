//  Team JSJ - Jordan Kayse, Jessica Yeh, Story Zanetti
//  FaceViewController.swift
//  JSJAssignment4
//
//  Created by ch484-mac7 on 3/5/15.
//  Copyright (c) 2015 SMU. All rights reserved.
//


import UIKit
import AVFoundation

class FaceViewController: UIViewController {
    
    var videoManager: VideoAnalgesic! = nil
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Do any additional setup after loading the view, typically from a nib.
        self.setupCameraAndFilters()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.videoManager.stop()
    }

    // A function to setup the video manager processing block
    // and to place filters on facial features
    func setupCameraAndFilters() {
        self.view.backgroundColor = nil
        
        if (self.videoManager == nil) {
            self.videoManager = VideoAnalgesic.sharedInstance
            self.videoManager.setCameraPosition(AVCaptureDevicePosition.Front)
        }
        
        // Setup the video manager processing block
        self.videoManager.setProcessingBlock( { (imageInput) -> (CIImage) in
            
            // Setup variables for detecting faces and facial features
            let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow]
            
            let detector = CIDetector(ofType: CIDetectorTypeFace,
                context: self.videoManager.getCIContext(),
                options: optsDetector)
            
            let optsFace = [CIDetectorImageOrientation:self.videoManager.getImageOrientationFromUIOrientation(UIApplication.sharedApplication().statusBarOrientation),CIDetectorSmile:true,CIDetectorEyeBlink:true]
            
            let features = detector.featuresInImage(imageInput, options: optsFace as? [String: AnyObject])
            var swappedPoint = CGPoint()
            
            var outputImage = imageInput
            var filter: CIFilter!
            
            // Iterate through all the faces detected and put filters
            for f in features as! [CIFaceFeature]{
                let faceRatio = f.bounds.size.height/15
                
                swappedPoint.x = f.bounds.midX
                swappedPoint.y = f.bounds.midY
                
                // If the face has a left eye
                if (f.hasLeftEyePosition) {
                    // If the left eye is blinking
                    if (f.leftEyeClosed) {
                        // Create the twirl filter
                        filter = CIFilter(name: "CITwirlDistortion")
                        filter.setValue(M_PI, forKey:"inputAngle")
                    } else {
                        // Create the hole distortion filter
                        filter = CIFilter(name: "CIHoleDistortion")
                    }
                    
                    // Apply left eye filters
                    filter.setValue(faceRatio + 5, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.leftEyePosition), forKey: "inputCenter")
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    
                    outputImage = filter.outputImage!
                }
                
                // If the face has a right eye
                if (f.hasRightEyePosition) {
                    // If the right eye is blinking
                    if (f.rightEyeClosed) {
                        // Create the twirl filter
                        filter = CIFilter(name: "CITwirlDistortion")
                        filter.setValue(M_PI, forKey:"inputAngle")
                    } else {
                        // Create the hole distortion filter
                        filter = CIFilter(name: "CIHoleDistortion")
                    }
                    
                    // Apply right eye filters
                    filter.setValue(faceRatio + 5, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.rightEyePosition), forKey: "inputCenter")
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    
                    outputImage = filter.outputImage!
                }
                
                // If the face has a mouth position
                if (f.hasMouthPosition) {
                    // Create the vortex filter
                    filter = CIFilter(name: "CIVortexDistortion")
                    filter.setValue(faceRatio + 20, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.mouthPosition), forKey: "inputCenter")
                    
                    // If the face has a smile
                    if (f.hasSmile) {
                        // Set a positive angle for the vortex for a smile
                        filter.setValue(56.55, forKey: "inputAngle")
                    } else {
                        // Reverse the angle for no smile
                        filter.setValue(-56.55, forKey: "inputAngle")
                    }
                    
                    // Apply the vortex filter
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    
                    outputImage = filter.outputImage!
                }
                
                // Create and place bump distortion for face
                filter = CIFilter(name: "CIBumpDistortion")
                filter.setValue(faceRatio + 50, forKey: "inputRadius")
                filter.setValue(0.75, forKey: "inputScale")
                filter.setValue(CIVector(CGPoint: swappedPoint), forKey: "inputCenter")
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                outputImage = filter.outputImage!
            }
            
            return outputImage
        })
        
        self.videoManager.start()
    }
    
    // When the switch camera button is clicked, toggle between front and
    // back cameras
    @IBAction func switchCameraClicked(sender: UIButton) {
        self.videoManager.toggleCameraPosition()
        self.setupCameraAndFilters()
    }
    
}


