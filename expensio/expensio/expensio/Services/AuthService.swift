import Foundation
import FirebaseAuth

// Wraps Firebase Authentication for the whole app.
// Session state is mirrored into UserDefaults so returning users skip login.
final class AuthService {

    static let shared = AuthService()
    private init() {}

    private let defaults = UserDefaults.standard

    private enum DefaultsKey {
        static let isLoggedIn = "expensio_isLoggedIn"
        static let userId = "expensio_userId"
        static let userEmail = "expensio_userEmail"
    }

    // MARK: - Session state

    var isLoggedIn: Bool {
        defaults.bool(forKey: DefaultsKey.isLoggedIn)
    }

    var currentUserId: String? {
        defaults.string(forKey: DefaultsKey.userId)
    }

    var currentUserEmail: String? {
        defaults.string(forKey: DefaultsKey.userEmail)
    }

    // Saves the signed-in user's session to UserDefaults.
    private func persistSession(for user: User) {
        defaults.set(true, forKey: DefaultsKey.isLoggedIn)
        defaults.set(user.uid, forKey: DefaultsKey.userId)
        defaults.set(user.email, forKey: DefaultsKey.userEmail)
    }

    // Wipes the saved session on logout.
    private func clearSession() {
        defaults.removeObject(forKey: DefaultsKey.isLoggedIn)
        defaults.removeObject(forKey: DefaultsKey.userId)
        defaults.removeObject(forKey: DefaultsKey.userEmail)
    }

    // MARK: - Sign up

    func signUp(fullName: String, email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Create the Firebase Auth user.
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(AuthServiceError.unknown))
                return
            }

            // Attach the display name, then persist the session.
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
        // Sign in, then persist the session on success.
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
