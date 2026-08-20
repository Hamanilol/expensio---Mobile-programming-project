import UIKit

// Notifies the presenting screen that an edit was saved.
protocol EditExpenseViewControllerDelegate: AnyObject {
    func editExpenseViewController(_ controller: EditExpenseViewController, didSave expense: Expense)
}

// Screen for editing an existing expense, set by ExpenseDetailViewController before this appears.
class EditExpenseViewController: UIViewController {

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

    @IBOutlet weak var datePicker: UIDatePicker!

    @IBOutlet weak var receiptButton: UIButton!
    @IBOutlet weak var saveExpenseButton: UIButton!

    var expense: Expense!
    weak var delegate: EditExpenseViewControllerDelegate?

    private var selectedCategory: ExpenseCategory = .food
    private var pickedReceiptImage: UIImage?
    // True if the user tapped remove on the existing receipt.
    private var removeExistingReceipt = false

    private weak var removeReceiptButton: UIButton?
    private var didSetupRemoveButton = false

    override func viewDidLoad() {
        super.viewDidLoad()
        populateFields()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Pin the date picker's position; its .compact style can resize itself at runtime.
        datePicker.frame.origin.x = 6

        // Build the remove-receipt button once layout is final.
        if !didSetupRemoveButton {
            didSetupRemoveButton = true
            setupRemoveReceiptButton()
        }
    }

    // MARK: - Setup

    // datePicker's valueChanged event — no manual label to update, it displays its own date.
    @IBAction func dateChanged(_ sender: UIDatePicker) {
    }

    // Builds the small "remove receipt" button overlaid on receiptButton, hidden until needed.
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

    // Fills every field from the expense being edited.
    private func populateFields() {
        amountTextField.text = String(format: "%.2f", expense.amount)
        titleDescriptionTextField.text = expense.title
        selectedCategory = expense.category
        datePicker.date = expense.date
        updateCategoryButtonStyles()

        // Show the existing receipt state, if any.
        if expense.receiptImageURL != nil {
            receiptButton.setTitle("Receipt attached · Tap to change", for: .normal)
            showRemoveButton()
        }
    }

    // MARK: - Actions

    @IBAction func backTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    // Shared handler for all 6 category buttons.
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

    @IBAction func attachReceiptTapped(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    // Validates, uploads a new photo if needed, then saves the changes.
    @IBAction func saveTapped(_ sender: UIButton) {
        // Validate amount.
        guard let amountText = amountTextField.text?.trimmingCharacters(in: .whitespaces),
              let amount = Double(amountText), amount > 0 else {
            presentAlert(title: "Invalid amount", message: "Please enter an amount greater than 0.")
            return
        }
        // Validate title.
        guard let title = titleDescriptionTextField.text?.trimmingCharacters(in: .whitespaces), !title.isEmpty else {
            presentAlert(title: "Missing title", message: "Please enter a title or description for this expense.")
            return
        }

        setSaving(true)

        if let pickedReceiptImage {
            // Upload the new photo first, then save with the resulting URL.
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
            // Keep the existing receipt URL unless the user tapped remove.
            let urlToSave = removeExistingReceipt ? nil : expense.receiptImageURL
            saveExpense(title: title, amount: amount, receiptImageURL: urlToSave)
        }
    }

    // MARK: - Save

    // Applies the edited fields to the expense and writes it to the database.
    private func saveExpense(title: String, amount: Double, receiptImageURL: String?) {
        var updated = expense!
        updated.title = title
        updated.amount = amount
        updated.category = selectedCategory
        updated.date = datePicker.date
        updated.receiptImageURL = receiptImageURL

        DatabaseService.shared.updateExpense(updated) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setSaving(false)
                switch result {
                case .success:
                    self.delegate?.editExpenseViewController(self, didSave: updated)
                    self.dismiss(animated: true)
                case .failure(let error):
                    self.presentAlert(title: "Couldn't save expense", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Styling helpers

    // Highlights the selected category button.
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

extension EditExpenseViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

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
