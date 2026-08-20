import Foundation
import FirebaseDatabase

// Fixed expense categories.
enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case bills = "Bills"
    case shopping = "Shopping"
    case health = "Health"
    case other = "Other"

    // SF Symbol shown for this category.
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

// A single expense. Stored at users/{uid}/expenses/{id} in Realtime Database.
struct Expense: Codable, Identifiable {
    var id: String?
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var receiptImageURL: String?
    var createdAt: Date?

    // MARK: - Realtime Database conversion

    // Converts to a dictionary for setValue(_:). Dates stored as Unix timestamps.
    func asDictionary() -> [String: Any] {
        // Required fields.
        var dict: [String: Any] = [
            "title": title,
            "amount": amount,
            "category": category.rawValue,
            "date": date.timeIntervalSince1970,
            "createdAt": createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        ]
        // Optional receipt URL.
        if let receiptImageURL {
            dict["receiptImageURL"] = receiptImageURL
        }
        return dict
    }

    // Builds an Expense from a database snapshot. Returns nil if a required field is missing.
    static func from(snapshot: DataSnapshot) -> Expense? {
        // Unwrap required fields; bail out if anything's missing or the wrong type.
        guard
            let data = snapshot.value as? [String: Any],
            let title = data["title"] as? String,
            let amount = data["amount"] as? Double,
            let categoryRaw = data["category"] as? String,
            let category = ExpenseCategory(rawValue: categoryRaw),
            let dateInterval = data["date"] as? Double
        else { return nil }

        // Optional fields.
        let receiptImageURL = data["receiptImageURL"] as? String
        let createdAtInterval = data["createdAt"] as? Double

        // Build the Expense, using the snapshot's key as the id.
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
