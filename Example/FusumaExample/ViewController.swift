//
//  ViewController.swift
//  Fusuma
//
//  Created by ytakzk on 01/31/2016.
//  Copyright (c) 2016 ytakzk. All rights reserved.
//

import UIKit
import AVFoundation

class PreviewView: UIView {

    lazy var playerItem: AVPlayerItem = AVPlayerItem(url: self.videoURL!)
    lazy var player: AVQueuePlayer = AVQueuePlayer(items: [self.playerItem])
    lazy var looper: AVPlayerLooper = AVPlayerLooper(player: self.player, templateItem: self.playerItem)
    lazy var playerLayer: AVPlayerLayer =  AVPlayerLayer(player: self.player)

    var image: UIImage? {
        didSet {
            if image != nil {
                videoURL = nil
                displayImage()
            } else {
                hideImageDisplay()
            }
        }
    }

    var videoURL: URL? {
        didSet {
            if videoURL != nil {
                image = nil
                showVideoPreview()
            } else {
                hideVideoDisplay()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }

    func sharedInit() {
        backgroundColor = .blue
    }

    func displayImage() {
        layer.contents = image?.cgImage
    }

    func hideImageDisplay() {
        layer.contents = nil
    }

    func showVideoPreview() {
        playerLayer.frame = self.bounds
        layer.addSublayer(playerLayer)
        player.play()
    }

    func hideVideoDisplay() {
        if let sublayers = layer.sublayers, sublayers.count > 0 {
            playerLayer.removeFromSuperlayer()
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: PreviewView!
    
    @IBOutlet weak var showButton: UIButton!
    
    @IBOutlet weak var fileUrlLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        showButton.layer.cornerRadius = 2.0
        self.fileUrlLabel.text = ""
    }

    @IBAction func showButtonPressed(_ sender: AnyObject) {
        
        // Show Fusuma
        let fusuma = FusumaViewController()
        
        fusuma.delegate = self
        fusuma.cropHeightRatio = 1.0
        fusuma.allowMultipleSelection = true
        fusuma.availableModes = [.library, .camera, .video]
        fusumaSavesImage = true

        present(fusuma, animated: true, completion: nil)
    }
}

extension ViewController: FusumaDelegate {

    func fusumaImageSelected(_ image: UIImage, source: FusumaMode) {
        switch source {
        case .camera:
            print("Image captured from Camera")
        case .library:
            print("Image selected from Camera Roll")
        case .video:
            print("Video captured")
        }
        previewView.image = image
    }

    func fusumaMultipleImageSelected(_ images: [UIImage], source: FusumaMode) {
        print("Number of selection images: \(images.count)")
        var count: Double = 0
        for image in images {
            DispatchQueue.main.asyncAfter(deadline: .now() + (3.0 * count)) {
                self.previewView.image = image
                print("w: \(image.size.width) - h: \(image.size.height)")
            }
            count += 1
        }
    }

    func fusumaVideoCompleted(withFileURL fileURL: URL) {
        print("video completed and output to file: \(fileURL)")
        self.fileUrlLabel.text = "file output to: \(fileURL.absoluteString)"
        previewView.videoURL = fileURL
    }

    func fusumaCameraRollUnauthorized() {
        print("Camera roll unauthorized")
        let alert = UIAlertController(title: "Access Requested",
                                      message: "Saving image needs to access your photo album",
                                      preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            _ = URL(string:UIApplicationOpenSettingsURLString).map(UIApplication.shared.openURL)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alert.addAction(settingsAction)
        alert.addAction(cancelAction)

        guard let vc = UIApplication.shared.delegate?.window??.rootViewController,
            let presented = vc.presentedViewController else {
                return
        }
        presented.present(alert, animated: true, completion: nil)
    }

    // Optional
    func fusumaImageSelected(_ image: UIImage, source: FusumaMode, metaData: ImageMetadata) {
        print("Image mediatype: \(metaData.mediaType)")
        print("Source image size: \(metaData.pixelWidth)x\(metaData.pixelHeight)")
        print("Creation date: \(String(describing: metaData.creationDate))")
        print("Modification date: \(String(describing: metaData.modificationDate))")
        print("Video duration: \(metaData.duration)")
        print("Is favourite: \(metaData.isFavourite)")
        print("Is hidden: \(metaData.isHidden)")
        print("Location: \(String(describing: metaData.location))")
    }

    func fusumaDismissedWithImage(_ image: UIImage, source: FusumaMode) {
        switch source {
        case .camera:
            print("Called just after dismissed FusumaViewController using Camera")
        case .library:
            print("Called just after dismissed FusumaViewController using Camera Roll")
        case .video:
            print("Called just after dismissed FusumaViewController")
        }
    }

    func fusumaClosed() {
        print("Called when the FusumaViewController disappeared")
    }

    func fusumaWillClosed() {
        print("Called when the close button is pressed")
    }

}
