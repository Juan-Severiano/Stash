//
//  ItemType.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

enum ItemType: String, CaseIterable, Sendable {
    case text, link, email, phone, color, code, image, screenshot, file

    var displayName: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .email: "Email"
        case .phone: "Phone"
        case .color: "Color"
        case .code: "Code"
        case .image: "Image"
        case .screenshot: "Screenshot"
        case .file: "File"
        }
    }

    var icon: String {
        switch self {
        case .text: "doc.text"
        case .link: "link"
        case .email: "envelope"
        case .phone: "phone"
        case .color: "paintpalette"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .image: "photo"
        case .screenshot: "camera"
        case .file: "doc"
        }
    }

    var filterGroup: FilterGroup {
        switch self {
        case .image: .images
        case .screenshot: .screenshots
        case .file: .files
        case .link: .links
        case .code: .code
        case .text, .email, .phone, .color: .text
        }
    }

    var isImageLike: Bool {
        self == .image || self == .screenshot
    }
}

enum FilterGroup: String, CaseIterable, Identifiable, Sendable {
    case all, text, links, images, files, code, screenshots, pinned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .links: "Links"
        case .images: "Images"
        case .files: "Files"
        case .code: "Code"
        case .screenshots: "Screenshots"
        case .pinned: "Pinned"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .text: "doc.text"
        case .links: "link"
        case .images: "photo"
        case .files: "doc"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .screenshots: "camera"
        case .pinned: "pin"
        }
    }
}
