//
//  Spot.swift
//  Spot
//
//  Originally Created by Daniel Leivers on 20/11/2016.
//  Copyright © 2016 Daniel Leivers. All rights reserved.
//

//  Extended by Alex Layton and Daniele Pietrobelli

import UIKit
import Foundation

struct SpotData {
    var appName : String
    var deviceAppInfo : String
    var combinedImageData : Data
    var screenshotData : Data
}

// ??? REST API for Firebase, AWS and Google cloud 

// MARK: Generic CloudHandler

class CloudHandler {
    required init() {}
    func upload(_ spotData : SpotData) {
        fatalError("Default CloudHandler used. Use subclass instead!")
    }
    
    func connect() {
        fatalError("Default CloudHandler used. Use subclass instead!")
    }
    
    func disconnect() {
        fatalError("Default CloudHandler used. Use subclass instead!")
    }
    
    func configuration() {
        fatalError("Default CloudHandler used. Use subclass instead!")
    }
}

// MARK: FirebaseHandler

// https://firebase.google.com/docs/reference/rest/database/
// https://firebase.google.com/docs/database/rest/start


// !!
// https://firebase.google.com/docs/storage/gcp-integration

class FirebaseHandler: CloudHandler {
    
    // Get a reference to the storage service using the default Firebase App
    let storage = FIRStorage.storage()
    // Create a storage reference from our storage service
    var storageRef : FIRStorageReference?

    required init() {
        print("FirebaseHandler init")
        super.init()
    } 
    
    override func configuration() {
        FIRApp.configure()
        self.storageRef = storage.reference()
    }
    
    override func upload(_ spotData : SpotData) {
        guard storageRef != nil else {
            print("incorrect initilisation")
            return
        }
        
        // Create a reference to the file you want to upload
        let riversRef = storageRef!.child(spotData.deviceAppInfo)
        
        // Upload the file to the path "images/rivers.jpg"
        let uploadTask = riversRef.put(spotData.screenshotData, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                // Uh-oh, an error occurred!
                print("Error occurred")
                return
            }
            // Metadata contains file metadata such as size, content-type, and download URL.
            let downloadURL = metadata.downloadURL
        }
    }
    
    override func connect() {}
    override func disconnect() {}
}

// MARK: AwsHandler 

// http://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html

class AwsHandler: CloudHandler {
    override func upload(_ spotData : SpotData) {}
    override func connect() {}
    override func disconnect() {}
}

// MARK: Google cloud 

// https://cloud.google.com/storage/docs/json_api/

class GoogleHandler: CloudHandler {
    override func upload(_ spotData : SpotData) {}
    override func connect() {}
    override func disconnect() {}
}

// MARK: Specific handlers

extension UIWindow {
    open override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if Spot.sharedInstance.handling {
            Spot.launchFlow()
        }
    }
}

@objc public class Spot: NSObject {
    
    // Should read this from an info.plist file
    static let sharedInstance = Spot(type: FirebaseHandler.self)

    var handling: Bool = false
    let cloudHandler: CloudHandler

    // MARK: CloudHandler implementation 
    
    init<T: CloudHandler>(type: T.Type) {
        print("inside init ...")
        cloudHandler = type.init()
        print("about to terminate init ...")
    }
    
    // MARK: Spot original methods
    
    private func cloudSetup() {
        // Do setup
        cloudHandler.connect()
    }
    
    func takeScreenshotAndUpload(spotData : SpotData) {
        // Take screenshot
        cloudHandler.upload(spotData)
    }
    
    public static func start() {
        FIRApp.configure()
        // May need to deal with a callback
        sharedInstance.handling = true
    }
    
    func configure() {
        self.cloudHandler.configuration()
        self.cloudHandler.connect() // May be better with a callback after configuration
    }
    
    public static func stop() {
        sharedInstance.handling = false
        sharedInstance.cloudHandler.disconnect()
    }
    
    static func launchFlow() {
        if let screenshot = captureScreen() {
            loadViewControllers(withScreenshot: screenshot)
        }
    }
    
    // MARK: Internal methods
    
    static func captureScreen() -> UIImage? {
        var screenshot: UIImage?
        let screenRect = UIScreen.main.bounds
        UIGraphicsBeginImageContextWithOptions(screenRect.size, false, UIScreen.main.scale)
        if let context = UIGraphicsGetCurrentContext() {
            UIColor.black.set()
            context.fill(screenRect);
            let window = UIApplication.shared.keyWindow
            window?.layer.render(in: context)
            screenshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        
        return screenshot
    }
    
    static func loadViewControllers(withScreenshot screenshot: UIImage) {
        // Handle pod bundle (if installed via 'pod install') or local for example
        var storyboard: UIStoryboard
        let podBundle = Bundle(for: self.classForCoder())
        if let bundleURL = podBundle.url(forResource: "Spot", withExtension: "bundle") {
            guard let bundle = Bundle(url: bundleURL) else { return }
            storyboard = UIStoryboard.init(name: "Spot", bundle: bundle)
        }
        else {
            storyboard = UIStoryboard.init(name: "Spot", bundle: nil)
        }
        
        if let initialViewController = storyboard.instantiateInitialViewController() as? OrientationLockNavigationController {
            initialViewController.orientationToLock = UIDevice.current.orientation
            let window = UIApplication.shared.keyWindow
            window?.rootViewController?.present(initialViewController, animated: true, completion: nil)
            if let screenshotViewController = initialViewController.topViewController as? SpotViewController {
                screenshotViewController.screenshot = screenshot
            }
        }
    }
    
    static func combine(bottom bottomImage: UIImage, with topImage: UIImage) -> UIImage? {
        var combinedImage: UIImage?
        UIGraphicsBeginImageContextWithOptions(bottomImage.size, false, 0.0)
        
        bottomImage.draw(in: CGRect.init(x: 0, y: 0, width: topImage.size.width, height: topImage.size.height))
        topImage.draw(in: CGRect.init(x: 0, y: 0, width: bottomImage.size.width, height: bottomImage.size.height))
        
        combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return combinedImage
    }
    
    static func modelName() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    static func deviceAppInfo() -> String {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        let bundleName = appName()
        
        var bodyText = "Bundle name: \(bundleName)\nVersion: \(versionNumber)\nBuild: \(buildNumber)\n"
        if let modelName = Spot.modelName() {
            bodyText += "Device: \(modelName)"
        }
        
        return bodyText
    }
    
    static func appName() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }
}
