import UIKit

/// Host app for the Morse keyboard. It exists mostly to install the extension
/// and to give you somewhere to try it out.
final class ViewController: UIViewController {

    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Morse Keyboard"

        let steps = UILabel()
        steps.numberOfLines = 0
        steps.font = .preferredFont(forTextStyle: .subheadline)
        steps.textColor = .secondaryLabel
        steps.text = """
            To install: Settings › General › Keyboard › Keyboards › \
            Add New Keyboard… › Morse.

            Then tap the globe key on any keyboard to switch to it. \
            Type below to try it out.
            """

        // Everything that could rewrite what you type is off, so ".." stays ".."
        // and "--" stays "--".
        textView.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 10

        let openSettings = UIButton(type: .system)
        openSettings.setTitle("Open Settings", for: .normal)
        openSettings.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [steps, textView, openSettings])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 180),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    @objc private func openSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
