//
//  AmountTranslationView.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 08/06/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxCocoa
import RxRelay
import RxSwift
import ToolKit

public final class AmountTranslationView: UIView {
    
    // MARK: - Types
    
    private struct AmountLabelConstraints {
        var top: [NSLayoutConstraint]
        var bottom: [NSLayoutConstraint]
        
        init(top: [NSLayoutConstraint], bottom: [NSLayoutConstraint]) {
            self.top = top
            self.bottom = bottom
        }
        
        func activate() {
            top.forEach { $0.priority = .penultimateHigh }
            bottom.forEach { $0.priority = .penultimateLow }
        }
        
        func deactivate() {
            top.forEach { $0.priority = .penultimateLow }
            bottom.forEach { $0.priority = .penultimateHigh }
        }
    }
    
    // MARK: - Properties
    
    private let fiatAmountLabelView = AmountLabelView()
    private let cryptoAmountLabelView = AmountLabelView()
    private let auxiliaryButton = ButtonView()
    private let swapButton = UIButton()

    private let presenter: AmountTranslationPresenter
    
    private let disposeBag = DisposeBag()
        
    private var fiatLabelConstraints: AmountLabelConstraints!
    private var cryptoLabelConstraints: AmountLabelConstraints!

    // MARK: - Init

    @available(*, unavailable)
    public required init?(coder: NSCoder) { unimplemented() }

    public init(presenter: AmountTranslationPresenter) {
        self.presenter = presenter
        super.init(frame: UIScreen.main.bounds)
                
        fiatAmountLabelView.presenter = presenter.fiatPresenter.presenter
        cryptoAmountLabelView.presenter = presenter.cryptoPresenter.presenter
        
        func setupConstraints(for amountLabelView: UIView, isActive: Bool) -> AmountLabelConstraints {
             
            amountLabelView.layoutToSuperview(.centerX)
            amountLabelView.layout(dimension: .height, to: 48)
            
            let topPriority: UILayoutPriority = isActive ? .penultimateHigh : .penultimateLow
            let topLeadingConstraint = amountLabelView.layoutToSuperview(
                .leading,
                relation: .greaterThanOrEqual,
                offset: 24,
                priority: topPriority
            )!
            let topTrailingConstraint = amountLabelView.layoutToSuperview(
                .trailing,
                relation: .lessThanOrEqual,
                offset: -24,
                priority: topPriority
            )!
            let topVerticalConstraint = amountLabelView.layout(
                edge: .bottom,
                to: .centerY,
                of: self,
                priority: topPriority
            )!

            let top = [
                topLeadingConstraint,
                topTrailingConstraint,
                topVerticalConstraint
            ]
            
            let bottomPriority: UILayoutPriority = isActive ? .penultimateLow : .penultimateHigh
            let bottomLeadingConstraint = amountLabelView.layoutToSuperview(
                .leading,
                relation: .greaterThanOrEqual,
                offset: 24,
                priority: topPriority
            )!
            let bottomTrailingConstraint = amountLabelView.layout(
                edge: .trailing,
                to: .leading,
                of: swapButton,
                relation: .lessThanOrEqual,
                offset: -16,
                priority: topPriority
            )!
            let bottomVerticalConstraint = amountLabelView.layout(
                edge: .top,
                to: .centerY,
                of: self,
                priority: bottomPriority
            )!

            let bottom = [
                bottomLeadingConstraint,
                bottomTrailingConstraint,
                bottomVerticalConstraint
            ]
            
            return AmountLabelConstraints(top: top, bottom: bottom)
        }
        
        addSubview(fiatAmountLabelView)
        addSubview(cryptoAmountLabelView)
        addSubview(auxiliaryButton)
        addSubview(swapButton)
        
        fiatLabelConstraints = setupConstraints(for: fiatAmountLabelView, isActive: true)
        cryptoLabelConstraints = setupConstraints(for: cryptoAmountLabelView, isActive: false)
    
        cryptoLabelConstraints.bottom.append(
            swapButton.layout(
                to: .centerY,
                of: cryptoAmountLabelView,
                priority: .penultimateHigh
            )!
        )
        fiatLabelConstraints.bottom.append(
            swapButton.layout(
                to: .centerY,
                of: fiatAmountLabelView,
                priority: .penultimateLow
            )!
        )

        cryptoLabelConstraints.bottom.append(
            auxiliaryButton.layout(
                to: .centerY,
                of: cryptoAmountLabelView,
                priority: .penultimateHigh
            )!
        )
        fiatLabelConstraints.bottom.append(
            auxiliaryButton.layout(
                to: .centerY,
                of: fiatAmountLabelView,
                priority: .penultimateLow
            )!
        )

        auxiliaryButton.layoutToSuperview(.centerX)
        auxiliaryButton.layout(edge: .trailing,
                                 to: .leading,
                                 of: swapButton,
                                 relation: .lessThanOrEqual,
                                 offset: 0)
        
        let swapImage = UIImage(named: "vertical-swap-icon", in: bundle, compatibleWith: nil)
        swapButton.setImage(swapImage, for: .normal)
        swapButton.layout(size: .init(edge: 40))
        swapButton.layout(to: .trailing, of: self, offset: -16)
             
        presenter.swapButtonVisibility
            .drive(swapButton.rx.visibility)
            .disposed(by: disposeBag)
        
        swapButton.rx.tap
            .bindAndCatch(to: presenter.swapButtonTapRelay)
            .disposed(by: disposeBag)

        presenter.activeAmountInput
            .map { input -> Bool in
                input == .fiat
            }
            .drive(fiatAmountLabelView.presenter.focusRelay)
            .disposed(by: disposeBag)

        presenter.activeAmountInput
            .map { input -> Bool in
                input == .crypto
            }
            .drive(cryptoAmountLabelView.presenter.focusRelay)
            .disposed(by: disposeBag)

        presenter.activeAmountInput
            .drive(
                onNext: { [weak self] input in
                    self?.didChangeActiveInput(to: input)
                }
            )
            .disposed(by: disposeBag)
    }

