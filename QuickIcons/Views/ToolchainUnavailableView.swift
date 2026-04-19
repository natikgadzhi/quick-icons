//
//  ToolchainUnavailableView.swift
//  QuickIcons
//

import SwiftUI

/// Displayed when the toolchain probe determines that swiftc is not available.
/// Explains the issue and provides a command to install the toolchain,
/// plus a "Re-check" button that re-runs the probe without relaunching the app.
struct ToolchainUnavailableView: View {
    let reason: String
    let onRecheck: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Swift toolchain not found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("QuickIcons requires the Swift compiler to preview and export icons. Install Xcode or the Xcode Command Line Tools to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                Text("Run this command in Terminal:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("xcode-select --install")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .textSelection(.enabled)
            }

            if !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Re-check", action: onRecheck)
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 440)
    }
}

#Preview {
    ToolchainUnavailableView(reason: "xcrun failed to locate swiftc (exit 1).") {}
}
