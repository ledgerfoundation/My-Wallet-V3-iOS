//
//  WebLoginService.swift
//  Blockchain
//
//  Created by Paulo on 23/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxCocoa
import ToolKit
import NetworkKit
import PlatformKit
import CommonCryptoKit

protocol WebLoginQRCodeServiceAPI: class {
    var qrCode: Single<String> { get }
}

final class WebLoginQRCodeService: WebLoginQRCodeServiceAPI {

    // MARK: - Types

    enum ServiceError: Error {
        case missingPassword
    }

    // MARK: - Public Properties

    var qrCode: Single<String> {
        guid
            .flatMap(weak: self) { (self, guid) -> Single<String> in
                self.qrCode(guid: guid)
            }
    }

    // MARK: - Private Properties

    private let autoPairing: AutoWalletPairingClientAPI
    private let walletCryptoService: WalletCryptoServiceAPI
    private let walletRepository: WalletRepositoryAPI

    // MARK: - Setup

    public init(
        autoPairing: AutoWalletPairingClientAPI = AutoWalletPairingClient(),
        walletCryptoService: WalletCryptoServiceAPI = WalletCryptoService(jsContextProvider: WalletManager.shared),
        walletRepository: WalletRepositoryAPI = WalletManager.shared.repository
    ) {
        self.autoPairing = autoPairing
        self.walletCryptoService = walletCryptoService
        self.walletRepository = walletRepository
    }

    private var guid: Single<String> {
        walletRepository
            .guid
            .map(weak: self) { (self, guid: String?) -> String in
                guard let guid = guid else {
                    throw MissingCredentialsError.guid
                }
                return guid
            }
    }

    private func qrCode(guid: String) -> Single<String> {
        autoPairing
            .request(guid: guid)
            .flatMap(weak: self) { (self, encryptionPhrase) -> Single<String> in
                self.encrypteWalletData(with: encryptionPhrase)
            }
            .map { "1|\(guid)|\($0)" }
    }

    private func encrypteWalletData(with encryptionPhrase: String) -> Single<String> {
        Single
            .zip(
                walletRepository.password,
                walletRepository.sharedKey
            )
            .map { (password, sharedKey) -> (String, String) in
                guard let password = password else {
                    throw ServiceError.missingPassword
                }
                guard let sharedKey = sharedKey else {
                    throw MissingCredentialsError.sharedKey
                }
                return (password, sharedKey)
            }
            .map { (password, sharedKey) -> String in
                guard let hexPassword = password.data(using: .utf8)?.hexValue else {
                    throw ServiceError.missingPassword
                }
                return "\(sharedKey)|\(hexPassword)"
            }
            .flatMap(weak: self) { (self, data) in
                self.walletCryptoService.encrypt(pair: KeyDataPair(key: encryptionPhrase, data: data),
                                                 pbkdf2Iterations: WalletCryptoPBKDF2Iterations.autoPair)
            }
    }
}
