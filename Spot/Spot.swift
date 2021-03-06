//
//  Spot.swift
//  Spot
//
//  Created by Daniel Leivers on 20/11/2016.
//  Copyright © 2016 Daniel Leivers. All rights reserved.
//

import UIKit

extension UIWindow {
    open override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if Spot.sharedInstance.handling {
            Spot.launchFlow()
        }
    }
}

@objc public class Spot: NSObject {
    
    static let sharedInstance = Spot()
    var handling: Bool = false
    
    public static func start() {
        sharedInstance.handling = true
    }
    
    public static func stop() {
        sharedInstance.handling = false
    }
    
    static func launchFlow() {
        if let screenshot = captureScreen() {
            loadViewControllers(withScreenshot: screenshot)
        }
    }
    
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
