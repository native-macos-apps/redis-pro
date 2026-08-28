//
//  Messages.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/29.
//

import Foundation
import Cocoa
import Logging

/// Thread-safe alert helpers.
/// All methods dispatch work on the main actor to avoid race conditions
/// that occurred with the old static `NSAlert` singletons.
@MainActor
class Messages {

    private static let logger = Logger(label: "alert")

    // MARK: - Confirm (callback-based)

    static func confirm(
        _ title: String,
        message: String = "",
        primaryButton: String = "Ok",
        action: @escaping () async -> Void
    ) {
        let alert = makeConfirmAlert(title: title, message: message, primaryButton: primaryButton)
        guard let window = NSApplication.shared.keyWindow else { return }

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            logger.info("alert ok action")
            Task { await action() }
        }
    }

    // MARK: - Confirm (async / await)

    static func confirmAsync(
        _ title: String,
        message: String = "",
        primaryButton: String = "Ok"
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = makeConfirmAlert(title: title, message: message, primaryButton: primaryButton)
            guard let window = NSApplication.shared.keyWindow else {
                continuation.resume(returning: false)
                return
            }
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }

    // MARK: - Error / Info

    static func show(_ title: String) {
        let alert = NSAlert()
        alert.messageText = StringHelper.ellipses(title, len: 200)
        alert.addButton(withTitle: "Ok")
        alert.alertStyle = .warning
        alert.runModal()
    }

    static func show(_ error: Error) {
        let message: String
        if let biz = error as? BizError {
            message = biz.message
        } else {
            message = "\(error)"
        }
        show(message)
    }

    // MARK: - Private helpers

    private static func makeConfirmAlert(
        title: String,
        message: String,
        primaryButton: String
    ) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = StringHelper.ellipses(title, len: 100)
        alert.informativeText = StringHelper.ellipses(message, len: 200)
        alert.alertStyle = .warning
        alert.addButton(withTitle: primaryButton)
        alert.addButton(withTitle: "Cancel")
        return alert
    }
}
