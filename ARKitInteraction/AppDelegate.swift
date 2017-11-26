/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Application's delegate.
*/

import UIKit
import ARKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        //仅在兼容的设备上提供AR功能。示例应用程序需要ARKit的核心功能，需在项目的Info.plist文件中设置UIRequiredDeviceCapabilities - arkit键值对。部署内建项目时，此键可防止在不支持ARKit的设备上安装应用程序。若app仅将AR作为次要功能，请使用isSupported方法来确定是否隐藏需要ARKit的功能。
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }

        return true
    }
}
