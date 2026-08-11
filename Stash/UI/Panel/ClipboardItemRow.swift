//
//  ClipboardItemRow.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(previewText)
                    .font(item.type == .code ? .system(size: 12, design: .monospaced) : .system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    if let source = item.sourceApp, !source.isEmpty {
                        Text(source)
                    }
                    if item.sourceApp != nil {
                        Text("•")
                    }
                    Text(RelativeTime.string(for: item.lastUsedAt))
                    if item.isSensitive {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 8))
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.type.isImageLike {
                thumbnailView
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 11))
        .padding(.horizontal, 6)
        .onHover { isHovering = $0 }
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }

    private var iconView: some View {
        Image(systemName: item.type.icon)
            .font(.system(size: 13, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 30, height: 30)
            .background(.quaternary.opacity(0.55), in: Circle())
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.18))
        }
        return AnyShapeStyle(isHovering ? Color.secondary.opacity(0.10) : Color.clear)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary.opacity(0.5))
                .frame(width: 44, height: 32)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var previewText: String {
        switch item.type {
        case .image:
            return item.displayText
        case .screenshot:
            return item.textContent ?? "Screenshot"
        case .file:
            return item.fileURLs.map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
        case .link, .email, .phone, .color, .code, .text:
            let text = item.textContent ?? ""
            if item.type == .code {
                return text.replacingOccurrences(of: "\n", with: " ")
            }
            return text
        }
    }

    private func loadThumbnailIfNeeded() {
        guard thumbnail == nil, item.type.isImageLike else { return }
        if let previewPath = item.previewPath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: previewPath)),
           let image = NSImage(data: data) {
            thumbnail = image
            return
        }
        if let filePath = item.filePath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
           let image = NSImage(data: data) {
            thumbnail = image
        }
    }
}

enum RelativeTime {
    static func string(for date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:
            return "just now"
        case ..<3600:
            return "\(Int(interval / 60)) min"
        case ..<86_400:
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        case ..<604_800:
            let days = Int(interval / 86_400)
            return days == 1 ? "1 day" : "\(days) days"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
