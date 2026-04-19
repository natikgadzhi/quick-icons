//
//  AppDelegate.swift
//  QuickIcons
//
//  Ensures the window title bar is always opaque by removing the
//  fullSizeContentView style mask bit that SwiftUI sets by default.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        configureMainWindow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-apply on every activation in case SwiftUI recreates the window.
        configureMainWindow()
    }

    private func configureMainWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
    }
}
