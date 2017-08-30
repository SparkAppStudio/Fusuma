//
//  FSVideoCameraView.swift
//  Fusuma
//
//  Created by Brendan Kirchner on 3/18/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

class Recorder {

    struct Config {
        let FPS: Int
        let maxDuration: Double
    }

    var config: Recorder.Config = Config(FPS: 30, maxDuration: 8.0)

    let session: AVCaptureSession

    var device: AVCaptureDevice?

    var videoInput: AVCaptureDeviceInput!
    var videoOutput: AVCaptureMovieFileOutput!

    init() {
      session = AVCaptureSession()
    }

    func addInput(_ input: AVCaptureDeviceInput?) {
        guard let input = input else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }

    func addOutput(_ output: AVCaptureMovieFileOutput?) {
        guard let output = output else { return }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    func addBackCamera() throws {
        videoInput = try AVCaptureDeviceInput(device: device)
        addInput(videoInput)
    }

    func addFileOutput() {
        videoOutput = AVCaptureMovieFileOutput()

        let maxDuration = CMTimeMakeWithSeconds(config.maxDuration, Int32(config.FPS))
        videoOutput?.maxRecordedDuration = maxDuration
        videoOutput?.minFreeDiskSpaceLimit = 1024 * 1024 //SET MIN FREE SPACE IN BYTES FOR RECORDING TO CONTINUE ON A VOLUME

        addOutput(videoOutput)
    }

}

import UIKit
import AVFoundation

@objc protocol FSVideoCameraViewDelegate: class {
    func videoFinished(withFileURL fileURL: URL)
}

final class FSVideoCameraView: UIView {

    @IBOutlet weak var previewViewContainer: UIView!
    @IBOutlet weak var shotButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    
    weak var delegate: FSVideoCameraViewDelegate? = nil
    
    let recorder = Recorder()

    @available(*, deprecated)
    var session: AVCaptureSession! {
        return recorder.session
    }

    @available(*, deprecated)
    var device: AVCaptureDevice?

    @available(*, deprecated)
    var videoInput: AVCaptureDeviceInput?

    @available(*, deprecated)
    var videoOutput: AVCaptureMovieFileOutput?

    var focusView: UIView?
    
    var flashOffImage: UIImage?
    var flashOnImage: UIImage?
    var videoStartImage: UIImage?
    var videoStopImage: UIImage?

    let totalSeconds = 8.0 //Total Seconds of capture time

    var circleProgress: CAShapeLayer! = nil

    fileprivate var isRecording = false
    
    static func instance() -> FSVideoCameraView {
        return UINib(nibName: "FSVideoCameraView", bundle: Bundle(for: self.classForCoder())).instantiate(withOwner: self, options: nil)[0] as! FSVideoCameraView
    }

    func addprogressView(with frame: CGRect) {
        let insetFrame = frame.insetBy(dx: 10, dy: 10)
        circleProgress = CAShapeLayer()
        circleProgress.frame = insetFrame
        let insetSize = insetFrame.insetBy(dx: 5, dy: 5).size
        let insetRectForCircle = CGRect(origin: CGPoint(x:5, y:5), size: insetSize)
        circleProgress.path = UIBezierPath(ovalIn: insetRectForCircle).cgPath
        circleProgress.lineWidth = 10
        circleProgress.strokeColor = UIColor.lightGray.cgColor
        circleProgress.fillColor = UIColor.clear.cgColor
        circleProgress.lineCap = kCALineCapRound
        circleProgress.strokeStart = 0
        circleProgress.strokeEnd = 1.0 // initially fill the circle
    }

