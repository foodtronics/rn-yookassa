import Foundation
import YooKassaPayments

@objc(RnYookassa)
class RnYookassa: RCTViewManager, TokenizationModuleOutput {
    var callback: RCTResponseSenderBlock?
    var confirmCallback: RCTResponseSenderBlock?
    var viewController: UIViewController?

    @objc
    func tokenize(_ params: NSDictionary, callbacker callback: @escaping RCTResponseSenderBlock) -> Void {
        self.callback = callback
        guard let clientApplicationKey = params["clientApplicationKey"] as? String,
            let _shopId = params["shopId"] as? String,
            let title = params["title"] as? String,
            let subtitle = params["subtitle"] as? String,
            let amountValue = params["price"] as? NSNumber,
            let savePaymentMethod = params["savePaymentMethod"] as? Bool
        else {
            return
        }

        // Optional:
        let paymentTypes = params["paymentMethodTypes"] as? [String]
        let authCenterClientId = params["authCenterClientId"] as? String
        let userPhoneNumber = params["userPhoneNumber"] as? String
        let gatewayId = params["gatewayId"] as? String
        let applePayMerchantId = params["applePayMerchantId"] as? String
        let returnUrl = params["returnUrl"] as? String
        let isDebug = params["isDebug"] as? Bool

        var paymentMethodTypes: PaymentMethodTypes = []

        if (paymentTypes != nil) {
            paymentTypes!.forEach { type in
                if let payType = PaymentMethodType(rawValue: type.lowercased()) {
                    if (payType == .yooMoney && authCenterClientId == nil) {
                        return
                    }

                    paymentMethodTypes.insert(PaymentMethodTypes(rawValue: [payType]))
                }
            }
        } else {
            paymentMethodTypes.insert(.bankCard)
            paymentMethodTypes.insert(.sberbank)

            if (authCenterClientId != nil) {
                paymentMethodTypes.insert(.yooMoney)
            }
        }

        let testModeSettings = TestModeSettings(paymentAuthorizationPassed: false,
                                                cardsCount: 2,
                                                charge: Amount(value: 10, currency: .rub),
                                                enablePaymentError: false)

        let tokenizationSettings = TokenizationSettings(paymentMethodTypes: paymentMethodTypes)

        let amount = Amount(value: amountValue.decimalValue, currency: .rub)
        let tokenizationModuleInputData =
            TokenizationModuleInputData(clientApplicationKey: clientApplicationKey,
            shopName: title,
            shopId: _shopId,
            purchaseDescription: subtitle,
            amount: amount,
            gatewayId: gatewayId,
            tokenizationSettings: tokenizationSettings,
            testModeSettings: (isDebug ?? false) ? testModeSettings : nil,
            // cardScanning: CardScannerProvider(),
            returnUrl: returnUrl,
            isLoggingEnabled: (isDebug != nil) ? true : false,
            userPhoneNumber: userPhoneNumber,
            customizationSettings: CustomizationSettings(mainScheme: UIColor(red: 244 / 255, green: 71 / 255, blue: 0 / 255, alpha: 1)),
            savePaymentMethod: savePaymentMethod ? .on : .off,
            moneyAuthClientId: authCenterClientId,
            applicationScheme: "fibbee://"
        )

        DispatchQueue.main.async {
            let inputData: TokenizationFlow = .tokenization(tokenizationModuleInputData)
            self.viewController = TokenizationAssembly.makeModule(inputData: inputData, moduleOutput: self)
            // let rootViewController = UIApplication.shared.windows.last { $0.isKeyWindow }?.rootViewController!
            // rootViewController?.present(self.viewController!, animated: true, completion: nil)
            let rootViewController = UIApplication.shared.keyWindow!.rootViewController!
                        rootViewController.present(self.viewController!, animated: true, completion: nil)
        }
    }

    @objc
    func confirmPayment(_ params: NSDictionary, callbacker callback: @escaping RCTResponseSenderBlock) -> Void {
        guard let confirmationUrl = params["confirmationUrl"] as? String,
            let _paymentMethodType = params["paymentMethodType"] as? String
        else {
            return
        }

        guard let paymentMethodType = PaymentMethodType(rawValue: _paymentMethodType.lowercased()) else { return }

        guard let viewController = viewController as? TokenizationModuleInput else { return }
        confirmCallback = callback
        viewController.startConfirmationProcess(confirmationUrl: confirmationUrl,
                                                paymentMethodType: paymentMethodType)
    }

    @objc
    func dismiss() {
        DispatchQueue.main.async {
            self.viewController?.dismiss(animated: true)
        }
    }

    func tokenizationModule(_ module: TokenizationModuleInput, didTokenize token: Tokens, paymentMethodType: PaymentMethodType)
    {
        let result: NSDictionary = [
            "paymentToken" : token.paymentToken,
            "paymentMethodType" : paymentMethodType.rawValue.uppercased()
        ]

        if let callback = callback {
            callback([result])
            self.callback = nil
        }
    }


    func didFinish(on module: TokenizationModuleInput, with error: YooKassaPaymentsError?) {
        let error: NSDictionary = [
            "code" : "E_PAYMENT_CANCELLED",
            "message" : "Payment cancelled."
        ]

        DispatchQueue.main.async { self.dismiss() }

        if let callback = callback {
            callback([NSNull(), error])
            self.callback = nil
        }
    }

    func didFinishConfirmation(paymentMethodType: PaymentMethodType) {
        let result: NSDictionary = [
            "paymentMethodType" : paymentMethodType.rawValue.uppercased()
        ]

        DispatchQueue.main.async { self.dismiss() }

        if let callback = self.confirmCallback {
            callback([result])
            confirmCallback = nil
        }
    }

    override class func requiresMainQueueSetup() -> Bool {
        return false
    }

    func didSuccessfullyPassedCardSec(on module: TokenizationModuleInput) {}

    func didFailConfirmation(error: YooKassaPaymentsError?) {
        let err: NSDictionary = [
            "code": "E_CONFIRMATION_FAILED",
            "message": error?.localizedDescription ?? "Confirmation failed."
        ]

        DispatchQueue.main.async { self.dismiss() }

        confirmCallback?([NSNull(), err])
        confirmCallback = nil
    }
}
