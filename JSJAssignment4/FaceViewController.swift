//
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
        self.view.backgroundColor = nil
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(AVCaptureDevicePosition.Front)
        
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow]
        
        let detector = CIDetector(ofType: CIDetectorTypeFace,
            context: self.videoManager.getCIContext(),
            options: optsDetector)
        
        var optsFace = [CIDetectorImageOrientation:self.videoManager.getImageOrientationFromUIOrientation(UIApplication.sharedApplication().statusBarOrientation),CIDetectorSmile:true,CIDetectorEyeBlink:true]
        
        self.videoManager.setProcessingBlock( { (imageInput) -> (CIImage) in
            
            var features = detector.featuresInImage(imageInput, options: optsFace)
            var swappedPoint = CGPoint()
            
            var outputImage = imageInput
            var filter: CIFilter
            for f in features as [CIFaceFeature]{
                let faceRatio = f.bounds.size.height/15
                
                swappedPoint.x = f.bounds.midX
                swappedPoint.y = f.bounds.midY
                filter = CIFilter(name: "CIBumpDistortion")
                filter.setValue(faceRatio + 50, forKey: "inputRadius")
                filter.setValue(0.5, forKey: "inputScale")
                filter.setValue(CIVector(CGPoint: swappedPoint), forKey: "inputCenter")
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                outputImage = filter.outputImage
                
                // If the face has a left eye, apply the hole filter
                if (f.hasLeftEyePosition) {
                    
                    // If the left eye is blinking
                    if (f.leftEyeClosed) {
                        filter = CIFilter(name: "CITwirlDistortion")
                        
                        filter.setValue(M_PI, forKey:"inputAngle")
                    } else {
                        filter = CIFilter(name: "CIHoleDistortion")
                    }
                    
                    filter.setValue(faceRatio + 5, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.leftEyePosition), forKey: "inputCenter")
                    
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    outputImage = filter.outputImage
                }
                
                // If the face has a right eye, apply the hole filter
                if (f.hasRightEyePosition) {
                    
                    // If the right eye is blinking
                    if (f.rightEyeClosed) {
                        filter = CIFilter(name: "CITwirlDistortion")
                        
                        filter.setValue(M_PI, forKey:"inputAngle")
                    } else {
                        filter = CIFilter(name: "CIHoleDistortion")
                    }
                    
                    filter.setValue(faceRatio + 5, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.rightEyePosition), forKey: "inputCenter")
                    
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    outputImage = filter.outputImage
                }
                
                // If the face has a mouth position, apply the vortex filter
                if (f.hasMouthPosition) {
                    filter = CIFilter(name: "CIVortexDistortion")
                    filter.setValue(faceRatio + 20, forKey: "inputRadius")
                    filter.setValue(CIVector(CGPoint: f.mouthPosition), forKey: "inputCenter")
                    
                    // If the face has a smile, reverse the vortex angle
                    if (f.hasSmile) {
                        filter.setValue(56.55, forKey: "inputAngle")
                    } else {
                        filter.setValue(-56.55, forKey: "inputAngle")
                    }
                    
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    outputImage = filter.outputImage
                }
                
                
            }
            
            return outputImage
        })
        
        self.videoManager.start()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.videoManager.stop()
    }
    
    @IBAction func switchCameraClicked(sender: UIButton) {
        self.videoManager.toggleCameraPosition()
    }
    
}


