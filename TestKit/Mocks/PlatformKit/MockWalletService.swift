//
//  MockWalletService.swift
//  BlockchainTests
//
//  Created by Chris Arriola on 6/13/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift

class MockWalletService: WalletOptionsAPI {
    
    let message: String?
    
    var serverUnderMaintenanceMessage: Single<String?> {
        Single.just(message)
    }

    var mockWalletOptions: WalletOptions?

    var walletOptions: Single<WalletOptions> {
        if let mockWalletOptions = mockWalletOptions {
            return Single.just(mockWalletOptions)
        }
        return Single.just(WalletOptions(json: ["maintenance": false]))
    }
    
    init(message: String? = nil) {
        self.message = message
    }
}
