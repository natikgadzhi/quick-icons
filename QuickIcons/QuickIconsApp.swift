//
//  QuickIconsApp.swift
//  QuickIcons
//
//  Created by Natik Gadzhi on 4/19/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct QuickIconsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRouterView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    openSwiftFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    /// Presents an NSOpenPanel for .swift files and, on success, posts an
    /// openSwiftFileNotification so EditorView can replace its source code.
    private func openSwiftFile() {
        let panel = NSOpenPanel()
        panel.title = "Open Swift File"
        panel.prompt = "Open"
        panel.message = "Choose a Swift source file to load into the editor."
        panel.allowedContentTypes = [.swiftSource]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let source = try readSwiftSource(at: url)
            NotificationCenter.default.post(
                name: .openSwiftFileNotification,
                object: nil,
                userInfo: [OpenSwiftFileNotification.sourceKey: source]
            )
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could Not Open File"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Open file notification

/// Namespace for the notification posted when a Swift file is successfully opened.
enum OpenSwiftFileNotification {
    static let sourceKey = "source"
}

extension Notification.Name {
    static let openSwiftFileNotification = Notification.Name("QuickIcons.OpenSwiftFile")
}