    func initialize() {

        self.backgroundColor = fusumaBackgroundColor
        
        self.isHidden = false
        
        // AVCapture
        recorder.device = getBackCamera()

        do {
            try recorder.addBackCamera()
            recorder.addFileOutput()

            let videoLayer = AVCaptureVideoPreviewLayer(session: recorder.session)
            videoLayer?.frame = self.previewViewContainer.bounds
            videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            self.previewViewContainer.layer.addSublayer(videoLayer!)

            addprogressView(with: videoLayer!.frame)
            videoLayer?.addSublayer(circleProgress)

            session.startRunning()
            
            // Focus View
            self.focusView         = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
            let tapRecognizer      = UITapGestureRecognizer(target: self, action: #selector(FSVideoCameraView.focus(_:)))
            self.previewViewContainer.addGestureRecognizer(tapRecognizer)
            
        } catch {
            
        }
        
        let bundle = Bundle(for: self.classForCoder)
        
        flashOnImage = fusumaFlashOnImage != nil ? fusumaFlashOnImage : UIImage(named: "ic_flash_on", in: bundle, compatibleWith: nil)
        flashOffImage = fusumaFlashOffImage != nil ? fusumaFlashOffImage : UIImage(named: "ic_flash_off", in: bundle, compatibleWith: nil)
        let flipImage = fusumaFlipImage != nil ? fusumaFlipImage : UIImage(named: "ic_loop", in: bundle, compatibleWith: nil)
        videoStartImage = fusumaVideoStartImage != nil ? fusumaVideoStartImage : UIImage(named: "ic_shutter", in: bundle, compatibleWith: nil)
        videoStopImage = fusumaVideoStopImage != nil ? fusumaVideoStopImage : UIImage(named: "ic_shutter_recording", in: bundle, compatibleWith: nil)
        
        flashButton.tintColor = fusumaBaseTintColor
        flipButton.tintColor  = fusumaBaseTintColor
        shotButton.tintColor  = fusumaBaseTintColor
        
        flashButton.setImage(flashOffImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        flipButton.setImage(flipImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        shotButton.setImage(videoStartImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        
        flashConfiguration()
        
        self.startCamera()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func startCamera() {
        
        let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if status == AVAuthorizationStatus.authorized {
            
            session?.startRunning()
            
        } else if status == AVAuthorizationStatus.denied ||
            status == AVAuthorizationStatus.restricted {
            
            session?.stopRunning()
        }
    }
    
    func stopCamera() {
        
        if self.isRecording {
            
            self.toggleRecording()
        }
        
        session?.stopRunning()
    }
    
    @IBAction func shotButtonPressed(_ sender: UIButton) {
        
        self.toggleRecording()
    }
    
    @IBAction func flipButtonPressed(_ sender: UIButton) {

        func removeCurrentInput() {
            for input in session.inputs {
                if let input = input as? AVCaptureInput {
                    session.removeInput(input)
                }
            }
        }

        func currentInputLocation() -> AVCaptureDevicePosition {
            return videoInput?.device.position == AVCaptureDevicePosition.front ? AVCaptureDevicePosition.back : AVCaptureDevicePosition.front
        }

        func addVideoInputForPosition(_ position: AVCaptureDevicePosition) {
            for device in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
                if let device = device as? AVCaptureDevice,
                    device.position == position {
                    if let videoInput = try? AVCaptureDeviceInput(device: device),
                        session.canAddInput(videoInput) {
                        session.addInput(videoInput)
                    }
                }
            }
        }

        guard let session = session else { return }
        session.stopRunning()
        session.beginConfiguration()
        removeCurrentInput()
        let position = currentInputLocation()
        addVideoInputForPosition(position)
        session.commitConfiguration()
        session.startRunning()
    }
    
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        
        do {
            
            guard let device = device else { return }
            
            try device.lockForConfiguration()
            
            let mode = device.flashMode
            
            switch mode {
            case .off:
                device.flashMode = AVCaptureFlashMode.on
                flashButton.setImage(flashOnImage, for: UIControlState())
            case .on:
                device.flashMode = AVCaptureFlashMode.off
                flashButton.setImage(flashOffImage, for: UIControlState())
            default:
                break
            }
            
            device.unlockForConfiguration()
        } catch _ {
            flashButton.setImage(flashOffImage, for: UIControlState())
            return
        }
    }

    func getBackCamera() -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            if let device = device as? AVCaptureDevice,
                device.position == AVCaptureDevicePosition.back {
                return device
            }
        }
        return nil
    }

}

extension FSVideoCameraView: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("started recording to: \(fileURL)")
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording to: \(outputFileURL)")
        self.delegate?.videoFinished(withFileURL: outputFileURL)
    }
}

fileprivate extension FSVideoCameraView {
    
    func toggleRecording() {
        guard let videoOutput = videoOutput else { return }
        self.isRecording = !self.isRecording

        let shotImage = self.isRecording ? videoStopImage : videoStartImage
        self.shotButton.setImage(shotImage, for: UIControlState())
        
        if self.isRecording {
            CATransaction.begin()
            CATransaction.setAnimationDuration(totalSeconds)
            circleProgress?.strokeEnd = 0.0
            CATransaction.commit()
            
            let outputPath = "\(NSTemporaryDirectory())output.mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputPath) {
                
                do {
                    try fileManager.removeItem(atPath: outputPath)
                } catch {
                    
                    print("error removing item at path: \(outputPath)")
                    self.isRecording = false
                    return
                }
            }
            
            self.flipButton.isEnabled = false
            self.flashButton.isEnabled = false
            videoOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
            
        } else {
            circleProgress?.strokeEnd = 1.0
            
            videoOutput.stopRecording()
            self.flipButton.isEnabled = true
            self.flashButton.isEnabled = true
        }
    }
    
    @objc func focus(_ recognizer: UITapGestureRecognizer) {
        
        let point    = recognizer.location(in: self)
        let viewsize = self.bounds.size
        let newPoint = CGPoint(x: point.y / viewsize.height, y: 1.0-point.x / viewsize.width)
        
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else {
            return
        }
        
        do {
            try device.lockForConfiguration()
        } catch _ {
            return
        }
        
        if device.isFocusModeSupported(AVCaptureFocusMode.autoFocus) == true {
            device.focusMode = AVCaptureFocusMode.autoFocus
            device.focusPointOfInterest = newPoint
        }
        
        if device.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure) == true {
            
            device.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            device.exposurePointOfInterest = newPoint
        }
        
        device.unlockForConfiguration()
        
        guard let focusView = focusView else { return }
        
        focusView.alpha  = 0.0
        focusView.center = point
        focusView.backgroundColor   = UIColor.clear
        focusView.layer.borderColor = UIColor.white.cgColor
        focusView.layer.borderWidth = 1.0
        focusView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        addSubview(focusView)
        
        UIView.animate(
            withDuration: 0.8,
            delay: 0.0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 3.0,
            options: UIViewAnimationOptions.curveEaseIn,
            animations: {
                
                focusView.alpha = 1.0
                focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        }, completion: {(finished) in
        
            focusView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            focusView.removeFromSuperview()
        })
    }
    
    func flashConfiguration() {
        
        do {
            guard let device = device else { return }
            try device.lockForConfiguration()
            device.flashMode = AVCaptureFlashMode.off
            flashButton.setImage(flashOffImage, for: UIControlState())
            device.unlockForConfiguration()
        } catch _ {
            return
        }
    }
}
