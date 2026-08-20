import Foundation
import FirebaseDatabase
import FirebaseAuth

/// Wraps a Firebase Realtime Database observer so callers can cancel it
/// with the same `.remove()` call pattern used throughout the app.
final class DatabaseObserver {
    private let ref: DatabaseReference
    private let handle: DatabaseHandle

    init(ref: DatabaseReference, handle: DatabaseHandle) {
        self.ref = ref
        self.handle = handle
    }

    func remove() {
        ref.removeObserver(withHandle: handle)
    }
}

/// Handles all Realtime Database reads/writes for expenses.
///
/// Data lives at `users/{uid}/expenses/{expenseId}`.
/// Each user's data is isolated under their own uid node, so one user
/// can never read or write another user's expenses.
final class DatabaseService {

    static let shared = DatabaseService()
    private init() {}

    private var db: DatabaseReference { Database.database().reference() }

    private var expensesRef: DatabaseReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.child("users").child(uid).child("expenses")
    }

    // MARK: - Create

    func addExpense(_ expense: Expense, completion: @escaping (Result<String, Error>) -> Void) {
        guard let ref = expensesRef else {
            completion(.failure(DatabaseServiceError.notAuthenticated))
            return
        }
        let newRef = ref.childByAutoId()
        guard let id = newRef.key else {
            completion(.failure(DatabaseServiceError.unknown))
            return
        }
        newRef.setValue(expense.asDictionary()) { error, _ in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(id))
            }
        }
    }

    // MARK: - Read (one-time)

    func fetchExpenses(completion: @escaping (Result<[Expense], Error>) -> Void) {
        guard let ref = expensesRef else {
            completion(.failure(DatabaseServiceError.notAuthenticated))
            return
        }
        ref.observeSingleEvent(of: .value) { snapshot in
            let expenses = Self.parseExpenses(from: snapshot)
            completion(.success(expenses))
        } withCancel: { error in
            completion(.failure(error))
        }
    }

    // MARK: - Read (live updates)

    @discardableResult
    func observeExpenses(onChange: @escaping (Result<[Expense], Error>) -> Void) -> DatabaseObserver? {
        guard let ref = expensesRef else {
            onChange(.failure(DatabaseServiceError.notAuthenticated))
            return nil
        }
        let handle = ref.observe(.value) { snapshot in
            let expenses = Self.parseExpenses(from: snapshot)
            onChange(.success(expenses))
        } withCancel: { error in
            onChange(.failure(error))
        }
        return DatabaseObserver(ref: ref, handle: handle)
    }

    // MARK: - Update

    func updateExpense(_ expense: Expense, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ref = expensesRef, let id = expense.id else {
            completion(.failure(DatabaseServiceError.missingId))
            return
        }
        ref.child(id).setValue(expense.asDictionary()) { error, _ in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Delete

    func deleteExpense(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ref = expensesRef else {
            completion(.failure(DatabaseServiceError.notAuthenticated))
            return
        }
        ref.child(id).removeValue { error, _ in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Helpers

    private static func parseExpenses(from snapshot: DataSnapshot) -> [Expense] {
        var expenses: [Expense] = []
        for child in snapshot.children {
            guard let snap = child as? DataSnapshot,
                  let expense = Expense.from(snapshot: snap) else { continue }
            expenses.append(expense)
        }
        return expenses.sorted { $0.date > $1.date }
    }
}

enum DatabaseServiceError: LocalizedError {
    case notAuthenticated
    case missingId
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You need to be signed in to do that."
        case .missingId: return "This expense hasn't been saved yet, so it can't be updated."
        case .unknown: return "Something went wrong. Please try again."
        }
    }
}
