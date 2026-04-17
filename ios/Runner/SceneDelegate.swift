import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      SolarCompanionCenter.shared.configure(with: flutterViewController.binaryMessenger)
    }

    if let context = connectionOptions.urlContexts.first {
      SolarCompanionCenter.shared.handleIncomingCompanionURL(context.url)
    }

    if let activity = connectionOptions.userActivities.first,
      let webpageURL = activity.webpageURL
    {
      SolarCompanionCenter.shared.handleIncomingCompanionURL(webpageURL)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      SolarCompanionCenter.shared.handleIncomingCompanionURL(context.url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    if let webpageURL = userActivity.webpageURL {
      SolarCompanionCenter.shared.handleIncomingCompanionURL(webpageURL)
    }
  }
}
