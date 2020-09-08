//
//  CheckoutScreenInteractor.swift
//  Blockchain
//
//  Created by AlexM on 1/23/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import BuySellKit
import PlatformKit
import RxSwift
import ToolKit

final class CheckoutScreenInteractor {
    
    // MARK: - Types
    
    enum InteractionError: Error {
        case missingInternalOrderData
        case impossibleState
    }
    
    // MARK: - Properties
    
    private(set) var checkoutData: CheckoutData
        
    // MARK: - Services
    
    private let orderCheckoutInterator: OrderCheckoutInteracting
    private let cancellationService: OrderCancellationServiceAPI
    private let confirmationService: OrderConfirmationServiceAPI
    
    // MARK: - Setup
    
    init(confirmationService: OrderConfirmationServiceAPI,
         cancellationService: OrderCancellationServiceAPI,
         orderCheckoutInterator: OrderCheckoutInteracting,
         checkoutData: CheckoutData) {
        self.orderCheckoutInterator = orderCheckoutInterator
        self.confirmationService = confirmationService
        self.cancellationService = cancellationService
        self.checkoutData = checkoutData
    }
    
    /// Performs a setup of the data
    func setup() -> Single<CheckoutInteractionData> {
        if checkoutData.order.is3DSConfirmedCardOrder || checkoutData.order.isPending3DSCardOrder {
            return orderCheckoutInterator.prepare(using: checkoutData.order)
        } else {
            return orderCheckoutInterator.prepare(using: self.checkoutData)
                .flatMap(weak: self) { (self, payload) in
                    self.set(data: payload.checkoutData)
                        .map { _ in
                            payload.interactionData
                        }
                }
        }
    }

    /// Confirms the order if needed and then continue
    /// - returns: Observable<(CheckoutData, Bool)> that emits pairs composed of a  CheckoutData
    ///  and a `Bool` flag informing if the order needed confirmation.
    func `continue`() -> Observable<(CheckoutData, Bool)> {
        if checkoutData.order.isPendingConfirmation {
            return confirmationService
                .confirm(checkoutData: checkoutData)
                .flatMap(weak: self) { (self, data) -> Single<CheckoutData> in
                    self.set(data: data)
                }
                .map { ($0, true) }
                .asObservable()
        } else {
            return .just((checkoutData, false))
        }
    }
    
    /// Cancels the order if possible
    func cancelIfPossible() -> Single<Bool> {
        if checkoutData.order.isPendingConfirmation {
            return cancellationService
                .cancel(order: checkoutData.order.identifier)
                .andThen(.just(true))
        } else {
            return .just(false)
        }
    }
    
    private func set(data: CheckoutData) -> Single<CheckoutData> {
        Single
            .create(weak: self) { (self, observer) -> Disposable in
                self.checkoutData = data
                observer(.success(data))
                return Disposables.create()
            }
    }
}
