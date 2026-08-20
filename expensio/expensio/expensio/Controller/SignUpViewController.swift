import UIKit

class SignUpViewController: UIViewController {

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!

    @IBOutlet weak var termsCheckboxButton: UIButton!
    @IBOutlet weak var termsLabel: UILabel!

    @IBOutlet weak var createAccountButton: UIButton!

    private var termsAccepted = true

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func backTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    // Flips the checkbox state and swaps its icon.
    @IBAction func toggleTermsCheckbox(_ sender: UIButton) {
        termsAccepted.toggle()
        let symbolName = termsAccepted ? "checkmark.square.fill" : "square"
        sender.setImage(UIImage(systemName: symbolName), for: .normal)
    }

    @IBAction func createAccountTapped(_ sender: UIButton) {
        // Validate full name.
        guard let fullName = fullNameTextField.text?.trimmingCharacters(in: .whitespaces), !fullName.isEmpty else {
            presentAlert(title: "Missing name", message: "Please enter your full name.")
            return
        }
        // Validate email.
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespaces), !email.isEmpty else {
            presentAlert(title: "Missing email", message: "Please enter your email address.")
            return
        }
        // Validate password length.
        guard let password = passwordTextField.text, password.count >= 6 else {
            presentAlert(title: "Weak password", message: "Password must be at least 6 characters.")
            return
        }
        // Confirms password match.
        guard password == confirmPasswordTextField.text else {
            presentAlert(title: "Passwords don't match", message: "Please make sure both password fields match.")
            return
        }
        // Validate terms were accepted.
        guard termsAccepted else {
            presentAlert(title: "Terms required", message: "Please agree to the Terms of Service and Privacy Policy to continue.")
            return
        }

        // Create the account.
        setLoading(true)
        AuthService.shared.signUp(fullName: fullName, email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    self.performSegue(withIdentifier: "SignUpSuccess", sender: nil)
                case .failure(let error):
                    self.presentAlert(title: "Couldn't create account", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helpers

    private func setLoading(_ isLoading: Bool) {
        createAccountButton.isEnabled = !isLoading
        createAccountButton.alpha = isLoading ? 0.6 : 1.0
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
