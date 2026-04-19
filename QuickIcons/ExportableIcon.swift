//
//  ExportableIcon.swift
//  QuickIcons
//

import SwiftUI

enum ExportableIcon: String, CaseIterable, Identifiable {
    case kindleExporter
    case scrapesBook

    var id: Self { self }

    var title: String {
        switch self {
        case .kindleExporter: "KindleExporter"
        case .scrapesBook: "Scrapes"
        }
    }

    var exportDirectoryName: String {
        switch self {
        case .kindleExporter: "KindleExporter-AppIcon.appiconset"
        case .scrapesBook: "Scrapes-AppIcon.appiconset"
        }
    }

    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .kindleExporter: KindleExporterIcon(size: size)
        case .scrapesBook: ScrapesBookIconView(size: size)
        }
    }
}
