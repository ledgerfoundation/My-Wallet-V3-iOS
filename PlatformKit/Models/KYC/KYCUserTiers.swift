//
//  KYCUserTiers.swift
//  Blockchain
//
//  Created by kevinwu on 12/12/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

extension KYC {
    public struct UserTiers: Decodable {
        public let tiers: [KYC.UserTier]

        /// `true` in case the user has a verified GOLD tier.
        public var isTier2Approved: Bool {
            latestApprovedTier == .tier2
        }
        
        public init(tiers: [KYC.UserTier]) {
            self.tiers = tiers
        }

        /// Returns the KYC.AccountStatus for the given KYC.Tier
        public func tierAccountStatus(for tier: KYC.Tier) -> KYC.AccountStatus {
            tiers
                .first(where: { $0.tier == tier })
                .flatMap { $0.state.accountStatus } ?? .none
        }
        
        /// Returns the latest tier, approved OR in progress (pending || in-review)
        public var latestTier: KYC.Tier {
            guard tierAccountStatus(for: .tier1).isInProgressOrApproved else {
                return .tier0
            }
            guard tierAccountStatus(for: .tier2).isInProgressOrApproved else {
                return .tier1
            }
            return .tier2
        }
        
        /// Returns the latest approved tier
        public var latestApprovedTier: KYC.Tier {
            guard tierAccountStatus(for: .tier1).isApproved else {
                return .tier0
            }
            guard tierAccountStatus(for: .tier2).isApproved else {
                return .tier1
            }
            return .tier2
        }

        /// Returns `true` if the user is not tier2 verified, rejected or pending
        public var canCompleteTier2: Bool {
            tiers.contains(where: {
                $0.tier == .tier2 &&
                    ($0.state != .pending && $0.state != .rejected && $0.state != .verified)
            })
        }
    }
}

fileprivate extension KYC.Tier.State {
    var accountStatus: KYC.AccountStatus {
        switch self {
        case .none:
            return .none
        case .rejected:
            return .failed
        case .pending:
            return .pending
        case .verified:
            return .approved
        }
    }
}
