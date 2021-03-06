//
//  QRCodeScannerFlashService.swift
//  Blockchain
//
//  Created by Alex McGregor on 2/9/21.
//  Copyright © 2021 Blockchain Luxembourg S.A. All rights reserved.
//

import RxCocoa
import RxSwift

/// Simple service for enabling and disabling the flash on the users
/// camera. Useful in dark settings. 
final class QRCodeScannerFlashService {
    
    /// Is the flash enabled
    var isEnabled: Driver<Bool> {
        isEnabledRelay.asDriver()
    }
    
    /// Whether or not the flash is enabled
    let isEnabledRelay = BehaviorRelay(value: false)
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // no-op
        }
        isEnabledRelay.accept(device.torchMode == .on)
    }
}
