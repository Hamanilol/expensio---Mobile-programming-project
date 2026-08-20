import UIKit

/// Lets the presenting screen (Expenses list, or Expense Detail when editing)
/// know a save completed, matching the delegate pattern taught for
/// cross-view-controller communication (see the Protocols lesson).
protocol AddExpenseViewControllerDelegate: AnyObject {
    func addExpenseViewController(_ controller: AddExpenseViewController, didSave expense: Expense)
}

class AddExpenseViewController: UIViewController {

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!

    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var titleDescriptionTextField: UITextField!

    @IBOutlet weak var foodCategoryButton: UIButton!
    @IBOutlet weak var transportCategoryButton: UIButton!
    @IBOutlet weak var billsCategoryButton: UIButton!
    @IBOutlet weak var shoppingCategoryButton: UIButton!
    @IBOutlet weak var healthCategoryButton: UIButton!
    @IBOutlet weak var otherCategoryButton: UIButton!

    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var calendarButton: UIButton!

    @IBOutlet weak var receiptButton: UIButton!
    @IBOutlet weak var saveExpenseButton: UIButton!

    var expenseToEdit: Expense?
    weak var delegate: AddExpenseViewControllerDelegate?

    private var selectedCategory: ExpenseCategory = .food
    private var selectedDate = Date()
    private var pickedReceiptImage: UIImage?
    // Tracks when the user explicitly removes an existing receipt in edit mode
    private var removeExistingReceipt = false

    private weak var removeReceiptButton: UIButton?
    private var didSetupRemoveButton = false

