//
//  QuickIconsApp.swift
//  QuickIcons
//
//  Created by Natik Gadzhi on 4/19/26.
//

import SwiftUI

@main
struct QuickIconsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRouterView()
        }
    }
}
