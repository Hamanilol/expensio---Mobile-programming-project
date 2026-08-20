import UIKit

// Notifies the presenting screen when this expense is changed or removed.
protocol ExpenseDetailViewControllerDelegate: AnyObject {
    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didUpdate expense: Expense)
    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didDelete expense: Expense)
}

// Shows the full details of one expense, with Edit and Delete actions.
class ExpenseDetailViewController: UIViewController {

    var expense: Expense!
    weak var delegate: ExpenseDetailViewControllerDelegate?

    // MARK: - Outlets

    @IBOutlet weak var receiptImageView: UIImageView!
    @IBOutlet weak var receiptPlaceholderIcon: UIImageView!
    @IBOutlet weak var receiptPlaceholderLabel: UILabel!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var categoryBadgeView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var categoryValueLabel: UILabel!
    @IBOutlet weak var dateValueLabel: UILabel!
    @IBOutlet weak var receiptValueLabel: UILabel!

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        populateFields()
    }

    // MARK: - Populate

    // Fills every label from `expense`.
    private func populateFields() {
        titleLabel.text = expense.title

        // Category badge.
        let color = expense.category.accentColor
        let badgeText = expense.category.rawValue.capitalized
        categoryLabel.text = badgeText
        categoryLabel.textColor = color
        categoryBadgeView.backgroundColor = color.withAlphaComponent(0.18)

        // Resize the badge to fit the category name.
        let textW = (badgeText as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]).width + 24
        categoryBadgeView.frame.size.width = textW
        categoryLabel.frame.size.width = textW

        let formattedDate = Self.dateFormatter.string(from: expense.date)
        dateLabel.text = formattedDate

        // Info card values.
        amountLabel.text = String(format: "$%.2f", expense.amount)
        categoryValueLabel.text = badgeText
        dateValueLabel.text = formattedDate

        // Receipt: load the image if there's a URL, otherwise show the placeholder.
        if let urlString = expense.receiptImageURL, let url = URL(string: urlString) {
            receiptValueLabel.text = url.lastPathComponent
            receiptPlaceholderIcon.isHidden = true
            receiptPlaceholderLabel.isHidden = true
            loadReceiptImage(from: url)
        } else {
            receiptValueLabel.text = "None"
            receiptImageView.image = nil
            receiptPlaceholderIcon.isHidden = false
            receiptPlaceholderLabel.isHidden = false
        }
    }

    // Loads the receipt image via URLSession.
    private func loadReceiptImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.receiptImageView.image = image
            }
        }.resume()
    }

    // MARK: - Actions

    @IBAction private func backTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    // Passes the current expense to EditExpenseViewController before it appears.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditExpense",
           let editVC = segue.destination as? EditExpenseViewController {
            editVC.expense = expense
            editVC.delegate = self
        }
    }

    // Confirms before deleting.
    @IBAction private func deleteTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Delete Expense?",
            message: "This can't be undone.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func performDelete() {
        guard let id = expense.id else { return }

        DatabaseService.shared.deleteExpense(id: id) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.delegate?.expenseDetailViewController(self, didDelete: self.expense)
                    self.dismiss(animated: true)
                case .failure(let error):
                    let alert = UIAlertController(title: "Something went wrong", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - EditExpenseViewControllerDelegate

extension ExpenseDetailViewController: EditExpenseViewControllerDelegate {

    // Refreshes this screen after an edit, then forwards the update to our own delegate.
    func editExpenseViewController(_ controller: EditExpenseViewController, didSave expense: Expense) {
        self.expense = expense
        populateFields()
        delegate?.expenseDetailViewController(self, didUpdate: expense)
    }
}
