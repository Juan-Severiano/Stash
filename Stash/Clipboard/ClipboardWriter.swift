//
//  ClipboardWriter.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

enum ClipboardWriter {
    /// Writes an item back to the pasteboard, preserving its rich types.
    static func write(_ item: ClipboardItem) {
        switch item.type {
        case .image, .screenshot:
            if let data = FileStorage.loadImageData(id: item.id) {
                writeImage(data: data)
            }
        case .file:
            let urls = item.fileURLs.map { URL(fileURLWithPath: $0) }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(urls as [NSURL])
        default:
            writeText(item.textContent ?? "", rich: item.richTextData)
        }
    }

    static func writeText(_ text: String, rich: Data?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        if let rich {
            pb.setData(rich, forType: .rtf)
        }
    }

    static func writePlain(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    static func writeImage(data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)
    }

    static func writeFiles(paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }
}
