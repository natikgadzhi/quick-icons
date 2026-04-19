//
//  IconExportView.swift
//  QuickIcons
//

import AppKit
import SwiftUI

struct IconExportView: View {
    @State private var selectedIcon: ExportableIcon = .kindleExporter
    @State private var exportMessage: String?
    @State private var isExporting = false

    private let service = IconExportService()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("App Icon Export")
                    .font(.title2.weight(.semibold))

                Picker("Icon", selection: $selectedIcon) {
                    ForEach(ExportableIcon.allCases) { icon in
                        Text(icon.title).tag(icon)
                    }
                }
                .pickerStyle(.segmented)
            }

            selectedIcon
                .view(size: 220)
                .padding(20)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 10) {
                Button(isExporting ? "Exporting…" : "Export AppIcon Set") {
                    Task { @MainActor in
                        await exportSelectedIcon()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }

    @MainActor
    private func exportSelectedIcon() async {
        guard !isExporting else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose Export Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"

        guard panel.runModal() == .OK, let baseURL = panel.url else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let destination = try service.export(selectedIcon, to: baseURL)
            exportMessage = "Exported \(selectedIcon.title) to \(destination.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    IconExportView()
}
