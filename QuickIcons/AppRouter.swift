//
//  AppRouter.swift
//  QuickIcons
//

import SwiftUI

// MARK: - Toolchain state

/// Tracks the result of the toolchain availability probe.
@MainActor
enum ToolchainState {
    /// The probe is still running.
    case checking
    /// A usable Swift toolchain was found.
    case available
    /// No usable Swift toolchain was found; `reason` explains what went wrong.
    case unavailable(reason: String)
}

// MARK: - App router view model

/// Owns the toolchain state and drives the root router view.
@MainActor
@Observable
final class AppRouter {
    var toolchainState: ToolchainState = .checking

    private let runner: ProcessRunner

    init(runner: @escaping ProcessRunner = defaultProcessRunner) {
        self.runner = runner
    }

    /// Kicks off the toolchain probe. Safe to call multiple times (each call re-runs the check).
    func checkToolchain() {
        toolchainState = .checking
        Task {
            let (available, reason) = await probeToolchain(runner: runner)
            if available {
                toolchainState = .available
            } else {
                toolchainState = .unavailable(reason: reason ?? "Unknown error.")
            }
        }
    }
}

// MARK: - Root router view

/// Selects which top-level view to display based on `ToolchainState`.
struct AppRouterView: View {
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch router.toolchainState {
            case .checking:
                CheckingView()
            case .available:
                ContentView()
            case .unavailable(let reason):
                ToolchainUnavailableView(reason: reason) {
                    router.checkToolchain()
                }
            }
        }
        .onAppear {
            router.checkToolchain()
        }
    }
}

// MARK: - Checking view

private struct CheckingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Checking Swift toolchain…")
                .foregroundStyle(.secondary)
        }
        .frame(width: 400, height: 260)
    }
}