    // Inline date picker — maximumDate = today prevents selecting future dates
    private let inlineDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.maximumDate = Date()
        if #available(iOS 14.0, *) {
            picker.preferredDatePickerStyle = .inline
        }
        picker.backgroundColor = UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
        return picker
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDateField()

        if let expenseToEdit {
            populateForEditing(expenseToEdit)
        } else {
            updateCategoryButtonStyles()
            updateDateField()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetupRemoveButton {
            didSetupRemoveButton = true
            setupRemoveReceiptButton()
        }
    }

    // MARK: - Setup

    private func setupDateField() {
        inlineDatePicker.addTarget(self, action: #selector(datePickerValueChanged(_:)), for: .valueChanged)

        // Toolbar with Done button so the user can explicitly confirm and dismiss the picker
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barTintColor = UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
        toolbar.tintColor = .white
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneStyle: UIBarButtonItem.Style = {
            if #available(iOS 26.0, *) { return .prominent }
            return .done
        }()
        let done = UIBarButtonItem(title: "Done", style: doneStyle, target: self, action: #selector(datePickerDoneTapped))
        toolbar.setItems([flex, done], animated: false)

        dateTextField.inputAccessoryView = toolbar
        dateTextField.inputView = inlineDatePicker
        dateTextField.tintColor = .clear
    }

    @objc private func datePickerDoneTapped() {
        dateTextField.resignFirstResponder()
    }

    @objc private func datePickerValueChanged(_ picker: UIDatePicker) {
        selectedDate = picker.date
        updateDateField()
    }

    private func updateDateField() {
        dateTextField.text = Self.displayFormatter.string(from: selectedDate)
    }

    // Positioned after layout so receiptButton.frame is finalised
    private func setupRemoveReceiptButton() {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = UIColor(red: 0.98, green: 0.37, blue: 0.37, alpha: 1)
        btn.isHidden = true

        let rf = receiptButton.frame
        btn.frame = CGRect(x: rf.maxX - 20, y: rf.minY - 12, width: 28, height: 28)
        view.addSubview(btn)
        btn.addTarget(self, action: #selector(removeReceiptTapped), for: .touchUpInside)
        removeReceiptButton = btn
    }

    @objc private func removeReceiptTapped() {
        pickedReceiptImage = nil
        removeExistingReceipt = true
        receiptButton.setTitle("Attach Receipt", for: .normal)
        removeReceiptButton?.isHidden = true
    }

    private func showRemoveButton() {
        removeReceiptButton?.isHidden = false
    }

    private func populateForEditing(_ expense: Expense) {
        saveButton.setTitle("Save", for: .normal)
        amountTextField.text = String(format: "%.2f", expense.amount)
        titleDescriptionTextField.text = expense.title
        selectedCategory = expense.category
        selectedDate = expense.date
        inlineDatePicker.date = expense.date
        updateDateField()
        updateCategoryButtonStyles()

        if expense.receiptImageURL != nil {
            receiptButton.setTitle("Receipt attached · Tap to change", for: .normal)
            showRemoveButton()
        }
    }

    // MARK: - Actions

    @IBAction func backTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func categoryTapped(_ sender: UIButton) {
        switch sender {
        case foodCategoryButton: selectedCategory = .food
        case transportCategoryButton: selectedCategory = .transport
        case billsCategoryButton: selectedCategory = .bills
        case shoppingCategoryButton: selectedCategory = .shopping
        case healthCategoryButton: selectedCategory = .health
        case otherCategoryButton: selectedCategory = .other
        default: break
        }
        updateCategoryButtonStyles()
    }

    @IBAction func datePickerTapped(_ sender: UIButton) {
        dateTextField.becomeFirstResponder()
    }

    @IBAction func attachReceiptTapped(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func saveTapped(_ sender: UIButton) {
        guard let amountText = amountTextField.text?.trimmingCharacters(in: .whitespaces),
              let amount = Double(amountText), amount > 0 else {
            presentAlert(title: "Invalid amount", message: "Please enter an amount greater than 0.")
            return
        }
        guard let title = titleDescriptionTextField.text?.trimmingCharacters(in: .whitespaces), !title.isEmpty else {
            presentAlert(title: "Missing title", message: "Please enter a title or description for this expense.")
            return
        }

        setSaving(true)

        if let pickedReceiptImage {
            CloudinaryService.shared.uploadImage(pickedReceiptImage) { [weak self] result in
                switch result {
                case .success(let url):
                    self?.saveExpense(title: title, amount: amount, receiptImageURL: url)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.setSaving(false)
                        self?.presentAlert(title: "Photo upload failed", message: error.localizedDescription)
                    }
                }
            }
        } else {
            // Preserve existing URL unless user explicitly removed it
            let urlToSave = removeExistingReceipt ? nil : expenseToEdit?.receiptImageURL
            saveExpense(title: title, amount: amount, receiptImageURL: urlToSave)
        }
    }

    // MARK: - Save

    private func saveExpense(title: String, amount: Double, receiptImageURL: String?) {
        var expense = expenseToEdit ?? Expense(
            id: nil, title: title, amount: amount, category: selectedCategory,
            date: selectedDate, receiptImageURL: receiptImageURL, createdAt: nil
        )
        expense.title = title
        expense.amount = amount
        expense.category = selectedCategory
        expense.date = selectedDate
        expense.receiptImageURL = receiptImageURL

        if expenseToEdit != nil {
            DatabaseService.shared.updateExpense(expense) { [weak self] result in
                self?.handleSaveResult(result.map { expense })
            }
        } else {
            DatabaseService.shared.addExpense(expense) { [weak self] result in
                switch result {
                case .success(let newId):
                    var savedExpense = expense
                    savedExpense.id = newId
                    self?.handleSaveResult(.success(savedExpense))
                case .failure(let error):
                    self?.handleSaveResult(.failure(error))
                }
            }
        }
    }

    private func handleSaveResult(_ result: Result<Expense, Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setSaving(false)
            switch result {
            case .success(let savedExpense):
                self.delegate?.addExpenseViewController(self, didSave: savedExpense)
                self.dismiss(animated: true)
            case .failure(let error):
                self.presentAlert(title: "Couldn't save expense", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Styling helpers

    private func updateCategoryButtonStyles() {
        let chips: [(UIButton, ExpenseCategory)] = [
            (foodCategoryButton, .food),
            (transportCategoryButton, .transport),
            (billsCategoryButton, .bills),
            (shoppingCategoryButton, .shopping),
            (healthCategoryButton, .health),
            (otherCategoryButton, .other)
        ]

        for (button, category) in chips {
            let isSelected = category == selectedCategory
            let color = category.accentColor
            button.backgroundColor = isSelected ? color.withAlphaComponent(0.16) : UIColor(red: 0.071, green: 0.086, blue: 0.137, alpha: 1)
            button.setTitleColor(isSelected ? color : UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1), for: .normal)
            button.tintColor = isSelected ? color : UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1)
        }
    }

    private func setSaving(_ isSaving: Bool) {
        saveExpenseButton.isEnabled = !isSaving
        saveExpenseButton.alpha = isSaving ? 0.6 : 1.0
        saveButton.isEnabled = !isSaving
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension AddExpenseViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        pickedReceiptImage = image
        removeExistingReceipt = false
        receiptButton.setTitle("Receipt attached · Tap to change", for: .normal)
        showRemoveButton()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
