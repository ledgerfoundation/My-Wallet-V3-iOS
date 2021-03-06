//
//  CurrencyLabeledButtonViewModel.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 22/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxCocoa
import RxRelay
import RxSwift

public final class CurrencyLabeledButtonViewModel: LabeledButtonViewModelAPI {

    // MARK: - Types
    
    private typealias AccessibilityId = Accessibility.Identifier.LabeledButtonCollectionView
    public typealias Element = MoneyValue

    // MARK: - Exposed Properties

    /// Accepts taps
    public let tapRelay = PublishRelay<Void>()

    public var elementOnTap: Signal<Element> {
        let amount = self.amount
        return tapRelay
            .asSignal()
            .map { amount }
    }

    /// Streams the content of the relay
    public var content: Driver<ButtonContent> {
        contentRelay.asDriver()
    }

    /// Determines the background color of the view
    public let backgroundColor: Color

    // MARK: - Private Properties

    private let contentRelay = BehaviorRelay<ButtonContent>(value: .empty)
    private let amount: MoneyValue

    private let disposeBag = DisposeBag()

    // MARK: - Setup

    convenience init(amount: MoneyValue,
                     suffix: String? = nil,
                     style: LabeledButtonViewStyle = .currency,
                     accessibilityId: String) {
        let amountString = amount.toDisplayString(includeSymbol: true)
        let text = [amountString, suffix].compactMap { $0 }.joined(separator: " ")
        let buttonContent = Self.buttonContent(from: style, text: text, amountString: amountString, accessibilityId: accessibilityId)
        self.init(amount: amount, style: style, buttonContent: buttonContent)
    }

    init(amount: MoneyValue,
         style: LabeledButtonViewStyle,
         buttonContent: ButtonContent) {
        self.amount = amount
        backgroundColor = style.backgroundColor
        contentRelay.accept(buttonContent)
    }
    
    private static func buttonContent(from style: LabeledButtonViewStyle,
                                      text: String,
                                      amountString: String,
                                      accessibilityId: String) -> ButtonContent {
        ButtonContent(
            text: text,
            font: style.font,
            color: style.textColor,
            backgroundColor: style.backgroundColor,
            border: style.border,
            cornerRadius: style.cornerRadius,
            accessibility: .init(
                id: .value("\(AccessibilityId.buttonPrefix)\(accessibilityId)"),
                label: .value(amountString)
            )
        )
    }
}
