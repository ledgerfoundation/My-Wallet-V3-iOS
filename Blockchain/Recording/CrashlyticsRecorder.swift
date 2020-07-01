//
//  CrashlyticsRecorder.swift
//  Blockchain
//
//  Created by Daniel Huri on 24/06/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import FirebaseCrashlytics
import Foundation
import PlatformKit
import ToolKit

/// Crashlytics implementation of `Recording`. Should be injected as a service.
final class CrashlyticsRecorder: Recording {

    // MARK: - Properties
    
    private let crashlytics: Crashlytics
    
    // MARK: - Setup
    
    init(crashlytics: Crashlytics = Crashlytics.crashlytics()) {
        self.crashlytics = crashlytics
    }
    
    // MARK: - ErrorRecording
    
    /// Records error using Crashlytics.
    /// If the only necessary recording data is the context, just call `error()` with no `error` parameter.
    /// - Parameter error: The error to be recorded by the crash service. defaults to `BreadcrumbError` instance.
    func error(_ error: Error) {
        crashlytics.record(error: error as NSError)
    }

    // MARK: - MessageRecording
    
    /// Records any type of message.
    /// - Parameter message: The message to be recorded by the crash service. defaults to an empty string.
    func record(_ message: String) {
        crashlytics.log(message)
    }

    // MARK: - UIOperationRecording
    
    /// Should be called if there is a suspicion that a UI action is performed on a background thread.
    /// In such case, a non-fatal error will be recorded.
    func recordIllegalUIOperationIfNeeded() {
        guard !Thread.isMainThread else {
            return
        }

        error(UIOperationError.changingUIOnBackgroundThread)
    }
}
