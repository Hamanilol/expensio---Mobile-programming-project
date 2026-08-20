import UIKit
import FirebaseAuth

class ExpensesViewController: UIViewController {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!

    @IBOutlet weak var totalSpentLabel: UILabel!

    @IBOutlet weak var searchTextField: UITextField!

    @IBOutlet weak var categoryFilterScrollView: UIScrollView!
    @IBOutlet weak var allFilterButton: UIButton!
    @IBOutlet weak var foodFilterButton: UIButton!
    @IBOutlet weak var transportFilterButton: UIButton!
    @IBOutlet weak var billsFilterButton: UIButton!
    @IBOutlet weak var shoppingFilterButton: UIButton!

    @IBOutlet weak var expensesTableView: UITableView!
    @IBOutlet weak var addExpenseButton: UIButton!

    // MARK: - State

    private var allExpenses: [Expense] = []
    private var filteredExpenses: [Expense] = []

    private var selectedCategory: ExpenseCategory?
    private var selectedMonth: Int? = nil   // nil = all months, 1–12 = specific month
    private var searchQuery: String = ""

    private var expensesListener: DatabaseObserver?
    private var selectedExpense: Expense?

    // Programmatically-added filter controls (not in the storyboard).
    private var healthFilterButton: UIButton?
    private var otherFilterButton: UIButton?
    private var monthFilterButtons: [UIButton] = []
    private var didSetupMonthFilter = false

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHeader()
        configureSearchField()
        addMissingCategoryChips()
        updateFilterButtonStyles()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Run once after the storyboard frames have been applied.
        if !didSetupMonthFilter {
            didSetupMonthFilter = true
            setupMonthFilter()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startObservingExpenses()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening while this screen isn't visible.
        expensesListener?.remove()
        expensesListener = nil
    }

    // MARK: - Setup

    // Shows the signed-in user's name (or email as a fallback) and the current month.
    private func configureHeader() {
        let user = Auth.auth().currentUser
        userNameLabel.text = user?.displayName?.isEmpty == false
            ? user?.displayName
            : (AuthService.shared.currentUserEmail ?? "")
        dateLabel.text = Self.monthYearFormatter.string(from: Date())
    }

    private func configureSearchField() {
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
    }

    @objc private func searchTextChanged() {
        searchQuery = searchTextField.text ?? ""
        applyFilters()
    }

    // MARK: - Category chips (Health + Other; storyboard has All/Food/Transport/Bills/Shopping)

