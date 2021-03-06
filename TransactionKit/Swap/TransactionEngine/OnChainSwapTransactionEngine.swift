//
//  OnChainSwapTransactionEngine.swift
//  TransactionKit
//
//  Created by Paulo on 18/11/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import RxSwift
import ToolKit

final class OnChainSwapTransactionEngine: SwapTransactionEngine {

    let receiveAddressFactory: CryptoReceiveAddressFactoryService
    let fiatCurrencyService: FiatCurrencyServiceAPI
    let kycTiersService: KYCTiersServiceAPI
    let onChainEngine: OnChainTransactionEngine
    let orderCreationService: OrderCreationServiceAPI
    var orderDirection: OrderDirection {
        target is TradingAccount ? .fromUserKey : .onChain
    }
    let orderQuoteService: OrderQuoteServiceAPI
    let orderUpdateService: OrderUpdateServiceAPI
    let priceService: PriceServiceAPI
    let quotesEngine: SwapQuotesEngine
    let requireSecondPassword: Bool
    let tradeLimitsService: TradeLimitsAPI
    var askForRefreshConfirmation: ((Bool) -> Completable)!
    var sourceAccount: CryptoAccount!
    var transactionTarget: TransactionTarget!

    init(quotesEngine: SwapQuotesEngine,
         requireSecondPassword: Bool,
         onChainEngine: OnChainTransactionEngine,
         orderQuoteService: OrderQuoteServiceAPI = resolve(),
         orderCreationService: OrderCreationServiceAPI = resolve(),
         orderUpdateService: OrderUpdateServiceAPI = resolve(),
         tradeLimitsService: TradeLimitsAPI = resolve(),
         fiatCurrencyService: FiatCurrencyServiceAPI = resolve(),
         kycTiersService: KYCTiersServiceAPI = resolve(),
         priceService: PriceServiceAPI = resolve(),
         receiveAddressFactory: CryptoReceiveAddressFactoryService = resolve()) {
        self.quotesEngine = quotesEngine
        self.requireSecondPassword = requireSecondPassword
        self.orderQuoteService = orderQuoteService
        self.orderCreationService = orderCreationService
        self.orderUpdateService = orderUpdateService
        self.tradeLimitsService = tradeLimitsService
        self.fiatCurrencyService = fiatCurrencyService
        self.kycTiersService = kycTiersService
        self.priceService = priceService
        self.onChainEngine = onChainEngine
        self.receiveAddressFactory = receiveAddressFactory
    }

    private func startOnChainEngine(pricedQuote: PricedQuote) -> Completable {
        do {
            let transactionTarget = try receiveAddressFactory.makeExternalAssetAddress(
                asset: sourceAsset,
                address: pricedQuote.sampleDepositAddress,
                label: pricedQuote.sampleDepositAddress,
                onTxCompleted: { _ in .empty() }
            )
            onChainEngine.start(
                sourceAccount: sourceAccount,
                transactionTarget: transactionTarget,
                askForRefreshConfirmation: { _ in .empty() }
            )
            return .just(event: .completed)
        } catch let error {
            return .just(event: .error(error))
        }
    }

    func validateAmount(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        onChainEngine.validateAmount(pendingTransaction: pendingTransaction)
            .flatMap(weak: self) { (self, pendingTransaction) -> Single<PendingTransaction> in
                switch pendingTransaction.validationState {
                case .canExecute, .invalidAmount:
                    return self.defaultValidateAmount(pendingTransaction: pendingTransaction)
                default:
                    return .just(pendingTransaction)
                }
            }
            .updateTxValiditySingle(pendingTransaction: pendingTransaction)
    }