    // MARK: - Public Methods

    public func connect(input: Driver<AmountTranslationPresenter.Input>) -> Driver<AmountTranslationPresenter.State> {
        Driver.combineLatest(presenter.connect(input: input), presenter.activeAmountInput)
            .map { (state: $0.0, activeAmountInput: $0.1) }
            .map { [weak self] value in
                guard let self = self else { return .empty }
                return self.performEffect(state: value.state, activeAmountInput: value.activeAmountInput)
            }
    }

    // MARK: - Private Methods

    private func performEffect(state: AmountTranslationPresenter.State,
                               activeAmountInput: ActiveAmountInput) -> AmountTranslationPresenter.State {
        let limitButtonVisibility: Visibility
        switch state {
        case .warning(let viewModel):
            auxiliaryButton.viewModel = viewModel
            limitButtonVisibility = .visible
        case .showSecondaryAmountLabel,
             .empty:
            auxiliaryButton.viewModel = nil
            limitButtonVisibility = .hidden
        }
        
        let fiatVisibility: Visibility
        let cryptoVisibility: Visibility
        switch activeAmountInput {
        case .fiat:
            fiatVisibility = .visible
            cryptoVisibility = limitButtonVisibility.inverted
        case .crypto:
            cryptoVisibility = .visible
            fiatVisibility = limitButtonVisibility.inverted
        }
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: {
                self.auxiliaryButton.alpha = limitButtonVisibility.defaultAlpha
                self.auxiliaryButton.isHidden = limitButtonVisibility.isHidden
                self.fiatAmountLabelView.alpha = fiatVisibility.defaultAlpha
                self.cryptoAmountLabelView.alpha = cryptoVisibility.defaultAlpha
            },
            completion: nil
        )
        return state
    }
    
    private func didChangeActiveInput(to newInput: ActiveAmountInput) {
        layoutIfNeeded()
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: {
                switch newInput {
                case .fiat:
                    self.fiatLabelConstraints.activate()
                    self.cryptoLabelConstraints.deactivate()
                case .crypto:
                    self.cryptoLabelConstraints.activate()
                    self.fiatLabelConstraints.deactivate()
                }
                self.layoutIfNeeded()
            },
            completion: nil
        )
    }
}
