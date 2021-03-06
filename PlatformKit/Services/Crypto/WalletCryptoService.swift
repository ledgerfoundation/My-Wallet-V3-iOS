//
//  WalletCryptoService.swift
//  PlatformKit
//
//  Created by Daniel Huri on 17/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import RxSwift
import ToolKit
import WalletPayloadKit

public enum WalletCryptoPBKDF2Iterations {
    /// Used for Auto Pair QR code decryption/encryption
    public static let autoPair: Int = 10
    /// This does not need to be large because the key is already 256 bits
    public static let pinLogin: Int = 1
}

public protocol WalletCryptoServiceAPI: class {
    func decrypt(pair: KeyDataPair<String, String>, pbkdf2Iterations: Int) -> Single<String>
    func encrypt(pair: KeyDataPair<String, String>, pbkdf2Iterations: Int) -> Single<String>
}

final class WalletCryptoService: WalletCryptoServiceAPI {

    // MARK: - Types

    enum ServiceError: Error {
        case emptyResult
        case failed
    }

    private enum JSMethod: String {
        case decrypt = "WalletCrypto.decrypt(\"%@\", \"%@\", %ld)"
        case encrypt = "WalletCrypto.encrypt(\"%@\", \"%@\", %ld)"
    }

    // MARK: - Properties
    
    private let jsContextProvider: JSContextProviderAPI
    private let payloadCryptor: WalletPayloadCryptorAPI
    private let recorder: Recording
    
    // MARK: - Setup

    init(contextProvider: JSContextProviderAPI = resolve(),
         payloadCryptor: WalletPayloadCryptorAPI = resolve(),
         recorder: Recording = resolve(tag: "CrashlyticsRecorder")) {
        self.jsContextProvider = contextProvider
        self.payloadCryptor = payloadCryptor
        self.recorder = recorder
    }
    
    // MARK: - Public methods

    /// Receives a `KeyDataPair` and decrypt `data` using `key`
    /// - Parameter pair: A pair of key and data used in the decription process.
    public func decrypt(pair: KeyDataPair<String, String>, pbkdf2Iterations: Int) -> Single<String> {
        decryptNative(pair: pair, pbkdf2Iterations: UInt32(pbkdf2Iterations)).single
            .catchError(weak: self) { (self, error) -> Single<String> in
                self.decryptJS(pair: pair, pbkdf2Iterations: UInt32(pbkdf2Iterations))
                    .do(onSuccess: { _ in
                        // For now log the error only
                        self.recorder.error(error)
                        // Later we should crash if JS decryption succeeds but native decryption fails
                        // fatalError(error.localizedDescription)
                    })
            }
    }
    
    /// Receives a `KeyDataPair` and encrypt `data` using `key`.
    /// - Parameter pair: A pair of key and data used in the encription process.
    public func encrypt(pair: KeyDataPair<String, String>, pbkdf2Iterations: Int) -> Single<String> {
        encryptNative(pair: pair, pbkdf2Iterations: UInt32(pbkdf2Iterations)).single
    }

    // MARK: - Private methods
    
    private func encryptNative(pair: KeyDataPair<String, String>, pbkdf2Iterations: UInt32) -> Result<String, WalletCryptoError> {
        payloadCryptor
            .encrypt(pair: pair, pbkdf2Iterations: pbkdf2Iterations)
            .mapError { _ in WalletCryptoError.unknown }
    }
    
    private func decryptNative(pair: KeyDataPair<String, String>, pbkdf2Iterations: UInt32) -> Result<String, WalletCryptoError> {
        payloadCryptor
            .decrypt(pair: pair, pbkdf2Iterations: pbkdf2Iterations)
            .mapError { _ in WalletCryptoError.unknown }
    }
    
    private func decryptJS(pair: KeyDataPair<String, String>, pbkdf2Iterations: UInt32) -> Single<String> {
        Single.create(weak: self) { (self, observer) -> Disposable in
            do {
                let result = try self.jsCrypto(
                    .decrypt,
                    data: pair.data,
                    key: pair.key,
                    iterations: Int(pbkdf2Iterations)
                )
                observer(.success(result))
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
        .subscribeOn(MainScheduler.instance)
    }
    
    private func encryptJS(pair: KeyDataPair<String, String>, pbkdf2Iterations: Int) -> Single<String> {
        Single.create(weak: self) { (self, observer) -> Disposable in
            do {
                let result = try self.jsCrypto(
                    .encrypt,
                    data: pair.data,
                    key: pair.key,
                    iterations: pbkdf2Iterations
                )
                observer(.success(result))
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
        .subscribeOn(MainScheduler.instance)
    }
    
    private func jsCrypto(_ method: JSMethod,
                          data: String,
                          key: String,
                          iterations: Int) throws -> String {
        let data = data.escapedForJS()
        let key = key.escapedForJS()
        let script = String(format: method.rawValue, data, key, iterations)
        guard let result = jsContextProvider.jsContext.evaluateScript(script)?.toString() else {
            throw ServiceError.failed
        }
        guard !result.isEmpty else {
            throw ServiceError.emptyResult
        }
        return result
    }
}
