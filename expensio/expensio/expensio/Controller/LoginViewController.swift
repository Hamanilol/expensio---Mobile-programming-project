import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var appNameLabel: UILabel!
    @IBOutlet weak var taglineLabel: UILabel!

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var togglePasswordButton: UIButton!

    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var createAccountButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        passwordTextField.isSecureTextEntry.toggle()
        let symbolName = passwordTextField.isSecureTextEntry ? "eye" : "eye.slash"
        sender.setImage(UIImage(systemName: symbolName), for: .normal)
    }

    @IBAction func signInTapped(_ sender: UIButton) {
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespaces), !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            presentAlert(title: "Missing information", message: "Please enter both your email and password.")
            return
        }

        setLoading(true)
        AuthService.shared.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    self.performSegue(withIdentifier: "LoginSuccess", sender: nil)
                case .failure(let error):
                    self.presentAlert(title: "Couldn't sign in", message: error.localizedDescription)
                }
            }
        }
    }

    @IBAction func createAccountTapped(_ sender: UIButton) {
        // Storyboard segue (Login → SignUp) handles this automatically.
    }

    // MARK: - Helpers

    private func setLoading(_ isLoading: Bool) {
        signInButton.isEnabled = !isLoading
        signInButton.alpha = isLoading ? 0.6 : 1.0
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