    // Adds two extra chips after the storyboard's own five.
    private func addMissingCategoryChips() {
        // Storyboard Shopping button: x=320, w=90 → right edge at 410.
        // Health starts at 418, Other at 502.
        let healthBtn = makeChip(title: "Health")
        healthBtn.frame = CGRect(x: 418, y: 0, width: 76, height: 32)
        healthBtn.tag = 5
        healthBtn.addTarget(self, action: #selector(extraCategoryTapped(_:)), for: .touchUpInside)
        categoryFilterScrollView.addSubview(healthBtn)
        healthFilterButton = healthBtn

        let otherBtn = makeChip(title: "Other")
        otherBtn.frame = CGRect(x: 502, y: 0, width: 70, height: 32)
        otherBtn.tag = 6
        otherBtn.addTarget(self, action: #selector(extraCategoryTapped(_:)), for: .touchUpInside)
        categoryFilterScrollView.addSubview(otherBtn)
        otherFilterButton = otherBtn

        // Widen the scroll content to fit all 7 chips.
        categoryFilterScrollView.contentSize = CGSize(width: 580, height: 36)
    }

    @objc private func extraCategoryTapped(_ sender: UIButton) {
        selectedCategory = sender.tag == 5 ? .health : .other
        updateFilterButtonStyles()
        applyFilters()
    }

    // Shared factory so both extra chips look identical to the storyboard's own.
    private func makeChip(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        button.backgroundColor = UIColor(red: 0.09, green: 0.125, blue: 0.227, alpha: 1)
        button.setTitleColor(UIColor(red: 0.698, green: 0.731, blue: 0.779, alpha: 1), for: .normal)
        return button
    }

    // MARK: - Month filter row (built entirely in code, matches Figma design)

    // Builds a second scrolling chip row (All + Jan–Dec) below the category row.
    private func setupMonthFilter() {
        let filterFrame = categoryFilterScrollView.frame   // x=24, y=279, w=342, h=36
        let monthRowY = filterFrame.maxY + 8                // 8pt gap below category row

        // Container scroll view for the month chips.
        let monthScroll = UIScrollView()
        monthScroll.showsHorizontalScrollIndicator = false
        monthScroll.backgroundColor = .clear
        monthScroll.frame = CGRect(x: filterFrame.minX, y: monthRowY,
                                   width: filterFrame.width, height: 32)
        view.addSubview(monthScroll)

        // "MONTH" row header label.
        let headerLabel = UILabel()
        headerLabel.text = "MONTH"
        headerLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        headerLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.53, alpha: 1)
        headerLabel.frame = CGRect(x: 0, y: 7, width: 52, height: 18)
        monthScroll.addSubview(headerLabel)

        // Build "All" + Jan–Dec chips left to right.
        let monthNames = ["All", "Jan", "Feb", "Mar", "Apr", "May",
                          "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var xCursor: CGFloat = 60

        for (index, name) in monthNames.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 14
            btn.clipsToBounds = true
            btn.tag = index   // 0 = All, 1–12 = month number
            let chipWidth: CGFloat = name == "All" ? 40 : 44
            btn.frame = CGRect(x: xCursor, y: 0, width: chipWidth, height: 32)
            btn.addTarget(self, action: #selector(monthFilterTapped(_:)), for: .touchUpInside)
            monthScroll.addSubview(btn)
            monthFilterButtons.append(btn)
            xCursor += chipWidth + 8
        }

        monthScroll.contentSize = CGSize(width: xCursor, height: 32)

        // Push the table view down and shrink it to make room for the new row.
        let newTableY = monthScroll.frame.maxY + 8
        let oldTableMaxY = expensesTableView.frame.maxY
        expensesTableView.frame = CGRect(
            x: expensesTableView.frame.minX,
            y: newTableY,
            width: expensesTableView.frame.width,
            height: max(0, oldTableMaxY - newTableY)
        )

        updateMonthButtonStyles()
    }

    @objc private func monthFilterTapped(_ sender: UIButton) {
        selectedMonth = sender.tag == 0 ? nil : sender.tag
        updateMonthButtonStyles()
        applyFilters()
    }

    // MARK: - Data

    // Subscribes to live updates so the list refreshes automatically after any change.
    private func startObservingExpenses() {
        expensesListener = DatabaseService.shared.observeExpenses { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let expenses):
                    self.allExpenses = expenses
                    self.applyFilters()
                case .failure(let error):
                    self.presentAlert(title: "Couldn't load expenses", message: error.localizedDescription)
                }
            }
        }
    }

    // Applies category, search, and month filters together, then reloads the table.
    private func applyFilters() {
        filteredExpenses = allExpenses.filter { expense in
            let matchesCategory = selectedCategory == nil || expense.category == selectedCategory
            let matchesSearch = searchQuery.isEmpty || expense.title.localizedCaseInsensitiveContains(searchQuery)
            let matchesMonth: Bool
            if let selectedMonth {
                let month = Calendar.current.component(.month, from: expense.date)
                matchesMonth = month == selectedMonth
            } else {
                matchesMonth = true
            }
            return matchesCategory && matchesSearch && matchesMonth
        }
        expensesTableView.reloadData()
        updateTotalSpentLabel()
    }

    // Total for the current calendar month, independent of any active filters.
    private func updateTotalSpentLabel() {
        let calendar = Calendar.current
        let now = Date()
        let monthTotal = allExpenses
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        totalSpentLabel.text = String(format: "$%.2f", monthTotal)
    }

    // MARK: - Actions

    // Signs out, then swaps the window's root view controller back to Login.
    @IBAction func logoutTapped(_ sender: UIButton) {
        do {
            try AuthService.shared.signOut()
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
            guard let window = view.window else { return }
            window.rootViewController = loginVC
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        } catch {
            presentAlert(title: "Couldn't log out", message: error.localizedDescription)
        }
    }

    // Handles the 5 storyboard category chips (the 2 extra ones use extraCategoryTapped).
    @IBAction func filterTapped(_ sender: UIButton) {
        switch sender {
        case allFilterButton: selectedCategory = nil
        case foodFilterButton: selectedCategory = .food
        case transportFilterButton: selectedCategory = .transport
        case billsFilterButton: selectedCategory = .bills
        case shoppingFilterButton: selectedCategory = .shopping
        default: break
        }
        updateFilterButtonStyles()
        applyFilters()
    }

    @IBAction func addExpenseTapped(_ sender: UIButton) {
        // Storyboard segue triggers presentation of AddExpenseViewController.
    }

    // MARK: - Chip styling

    // Highlights whichever category chip is currently selected.
    private func updateFilterButtonStyles() {
        let active = UIColor(red: 0.267, green: 0.439, blue: 0.745, alpha: 1)
        let inactive = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1)
        let inactiveText = UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1)

        // Storyboard category chips.
        let storyboardChips: [(UIButton, ExpenseCategory?)] = [
            (allFilterButton, nil),
            (foodFilterButton, .food),
            (transportFilterButton, .transport),
            (billsFilterButton, .bills),
            (shoppingFilterButton, .shopping)
        ]
        for (btn, category) in storyboardChips {
            let on = category == selectedCategory
            btn.backgroundColor = on ? active.withAlphaComponent(0.22) : inactive
            btn.setTitleColor(on ? active : inactiveText, for: .normal)
        }

        // Programmatic category chips.
        let extraChips: [(UIButton?, ExpenseCategory)] = [
            (healthFilterButton, .health),
            (otherFilterButton, .other)
        ]
        for (btn, category) in extraChips {
            guard let btn else { continue }
            let on = selectedCategory == category
            btn.backgroundColor = on ? active.withAlphaComponent(0.22) : inactive
            btn.setTitleColor(on ? active : inactiveText, for: .normal)
        }

        updateMonthButtonStyles()
    }

    // Highlights whichever month chip is currently selected.
    private func updateMonthButtonStyles() {
        let active = UIColor(red: 0.267, green: 0.439, blue: 0.745, alpha: 1)
        let inactive = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1)
        let inactiveText = UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1)

        for btn in monthFilterButtons {
            let on = (btn.tag == 0 && selectedMonth == nil) || btn.tag == selectedMonth
            btn.backgroundColor = on ? active.withAlphaComponent(0.22) : inactive
            btn.setTitleColor(on ? active : inactiveText, for: .normal)
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate

extension ExpensesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredExpenses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExpenseCell", for: indexPath) as! ExpenseTableViewCell
        cell.configure(with: filteredExpenses[indexPath.row])
        return cell
    }

    // Stashes the tapped expense, then triggers the detail segue.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedExpense = filteredExpenses[indexPath.row]
        performSegue(withIdentifier: "ShowExpenseDetail", sender: nil)
    }

    // Passes the selected expense to ExpenseDetailViewController.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowExpenseDetail",
           let detailVC = segue.destination as? ExpenseDetailViewController {
            detailVC.expense = selectedExpense
            detailVC.delegate = self
        }
    }
}

// MARK: - ExpenseDetailViewControllerDelegate / AddExpenseViewControllerDelegate

extension ExpensesViewController: ExpenseDetailViewControllerDelegate, AddExpenseViewControllerDelegate {

    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didUpdate expense: Expense) {
        // Live listener refreshes the list automatically.
    }

    func expenseDetailViewController(_ controller: ExpenseDetailViewController, didDelete expense: Expense) {
        // Live listener refreshes the list automatically.
    }

    func addExpenseViewController(_ controller: AddExpenseViewController, didSave expense: Expense) {
        // Live listener refreshes the list automatically.
    }
}
