import Flutter
import UIKit

/// Flutter's own scene delegate plus the hook for shared files.
///
/// Info.plist declares a UIApplicationSceneManifest, so UIKit routes
/// opened URLs to the scene rather than to AppDelegate's
/// `application(_:open:options:)` - that method is never called here.
/// Named in Info.plist as `$(PRODUCT_MODULE_NAME).SceneDelegate`.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // A share that launched the app from cold arrives here.
    IncomingFiles.shared.absorb(connectionOptions.urlContexts)
  }

  override func scene(
    _ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    // A share into the app while it was already running.
    IncomingFiles.shared.absorb(URLContexts)
  }
}
