import UIKit

class SummaryViewController: UIViewController {

    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var previousMonthButton: UIButton!
    @IBOutlet weak var nextMonthButton: UIButton!

    @IBOutlet weak var totalSpentLabel: UILabel!
    @IBOutlet weak var percentChangeLabel: UILabel!

    @IBOutlet weak var transportAmountLabel: UILabel!
    @IBOutlet weak var transportProgressView: UIProgressView!

    @IBOutlet weak var billsAmountLabel: UILabel!
    @IBOutlet weak var billsProgressView: UIProgressView!

    @IBOutlet weak var foodAmountLabel: UILabel!
    @IBOutlet weak var foodProgressView: UIProgressView!

    @IBOutlet weak var shoppingAmountLabel: UILabel!
    @IBOutlet weak var shoppingProgressView: UIProgressView!

    @IBOutlet weak var healthAmountLabel: UILabel!
    @IBOutlet weak var healthProgressView: UIProgressView!

    @IBOutlet weak var week1Bar: UIView!
    @IBOutlet weak var week2Bar: UIView!
    @IBOutlet weak var week3Bar: UIView!
    @IBOutlet weak var week4Bar: UIView!

    // MARK: - State

    private var allExpenses: [Expense] = []
    private var displayedMonth: Date = Date()

    // Categories shown as individual rows
    private static let summaryCategories: [ExpenseCategory] = [.transport, .bills, .food, .shopping, .health]

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    // Baseline y-position and max height for the weekly bars.
    private let weekBarBaselineY: CGFloat = 110
    private let weekBarMaxHeight: CGFloat = 90
    private let weekBarMinHeight: CGFloat = 4

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadExpenses()
    }

    // MARK: - Data

    // One-time fetch of all expenses
    private func loadExpenses() {
        DatabaseService.shared.fetchExpenses { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let expenses):
                    self.allExpenses = expenses
                    self.refreshUI()
                case .failure(let error):
                    self.presentAlert(title: "Couldn't load summary", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Actions

    @IBAction func previousMonthTapped(_ sender: UIButton) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = newMonth
        refreshUI()
    }

    @IBAction func nextMonthTapped(_ sender: UIButton) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = newMonth
        refreshUI()
    }

    // MARK: - Computation + UI refresh

    // Recomputes and repaints everything for the displayed month.
    private func refreshUI() {
        monthLabel.text = Self.monthYearFormatter.string(from: displayedMonth)

        let thisMonthExpenses = expenses(in: displayedMonth)
        let thisMonthTotal = thisMonthExpenses.reduce(0) { $0 + $1.amount }
        totalSpentLabel.text = String(format: "$%.2f", thisMonthTotal)

        updatePercentChange(currentTotal: thisMonthTotal)
        updateCategoryBreakdown(for: thisMonthExpenses)
        updateWeeklyBreakdown(for: thisMonthExpenses)
    }

    private func expenses(in month: Date) -> [Expense] {
        let calendar = Calendar.current
        return allExpenses.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    // Computes "up/down X% vs last month".
    private func updatePercentChange(currentTotal: Double) {
        guard let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else {
            percentChangeLabel.text = ""
            return
        }
        let previousTotal = expenses(in: previousMonth).reduce(0) { $0 + $1.amount }

        // Avoid dividing by zero when there's no prior spending to compare against.
        guard previousTotal > 0 else {
            percentChangeLabel.text = currentTotal > 0 ? "No spending last month to compare" : "No spending this month"
            return
        }

        let percentChange = ((currentTotal - previousTotal) / previousTotal) * 100
        let arrow = percentChange >= 0 ? "↑" : "↓"
        percentChangeLabel.text = String(format: "%@ %.0f%% vs last month", arrow, abs(percentChange))
    }

    // Sums each category and sizes its progress bar relative to the busiest one.
    private func updateCategoryBreakdown(for expenses: [Expense]) {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in expenses {
            totals[expense.category, default: 0] += expense.amount
        }

        let maxAmount = Self.summaryCategories.map { totals[$0] ?? 0 }.max() ?? 0

        let rows: [(ExpenseCategory, UILabel, UIProgressView)] = [
            (.transport, transportAmountLabel, transportProgressView),
            (.bills, billsAmountLabel, billsProgressView),
            (.food, foodAmountLabel, foodProgressView),
            (.shopping, shoppingAmountLabel, shoppingProgressView),
            (.health, healthAmountLabel, healthProgressView)
        ]

        for (category, label, progressView) in rows {
            let amount = totals[category] ?? 0
            label.text = String(format: "$%.2f", amount)
            progressView.progress = maxAmount > 0 ? Float(amount / maxAmount) : 0
            progressView.progressTintColor = category.accentColor
        }
    }

    // Splits the month into 4 buckets and sizes each bar relative to the busiest one.
    private func updateWeeklyBreakdown(for expenses: [Expense]) {
        let calendar = Calendar.current
        var weekTotals = [Double](repeating: 0, count: 4)

        // Bucket each expense into a week based on its day of month.
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            let weekIndex = min((day - 1) / 7, 3)
            weekTotals[weekIndex] += expense.amount
        }

        let maxWeekTotal = weekTotals.max() ?? 0
        let bars = [week1Bar, week2Bar, week3Bar, week4Bar]

        // Resize each bar proportionally, anchored to the baseline.
        for (index, bar) in bars.enumerated() {
            guard let bar else { continue }
            let ratio = maxWeekTotal > 0 ? CGFloat(weekTotals[index] / maxWeekTotal) : 0
            let height = max(weekBarMinHeight, weekBarMaxHeight * ratio)
            var frame = bar.frame
            frame.size.height = height
            frame.origin.y = weekBarBaselineY - height
            bar.frame = frame
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
