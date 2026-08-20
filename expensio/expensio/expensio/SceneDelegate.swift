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

    /// Skips straight to the tab bar if the user is already logged in.
    private func initialViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if AuthService.shared.isLoggedIn {
            return storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
        } else {
            return storyboard.instantiateInitialViewController()!
        }
    }
}
