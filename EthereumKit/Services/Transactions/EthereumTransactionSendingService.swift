//
//  EthereumPlatformService.swift
//  EthereumKit
//
//  Created by Jack on 28/03/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
import DIKit
import PlatformKit
import RxSwift

public enum EthereumTransactionCreationServiceError: Error {
    case transactionHashingError
    case nullReferenceError
}

protocol EthereumTransactionSendingServiceAPI {
    
    func send(transaction: EthereumTransactionCandidate, keyPair: EthereumKeyPair) -> Single<EthereumTransactionPublished>
}

final class EthereumTransactionSendingService: EthereumTransactionSendingServiceAPI {
    
    typealias Bridge = EthereumWalletBridgeAPI
    
    private let bridge: Bridge
    private let client: APIClientAPI
    private let feeService: AnyCryptoFeeService<EthereumTransactionFee>
    private let transactionBuilder: EthereumTransactionBuilderAPI
    private let transactionSigner: EthereumTransactionSignerAPI
    private let transactionEncoder: EthereumTransactionEncoderAPI

    init(
        with bridge: Bridge = resolve(),
        client: APIClientAPI = resolve(),
        feeService: AnyCryptoFeeService<EthereumTransactionFee> = resolve(),
        transactionBuilder: EthereumTransactionBuilderAPI = resolve(),
        transactionSigner: EthereumTransactionSignerAPI = resolve(),
        transactionEncoder: EthereumTransactionEncoderAPI = resolve()) {
        self.bridge = bridge
        self.client = client
        self.feeService = feeService
        self.transactionBuilder = transactionBuilder
        self.transactionSigner = transactionSigner
        self.transactionEncoder = transactionEncoder
    }
    
    func send(transaction: EthereumTransactionCandidate, keyPair: EthereumKeyPair) -> Single<EthereumTransactionPublished> {
        finalise(transaction: transaction, keyPair: keyPair)
            .flatMap(weak: self) { (self, transaction) -> Single<EthereumTransactionPublished> in
                self.publish(transaction: transaction)
            }
    }

    private func finalise(transaction: EthereumTransactionCandidate, keyPair: EthereumKeyPair) -> Single<EthereumTransactionFinalised> {
        bridge.nonce
            .flatMap(weak: self) { (self, nonce) -> Single<EthereumTransactionCandidateCosted> in
                self.transactionBuilder.build(transaction: transaction, nonce: nonce).single
            }
            .flatMap(weak: self) { (self, costed) -> Single<EthereumTransactionCandidateSigned> in
                self.transactionSigner.sign(transaction: costed, keyPair: keyPair).single
            }
            .flatMap(weak: self) { (self, signedTransaction) -> Single<EthereumTransactionFinalised> in
                self.transactionEncoder.encode(signed: signedTransaction).single
            }
    }

    private func publish(transaction: EthereumTransactionFinalised) -> Single<EthereumTransactionPublished> {
        client.push(transaction: transaction)
            .flatMap { response in
                let publishedTransaction = try EthereumTransactionPublished(
                    finalisedTransaction: transaction,
                    responseHash: response.txHash
                )
                return Single.just(publishedTransaction)
            }
    }
}

