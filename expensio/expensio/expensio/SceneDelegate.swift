import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = initialViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    /// Decides the app's starting screen based on the persisted session
    /// (see AuthService — the "isLoggedIn" flag lives in UserDefaults per
    /// the assessment brief, so returning users skip the login screen).
    private func initialViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if AuthService.shared.isLoggedIn {
            // "MainTabBarController" matches the Storyboard ID set on the
            // UITabBarController scene in Main.storyboard.
            return storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
        } else {
            // Falls back to the storyboard's own initial view controller (Login).
            return storyboard.instantiateInitialViewController()!
        }
    }
}
