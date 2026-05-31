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
            OpenFileCommand()
            BuildExportCommands()
            ViewMenuCommands()
        }
    }
}

// MARK: - Focused value: the editor's view model

/// Exposes the currently focused ``EditorViewModel`` so menu `Commands`
/// scenes can call model methods directly instead of going through
/// NotificationCenter.
struct EditorViewModelKey: FocusedValueKey {
    typealias Value = EditorViewModel
}

extension FocusedValues {
    var editorViewModel: EditorViewModel? {
        get { self[EditorViewModelKey.self] }
        set { self[EditorViewModelKey.self] = newValue }
    }
}

// MARK: - File menu

/// Replaces the default "New" item with an "Open…" command that loads a
/// Swift file into the focused editor's view model.
struct OpenFileCommand: Commands {
    @FocusedValue(\.editorViewModel) private var model

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                openSwiftFile()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(model == nil)
        }
    }

    /// Presents an NSOpenPanel for .swift files and hands the chosen URL to
    /// the focused ``EditorViewModel``.
    private func openSwiftFile() {
        guard let model else { return }

        let panel = NSOpenPanel()
        panel.title = "Open Swift File"
        panel.prompt = "Open"
        panel.message = "Choose a Swift source file to load into the editor."
        panel.allowedContentTypes = [.swiftSource]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.openFile(at: url)
    }
}

// MARK: - Build / Export menu commands

struct BuildExportCommands: Commands {
    @FocusedValue(\.editorViewModel) private var model

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()

            Button {
                guard let model else { return }
                Task { await model.compile() }
            } label: {
                Label("Build", systemImage: "play.fill")
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(model == nil)

            Button {
                model?.export()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!(model?.hasCompiledIcon ?? false))
        }
    }
}

// MARK: - View menu commands

/// Adds "Show Invisible Characters" plus Zoom controls to the View menu.
/// Each action calls the focused ``EditorViewModel`` directly.
struct ViewMenuCommands: Commands {
    @FocusedValue(\.editorViewModel) private var model

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

            // `Toggle` inside a CommandGroup renders as a checked menu item
            // on macOS. The getter reflects the focused model's current state;
            // the setter invokes `toggleInvisibles()`.
            Toggle(isOn: Binding(
                get: { model?.showsInvisibles ?? false },
                set: { _ in model?.toggleInvisibles() }
            )) {
                Text("Show Invisible Characters")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(model == nil)

            Divider()

            Button("Zoom In") {
                model?.zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(model == nil)

            Button("Zoom Out") {
                model?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(model == nil)

            Button("Actual Size") {
                model?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(model == nil)
        }
    }
}
