//
//  HistoryWindow.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import SwiftUI

struct HistoryWindowView: View {
    private var services: AppServices { AppServices.shared }
    private var settings: SettingsStore { services.settings }
    @State private var query = ""
    @State private var filter: FilterGroup = .all

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                Spacer()
                Picker("", selection: $filter) {
                    ForEach(FilterGroup.allCases) { group in
                        Text(group.displayName).tag(group)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 118)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            List {
                if sections.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Nothing copied yet" : "No matching items",
                        systemImage: query.isEmpty ? "clipboard" : "magnifyingglass",
                        description: Text(query.isEmpty
                            ? "Items you copy will appear here."
                            : "Try a different search or filter.")
                    )
                } else {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.items) { item in
                                HistoryRow(item: item)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            HStack {
                Text("\(services.history.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.bar)
        }
        .frame(minWidth: 680, minHeight: 500)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All", role: .destructive) {
                    services.history.deleteAll()
                }
                .disabled(services.history.items.isEmpty)
            }
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private struct HistorySection: Identifiable {
        let title: String
        let items: [ClipboardItem]
        var id: String { title }
    }

    private var filteredItems: [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return services.history.items.filter { item in
            switch filter {
            case .all: break
            case .pinned: guard item.isPinned else { return false }
            default: guard item.type.filterGroup == filter else { return false }
            }
            guard !trimmed.isEmpty else { return true }
            return item.searchText.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var sections: [HistorySection] {
        let calendar = Calendar.current
        var groups: [(title: String, items: [ClipboardItem])] = []
        let today = filteredItems.filter { calendar.isDateInToday($0.lastUsedAt) }
        let yesterday = filteredItems.filter { calendar.isDateInYesterday($0.lastUsedAt) }
        let older = filteredItems.filter { !calendar.isDateInToday($0.lastUsedAt) && !calendar.isDateInYesterday($0.lastUsedAt) }
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !older.isEmpty {
            let grouped = Dictionary(grouping: older) { calendar.startOfDay(for: $0.lastUsedAt) }
            for day in grouped.keys.sorted(by: >) {
                groups.append((day.formatted(date: .abbreviated, time: .omitted), grouped[day] ?? []))
            }
        }
        return groups.map { HistorySection(title: $0.title, items: $0.items) }
    }
}

struct HistoryRow: View {
    let item: ClipboardItem
    private var services: AppServices { AppServices.shared }
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(preview)
                .font(item.type == .code ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let source = item.sourceApp {
                Text(source)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(item.lastUsedAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Button {
                    services.history.togglePin(id: item.id)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button {
                    services.history.delete(id: item.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete")

                Button {
                    services.paste.perform(item, mode: .copy)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }
            .opacity(isHovering ? 1 : 0.4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            services.paste.perform(item, mode: .paste)
        }
    }

    private var preview: String {
        switch item.type {
        case .file:
            return item.fileURLs.map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
        case .image, .screenshot:
            return item.displayText
        case .code, .text, .link, .email, .phone, .color:
            return (item.textContent ?? "").replacingOccurrences(of: "\n", with: " ")
        }
    }
}
