import SwiftyStoreKit
import StoreKit

class Tip: UIViewController, ThemeableViewController {
    let tipProductIds = ["smalltip", "mediumtip", "largetip", "verylargetip", "gianttip"]
    var tipProducts: Set<SKProduct>?

    @IBOutlet private weak var explanationLabel: UILabel!
    @IBOutlet private var tipButtons: [UIButton]!

    override func viewDidLoad() {
        super.viewDidLoad()
        SwiftyStoreKit.retrieveProductsInfo(Set(tipProductIds)) { [weak self] results in
            guard let viewController = self else { return }
            guard results.retrievedProducts.count == viewController.tipProductIds.count else {
                viewController.tipButtons[1].isEnabled = false
                viewController.tipButtons[1].setTitle("Not available", for: .normal)
                return
            }
            viewController.tipProducts = results.retrievedProducts
            viewController.displayTipPrices()
        }

        monitorThemeSetting()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let scrollView = view.subviews[0] as! UIScrollView
        let contentView = scrollView.subviews[0]

        let top = (scrollView.bounds.height - contentView.bounds.height) / 2
        scrollView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
    }

    func displayTipPrices() {
        guard let tipProducts = tipProducts else { return }

        let priceFormatter = NumberFormatter()
        priceFormatter.formatterBehavior = .behavior10_4
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = tipProducts.first!.priceLocale

        for (index, productId) in tipProductIds.enumerated() {
            guard let product = tipProducts.first(where: { $0.productIdentifier == productId }) else { fatalError("No product with ID \(productId)") }
            guard let priceString = priceFormatter.string(from: product.price) else { fatalError("Could not format price string \(product.price)") }

            let button = tipButtons[index]
            button.isHidden = false
            button.isEnabled = true
            button.setTitle(priceString, for: .normal)
        }
    }

    @IBAction private func tipPressed(_ sender: UIButton) {
        guard let tipProducts = tipProducts else { return }

        let senderIndex = tipButtons.index(of: sender)!
        let productId = tipProductIds[senderIndex]
        let product = tipProducts.first { $0.productIdentifier == productId }!

        SwiftyStoreKit.purchaseProduct(product) { [weak self] result in
            switch result {
            case .success:
                guard let viewController = self else { return }
                viewController.explanationLabel.text = "Thanks for supporting Reading List! ❤️"
                viewController.tipButtons.forEach { $0.isHidden = true }
                UserSettings.hasEverTipped.value = true

            case .error(let error):
                guard error.code != .paymentCancelled else { return }

                let alert = UIAlertController(title: "Tip Failed", message: "Something went wrong - thanks for trying though!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default))
                appDelegate.window?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    func initialise(withTheme theme: Theme) {
        view.backgroundColor = theme.viewBackgroundColor
        explanationLabel.textColor = theme.titleTextColor
    }
}
