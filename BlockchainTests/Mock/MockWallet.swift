//
//  MockWallet.swift
//  BlockchainTests
//
//  Created by Chris Arriola on 4/30/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

@testable import Blockchain

class MockWallet: Wallet {

    var mockIsInitialized: Bool = false

    override func isInitialized() -> Bool {
        mockIsInitialized
    }

    /// When called, invokes the delegate's walletDidDecrypt and walletDidFinishLoad methods
    override func load(withGuid guid: String, sharedKey: String?, password: String?) {
        self.delegate?.walletDidDecrypt?(withSharedKey: sharedKey, guid: guid)
        self.delegate?.walletDidFinishLoad?()
    }
}
