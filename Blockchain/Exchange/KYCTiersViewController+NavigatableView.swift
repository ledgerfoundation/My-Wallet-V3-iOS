//
//  KYC.swift
//  Blockchain
//
//  Created by Paulo on 06/10/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import KYCUIKit
import PlatformUIKit

extension KYCTiersViewController: NavigatableView {

    var leftCTATintColor: UIColor {
        .white
    }

    var rightCTATintColor: UIColor {
        .white
    }

    var leftNavControllerCTAType: NavigationCTAType {
        guard let navController = navigationController else { return .dismiss }
        return navController.viewControllers.count > 1 ? .back : .dismiss
    }

    var rightNavControllerCTAType: NavigationCTAType {
        .none
    }

    var barStyle: Screen.Style.Bar {
        .lightContent()
    }

    func navControllerLeftBarButtonTapped(_ navController: UINavigationController) {
        guard let navController = navigationController else {
            dismiss(animated: true, completion: nil)
            return
        }
        navController.popViewController(animated: true)
    }

    func navControllerRightBarButtonTapped(_ navController: UINavigationController) {
        // no op
    }
}
