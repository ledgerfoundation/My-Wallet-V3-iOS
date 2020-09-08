//
//  CheckoutScreenPresenter.swift
//  Blockchain
//
//  Created by AlexM on 1/23/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Localization
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxRelay
import RxSwift
import ToolKit

final class CheckoutScreenPresenter: DetailsScreenPresenterAPI {
    
    // MARK: - Types
    
    private typealias AnalyticsEvent = AnalyticsEvents.SimpleBuy
    private typealias LocalizedString = LocalizationConstants.SimpleBuy.Checkout

    // MARK: - Navigation Properties

    let reloadRelay: PublishRelay<Void> = .init()

    var navigationBarAppearance: DetailsScreen.NavigationBarAppearance = .defaultDark

    let titleViewRelay: BehaviorRelay<Screen.Style.TitleView> = .init(value: .none)

    // MARK: - Screen Properties

    let buttons: [ButtonViewModel]

    var cells: [DetailsScreen.CellType] {
        contentReducer.cells
    }

    // MARK: - Injected
    
    private let analyticsRecorder: AnalyticsEventRecorderAPI
    private let uiUtilityProvider: UIUtilityProviderAPI
    private let interactor: CheckoutScreenInteractor
    private let checkoutRouting: CheckoutRoutingInteracting

    // MARK: - Private Properties
    
    private let disposeBag = DisposeBag()
    private let contentReducer: CheckoutScreenContentReducing

    // MARK: - Setup
    
    init(checkoutRouting: CheckoutRoutingInteracting,
         contentReducer: CheckoutScreenContentReducing,
         uiUtilityProvider: UIUtilityProviderAPI = UIUtilityProvider.default,
         analyticsRecorder: AnalyticsEventRecorderAPI,
         interactor: CheckoutScreenInteractor) {
        self.analyticsRecorder = analyticsRecorder
        self.checkoutRouting = checkoutRouting
        self.uiUtilityProvider = uiUtilityProvider
        self.interactor = interactor
        self.contentReducer = contentReducer

        // MARK: Nav Bar

        titleViewRelay.accept(.text(value: contentReducer.title))

        // MARK: Buttons Setup

        buttons = [
            contentReducer.continueButtonViewModel,
            contentReducer.cancelButtonViewModel
            ]
            .compactMap { $0 }

        contentReducer.continueButtonViewModel
            .tapRelay
            .show(loader: uiUtilityProvider.loader, style: .circle)
            .flatMap(weak: self) { (self, _) in
                self.interactor.continue()
                    .mapToResult()
            }
            .hide(loader: uiUtilityProvider.loader)
            .bindAndCatch(weak: self) { (self, result) in
                switch result {
                case .success(let data):
                    self.checkoutRouting.actionRelay.accept(.confirm(data.0, isOrderNew: data.1))
                case .failure:
                    self.uiUtilityProvider.alert.error(in: nil, action: nil)
                }
            }
            .disposed(by: disposeBag)

        contentReducer.cancelButtonViewModel?
            .tapRelay
            .bindAndCatch(weak: self) { (self) in
                self.cancel()
            }
            .disposed(by: disposeBag)

        contentReducer.transferDetailsButtonViewModel?
            .tapRelay
            .withLatestFrom(Observable.just(interactor.checkoutData))
            .map { .bankTransferDetails($0) }
            .bindAndCatch(to: checkoutRouting.actionRelay)
            .disposed(by: disposeBag)
    }

    /// Should get called once, when the view has finished loading
    func viewDidLoad() {
        interactor.setup()
            .handleLoaderForLifecycle(loader: uiUtilityProvider.loader, style: .circle)
            .subscribe(
                onSuccess: { [weak self] data in
                    guard let self = self else { return }
                    self.analyticsRecorder.record(
                        event: AnalyticsEvent.sbCheckoutShown(paymentMethod: data.paymentMethod.analyticsParameter)
                    )
                    self.contentReducer.setupDidSucceed(with: data)
                },
                onError: { [weak self] _ in
                    self?.setupDidFail()
                }
            )
            .disposed(by: disposeBag)
    }

    private func cancel() {
        if interactor.checkoutData.isPendingDepositBankWire {
            checkoutRouting.actionRelay.accept(.cancel(interactor.checkoutData))
        } else {
            interactor.cancelIfPossible()
                .handleLoaderForLifecycle(loader: uiUtilityProvider.loader, style: .circle)
                .subscribe(
                    onSuccess: { [weak self] wasCancelled in
                        guard let self = self else { return }
                        if wasCancelled {
                            self.analyticsRecorder.record(event: AnalyticsEvent.sbCheckoutCancelGoBack)
                        }
                        self.checkoutRouting.previousRelay.accept(())
                    }
                )
                .disposed(by: disposeBag)
        }
    }
    
    // MARK: - Navigation

    var navigationBarLeadingButtonAction: DetailsScreen.BarButtonAction {
        .custom { [weak self] in
            self?.cancel()
        }
    }

    var navigationBarTrailingButtonAction: DetailsScreen.BarButtonAction {
        .custom { [weak self] in
            self?.checkoutRouting.previousRelay.accept(())
        }
    }
    
    /// Is called as the interaction setup fails
    private func setupDidFail() {
        uiUtilityProvider.alert.error(in: nil) { [weak self] in
            self?.cancel()
        }
    }
}
