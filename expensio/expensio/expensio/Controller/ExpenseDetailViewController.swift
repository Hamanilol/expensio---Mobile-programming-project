import UIKit

/// Lets the presenting screen (Expenses list) know when this expense was
/// changed or removed, matching the delegate pattern taught for
/// cross-view-controller communication (see the Protocols lesson).
protocol ExpenseDetailViewControllerDelegate: AnyObject {
    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didUpdate expense: Expense)
    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didDelete expense: Expense)
}

/// Shows the full details of a single expense (title, category, amount, date,
/// receipt photo) with Edit and Delete actions.
class ExpenseDetailViewController: UIViewController {

    var expense: Expense!
    weak var delegate: ExpenseDetailViewControllerDelegate?

    // MARK: - Outlets (wired in Main.storyboard, scene "ExpenseDetailVC")

    @IBOutlet weak var receiptImageView: UIImageView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var categoryBadgeView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

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

    private func populateFields() {
        amountLabel.text = String(format: "$%.2f", expense.amount)
        titleLabel.text = expense.title
        dateLabel.text = Self.dateFormatter.string(from: expense.date)

        let color = expense.category.accentColor
        let badgeText = expense.category.rawValue.capitalized
        categoryLabel.text = badgeText
        categoryLabel.textColor = color
        categoryBadgeView.backgroundColor = color.withAlphaComponent(0.18)

        // Resize the badge to fit the text
        let textW = (badgeText as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ]).width + 24
        categoryBadgeView.frame.size.width = textW
        categoryLabel.frame.size.width = textW

        if let urlString = expense.receiptImageURL, let url = URL(string: urlString) {
            loadReceiptImage(from: url)
        } else {
            receiptImageView.image = UIImage(systemName: "photo")
            receiptImageView.contentMode = .center
            receiptImageView.tintColor = UIColor(red: 0.65, green: 0.68, blue: 0.75, alpha: 1)
        }
    }

    /// Simple URLSession-based image load — no third-party image caching
    /// library, since we only ever load one image on this screen.
    private func loadReceiptImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.receiptImageView.contentMode = .scaleAspectFill
                self?.receiptImageView.image = image
            }
        }.resume()
    }

    // MARK: - Actions

    @IBAction private func backTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditExpense",
           let addVC = segue.destination as? AddExpenseViewController {
            addVC.expenseToEdit = expense
            addVC.delegate = self
        }
    }

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

// MARK: - AddExpenseViewControllerDelegate

extension ExpenseDetailViewController: AddExpenseViewControllerDelegate {

    /// Called after the Edit form saves successfully — refresh this screen's
    /// own display and let the Expenses list know via our own delegate.
    func addExpenseViewController(_ controller: AddExpenseViewController, didSave expense: Expense) {
        self.expense = expense
        populateFields()
        delegate?.expenseDetailViewController(self, didUpdate: expense)
    }
}
