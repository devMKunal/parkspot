import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set MAPS_API_KEY in ios/Flutter/Secrets.xcconfig (git-ignored).
    // Without any key the SDK aborts when the map opens, so a missing key
    // falls back to a placeholder: the app runs and the tiles stay blank.
    let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    if key.isEmpty {
      NSLog("MAPS_API_KEY is not set in ios/Flutter/Secrets.xcconfig; the map will be blank.")
    }
    GMSServices.provideAPIKey(key.isEmpty ? "MISSING_MAPS_API_KEY" : key)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
