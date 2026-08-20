import Foundation
import FirebaseAuth

/// Wraps Firebase Authentication (email/password) for the app.
///
/// Session persistence: FirebaseAuth already persists the signed-in user
/// across launches on its own (via Keychain), but the assessment brief
/// explicitly requires session state to be kept using UserDefaults, so we
/// mirror a lightweight "isLoggedIn" flag + the user's uid/email there.
/// SceneDelegate/AppDelegate checks that flag at launch to decide whether to
/// show LoginViewController or jump straight to the tab bar.
final class AuthService {

    static let shared = AuthService()
    private init() {}

    private let defaults = UserDefaults.standard

    private enum DefaultsKey {
        static let isLoggedIn = "expensio_isLoggedIn"
        static let userId = "expensio_userId"
        static let userEmail = "expensio_userEmail"
    }

    // MARK: - Session state (UserDefaults-backed, per brief requirement)

    /// Whether a user should be considered logged in at app launch.
    /// Checked by SceneDelegate to pick the initial view controller.
    var isLoggedIn: Bool {
        defaults.bool(forKey: DefaultsKey.isLoggedIn)
    }

    /// The current user's Firestore/Auth uid, used to scope all
    /// Firestore reads/writes to `users/{uid}/expenses/...`.
    var currentUserId: String? {
        defaults.string(forKey: DefaultsKey.userId)
    }

    var currentUserEmail: String? {
        defaults.string(forKey: DefaultsKey.userEmail)
    }

    private func persistSession(for user: User) {
        defaults.set(true, forKey: DefaultsKey.isLoggedIn)
        defaults.set(user.uid, forKey: DefaultsKey.userId)
        defaults.set(user.email, forKey: DefaultsKey.userEmail)
    }

    private func clearSession() {
        defaults.removeObject(forKey: DefaultsKey.isLoggedIn)
        defaults.removeObject(forKey: DefaultsKey.userId)
        defaults.removeObject(forKey: DefaultsKey.userEmail)
    }

    // MARK: - Sign up

    func signUp(fullName: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(AuthServiceError.unknown))
                return
            }

            // Attach the display name so it's available without a separate Firestore read.
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            changeRequest.commitChanges { _ in
                self?.persistSession(for: user)
                completion(.success(()))
            }
        }
    }

    // MARK: - Sign in

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(AuthServiceError.unknown))
                return
            }
            self?.persistSession(for: user)
            completion(.success(()))
        }
    }

    // MARK: - Sign out

    func signOut() throws {
        try Auth.auth().signOut()
        clearSession()
    }
}

enum AuthServiceError: LocalizedError {
    case unknown

    var errorDescription: String? {
        switch self {
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
