import UIKit

class ExpenseTableViewCell: UITableViewCell {

    @IBOutlet weak var iconContainerView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var categoryBadgeView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var receiptIconImageView: UIImageView!

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    // Fills the cell's labels, icon, and colors from one expense.
    func configure(with expense: Expense) {
        // Text fields.
        titleLabel.text = expense.title
        categoryLabel.text = expense.category.rawValue
        dateLabel.text = Self.dateFormatter.string(from: expense.date)
        amountLabel.text = String(format: "$%.2f", expense.amount)

        // Category color and icon.
        let color = expense.category.accentColor
        iconImageView.image = UIImage(systemName: expense.category.iconName)
        iconImageView.tintColor = color
        iconContainerView.backgroundColor = color.withAlphaComponent(0.18)
        categoryLabel.textColor = color
        categoryBadgeView.backgroundColor = color.withAlphaComponent(0.18)

        // Receipt indicator, shown only when a photo is attached.
        receiptIconImageView.isHidden = (expense.receiptImageURL == nil)
    }
}
