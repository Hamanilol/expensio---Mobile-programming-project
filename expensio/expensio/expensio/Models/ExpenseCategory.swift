import UIKit

/// UIKit-specific appearance for ExpenseCategory, kept in its own file so the
/// core Expense/ExpenseCategory model (Models/Expense.swift) stays UIKit-free.
extension ExpenseCategory {
    var accentColor: UIColor {
        switch self {
        case .food: return UIColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1)
        case .transport: return UIColor(red: 0.243, green: 0.427, blue: 0.71, alpha: 1)
        case .bills: return UIColor(red: 0.459, green: 0.384, blue: 0.714, alpha: 1)
        case .shopping: return UIColor(red: 0.9, green: 0.35, blue: 0.6, alpha: 1)
        case .health: return UIColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1)
        case .other: return UIColor(red: 0.6, green: 0.63, blue: 0.68, alpha: 1)
        }
    }
}
