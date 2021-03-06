//
//  SellOrderDetails.swift
//  BuySellKit
//
//  Created by Alex McGregor on 8/31/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
import PlatformKit
import ToolKit

public struct SellOrderDetails {
    
    public typealias State = OrderDetailsState
    
    public let fiatValue: FiatValue
    public let cryptoValue: CryptoValue
    
    public var price: FiatValue?
    public var fee: FiatValue?
    
    public let identifier: String
    
    public let paymentMethod: PaymentMethod.MethodType

    public let creationDate: Date?
    
    public let state: State
    
    // MARK: - Setup
    
    init?(recorder: AnalyticsEventRecording, response: OrderPayload.Response) {
        guard let state = State(rawValue: response.state) else {
            return nil
        }
        guard let fiatCurrency = FiatCurrency(code: response.outputCurrency) else {
            return nil
        }
        guard let cryptoCurrency = CryptoCurrency(rawValue: response.inputCurrency) else {
            return nil
        }
        
        guard let cryptoValue = CryptoValue.create(minor: response.inputQuantity, currency: cryptoCurrency) else {
            return nil
        }
        guard let fiatValue = FiatValue.create(minor: response.outputQuantity, currency: fiatCurrency) else {
            return nil
        }
        
        guard let paymentType = PaymentMethodPayloadType(rawValue: response.paymentType) else {
            return nil
        }
        
        identifier = response.id
        
        self.fiatValue = fiatValue
        self.cryptoValue = cryptoValue
        self.state = state
        self.paymentMethod = PaymentMethod.MethodType(type: paymentType, currency: .fiat(fiatCurrency))
        
        if let price = response.price {
            self.price = FiatValue.create(minor: price, currency: fiatCurrency)
        }
        
        if let fee = response.fee {
            self.fee = FiatValue.create(minor: fee, currency: fiatCurrency)
        }

        creationDate = DateFormatter.utcSessionDateFormat.date(from: response.updatedAt)
        if creationDate == nil {
            recorder.record(event: AnalyticsEvents.DebugEvent.updatedAtParsingError(date: response.updatedAt))
        }
    }
}
