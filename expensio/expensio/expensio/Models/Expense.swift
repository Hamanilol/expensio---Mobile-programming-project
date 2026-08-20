import Foundation
import FirebaseDatabase

/// The fixed category set required by the assessment brief.
enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case bills = "Bills"
    case shopping = "Shopping"
    case health = "Health"
    case other = "Other"

    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "bus"
        case .bills: return "bolt.fill"
        case .shopping: return "bag.fill"
        case .health: return "heart.fill"
        case .other: return "ellipsis"
        }
    }
}

/// Model representing a single expense.
///
/// Realtime Database node shape (at `users/{uid}/expenses/{id}`):
/// ```
/// {
///   "title": "Blue Bottle Coffee",
///   "amount": 14.50,
///   "category": "Food",
///   "date": 1753000000.0,       // Unix timestamp (seconds)
///   "receiptImageURL": "https://res.cloudinary.com/.../receipt.jpg",
///   "createdAt": 1753000000.0   // Unix timestamp (seconds)
/// }
/// ```
struct Expense: Codable, Identifiable {
    var id: String?
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var receiptImageURL: String?
    var createdAt: Date?

    // MARK: - Realtime Database conversion

    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "amount": amount,
            "category": category.rawValue,
            "date": date.timeIntervalSince1970,
            "createdAt": createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        ]
        if let receiptImageURL {
            dict["receiptImageURL"] = receiptImageURL
        }
        return dict
    }

    /// Builds an Expense from a Realtime Database DataSnapshot.
    /// Returns nil if required fields are missing/malformed.
    static func from(snapshot: DataSnapshot) -> Expense? {
        guard
            let data = snapshot.value as? [String: Any],
            let title = data["title"] as? String,
            let amount = data["amount"] as? Double,
            let categoryRaw = data["category"] as? String,
            let category = ExpenseCategory(rawValue: categoryRaw),
            let dateInterval = data["date"] as? Double
        else { return nil }

        let receiptImageURL = data["receiptImageURL"] as? String
        let createdAtInterval = data["createdAt"] as? Double

        return Expense(
            id: snapshot.key,
            title: title,
            amount: amount,
            category: category,
            date: Date(timeIntervalSince1970: dateInterval),
            receiptImageURL: receiptImageURL,
            createdAt: createdAtInterval.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