    func initializeTransaction() -> Single<PendingTransaction> {
        quotesEngine
            .getRate(direction: orderDirection, pair: pair)
            .take(1)
            .asSingle()
            .flatMap(weak: self) { (self, pricedQuote) -> Single<PendingTransaction> in
                self.startOnChainEngine(pricedQuote: pricedQuote)
                    .andThen(
                        Single.zip(
                            self.fiatCurrencyService.fiatCurrency,
                            self.onChainEngine.initializeTransaction()
                        )
                    )
                    .flatMap(weak: self) { (self, payload) -> Single<PendingTransaction> in
                        let (fiatCurrency, pendingTransaction) = payload
                        let fallback = PendingTransaction(
                            amount: CryptoValue.zero(currency: self.sourceAsset).moneyValue,
                            available: CryptoValue.zero(currency: self.targetAsset).moneyValue,
                            fees: CryptoValue.zero(currency: self.targetAsset).moneyValue,
                            feeLevel: .none,
                            selectedFiatCurrency: fiatCurrency
                        )
                        return self.updateLimits(
                            pendingTransaction: pendingTransaction,
                            pricedQuote: pricedQuote,
                            fiatCurrency: fiatCurrency
                        )
                        .map { pendingTransaction -> PendingTransaction in
                            var pendingTransaction = pendingTransaction
                            pendingTransaction.feeLevel = .priority
                            return pendingTransaction
                        }
                        .handleSwapPendingOrdersError(initialValue: fallback)
                    }
            }
    }

    func doValidateAll(pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        onChainEngine
            .doValidateAll(pendingTransaction: pendingTransaction)
            .flatMap(weak: self) { (self, pendingTransaction) -> Single<PendingTransaction> in
                switch pendingTransaction.validationState {
                case .canExecute, .invalidAmount:
                    return self.defaultDoValidateAll(pendingTransaction: pendingTransaction)
                default:
                    return .just(pendingTransaction)
                }
            }
            .updateTxValiditySingle(pendingTransaction: pendingTransaction)
    }

    func execute(pendingTransaction: PendingTransaction, secondPassword: String) -> Single<TransactionResult> {
        createOrder(pendingTransaction: pendingTransaction)
            .flatMap(weak: self) { (self, swapOrder) -> Single<TransactionResult> in
                guard let depositAddress = swapOrder.depositAddress else {
                    throw PlatformKitError.illegalStateException(message: "Missing deposit address")
                }
                let transactionTarget = try self.receiveAddressFactory
                    .makeExternalAssetAddress(
                        asset: self.sourceAsset,
                        address: depositAddress,
                        label: depositAddress,
                        onTxCompleted: { _ in .empty() }
                    )
                return self.onChainEngine
                    .restart(transactionTarget: transactionTarget, pendingTransaction: pendingTransaction)
                    .flatMap(weak: self) { (self, pendingTransaction) -> Single<TransactionResult> in
                        self.onChainEngine
                            .execute(pendingTransaction: pendingTransaction, secondPassword: secondPassword)
                            .catchError(weak: self) { (self, error) -> Single<TransactionResult> in
                                self.orderUpdateService
                                    .updateOrder(identifier: swapOrder.identifier, success: false)
                                    .catchError { _ in .empty() }
                                    .andThen(.error(error))
                            }
                            .flatMap(weak: self) { (self, result) -> Single<TransactionResult> in
                                self.orderUpdateService
                                    .updateOrder(identifier: swapOrder.identifier, success: true)
                                    .catchError { _ in .empty() }
                                    .andThen(.just(result))
                            }
                    }
            }
    }

    func update(amount: MoneyValue, pendingTransaction: PendingTransaction) -> Single<PendingTransaction> {
        validateUpdateAmount(amount)
            .flatMap(weak: self) { (self, amount) -> Single<PendingTransaction> in
                self.onChainEngine
                    .update(amount: amount, pendingTransaction: pendingTransaction)
                    .do(onSuccess: { pendingTransaction in
                        self.quotesEngine.updateAmount(pendingTransaction.amount.amount)
                    })
                    .map(weak: self) { (self, pendingTransaction) -> PendingTransaction in
                        self.clearConfirmations(pendingTransaction: pendingTransaction)
                    }
            }
    }
}
