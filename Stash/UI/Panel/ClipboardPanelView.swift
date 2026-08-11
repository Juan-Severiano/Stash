//
//  ClipboardPanelView.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import SwiftUI

struct ClipboardPanelView: View {
    private var services: AppServices { AppServices.shared }
    private var settings: SettingsStore { services.settings }

    @State private var query = ""
    @State private var selectedID: String?
    @State private var filter: FilterGroup = .all
    @State private var showQuickActions = false
    @State private var detailItem: ClipboardItem?
    @State private var showDetail = false
    @State private var ocrResult: String?
    @State private var showOCRResult = false
    @FocusState private var searchFocused: Bool

    // MARK: - Derived

    private var visibleItems: [ClipboardItem] {
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

    private struct PanelSection: Identifiable {
        enum Kind: Equatable {
            case pinned, today, yesterday, date(Date)
        }
        let kind: Kind
        let items: [ClipboardItem]
        var id: String {
            switch kind {
            case .pinned: "pinned"
            case .today: "today"
            case .yesterday: "yesterday"
            case .date(let date): "d\(date.timeIntervalSince1970)"
            }
        }
        var title: String {
            switch kind {
            case .pinned: "PINNED"
            case .today: "TODAY"
            case .yesterday: "YESTERDAY"
            case .date(let date): date.formatted(date: .abbreviated, time: .omitted).uppercased()
            }
        }
    }

    private var sections: [PanelSection] {
        let calendar = Calendar.current
        let pinned = visibleItems.filter(\.isPinned)
        let rest = visibleItems.filter { !$0.isPinned }

        var sections: [PanelSection] = []
        if !pinned.isEmpty {
            sections.append(PanelSection(kind: .pinned, items: pinned))
        }
        let today = rest.filter { calendar.isDateInToday($0.lastUsedAt) }
        let yesterday = rest.filter { calendar.isDateInYesterday($0.lastUsedAt) }
        let older = rest.filter { !calendar.isDateInToday($0.lastUsedAt) && !calendar.isDateInYesterday($0.lastUsedAt) }
        if !today.isEmpty {
            sections.append(PanelSection(kind: .today, items: today))
        }
        if !yesterday.isEmpty {
            sections.append(PanelSection(kind: .yesterday, items: yesterday))
        }
        if !older.isEmpty {
            let grouped = Dictionary(grouping: older) { calendar.startOfDay(for: $0.lastUsedAt) }
            for day in grouped.keys.sorted(by: >) {
                sections.append(PanelSection(kind: .date(day), items: grouped[day] ?? []))
            }
        }
        return sections
    }

    private var selectedItem: ClipboardItem? {
        guard let selectedID else { return nil }
        return visibleItems.first { $0.id == selectedID }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            filterBar
            Divider()
            resultsList
            footerBar
        }
        .frame(width: ClipboardPanelController.panelSize.width,
               height: ClipboardPanelController.panelSize.height)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
                if selectedID == nil {
                    selectedID = visibleItems.first?.id
                }
            }
        }
        .onChange(of: query) { _, _ in
            selectedID = visibleItems.first?.id
        }
        .onChange(of: filter) { _, _ in
            selectedID = visibleItems.first?.id
        }
        .onChange(of: visibleItems) { _, newItems in
            if let selectedID, !newItems.contains(where: { $0.id == selectedID }) {
                self.selectedID = newItems.first?.id
            }
        }
        .popover(isPresented: $showQuickActions, arrowEdge: .bottom) {
            if let item = selectedItem {
                QuickActionsMenu(
                    item: item,
                    onEdit: { editedItem in
                        detailItem = editedItem
                        showDetail = true
                    },
                    onOCRResult: { text in
                        ocrResult = text
                        showOCRResult = true
                    }
                )
            }
        }
        .sheet(isPresented: $showDetail) {
            if let item = detailItem {
                ItemDetailSheet(item: item)
            }
        }
        .sheet(isPresented: $showOCRResult) {
            if let text = ocrResult {
                OCRResultSheet(text: text)
            }
        }
    }

    // MARK: - Search

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard")
                        .font(.title3.weight(.semibold))
                    Text(historySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
                    .onKeyPress { press in
                        handleKeyPress(press)
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var historySummary: String {
        let count = services.history.items.count
        return count == 1 ? "1 saved item" : "\(count) saved items"
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FilterGroup.allCases) { group in
                    Button {
                        filter = group
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: group.icon)
                            Text(group.displayName)
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(filter == group ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if sections.isEmpty {
                        emptyState
                    } else {
                        ForEach(sections) { section in
                            if !section.items.isEmpty {
                                Text(section.title)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.7)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 18)
                                    .padding(.top, 14)
                                    .padding(.bottom, 4)
                            }
                            ForEach(section.items) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isSelected: item.id == selectedID
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    activate(item)
                                }
                                .onTapGesture {
                                    selectedID = item.id
                                }
                                .id(item.id)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: filter == .pinned ? "pin.slash" : "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(services.history.items.isEmpty ? "Nothing copied yet" : "No matches")
                .font(.body.weight(.medium))
            Text("Copy anything with ⌘C to start building your history")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button {
                showQuickActions = true
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Quick actions (⌘K)")

            Spacer()

            Text(shortcutHints)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar.opacity(0.65))
    }

    private var shortcutHints: String {
        let primary = settings.pasteImmediately ? "⏎ Paste" : "⏎ Copy"
        return "\(primary)   ⌘⏎ Copy   ⌘P Pin   ⌫ Delete   Space Preview   ⌘K Actions"
    }

    // MARK: - Actions

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            moveSelection(by: 1)
            return .handled
        case .upArrow:
            moveSelection(by: -1)
            return .handled
        case .return:
            if press.modifiers.contains(.command) {
                if let item = selectedItem { copy(item) }
            } else {
                if let item = selectedItem { activate(item) }
            }
            return .handled
        case .space:
            guard query.isEmpty, press.modifiers.isEmpty else { return .ignored }
            if let item = selectedItem { openDetail(item) }
            return .handled
        case .delete:
            guard query.isEmpty, press.modifiers.isEmpty else { return .ignored }
            deleteSelected()
            return .handled
        default:
            if press.modifiers.contains(.command) {
                switch press.key {
                case "p":
                    if let item = selectedItem { togglePin(item) }
                    return .handled
                case "k":
                    showQuickActions = true
                    return .handled
                default:
                    return .ignored
                }
            }
            return .ignored
        }
    }

    private func moveSelection(by offset: Int) {
        guard !visibleItems.isEmpty else { return }
        guard let selectedID else {
            self.selectedID = visibleItems.first?.id
            return
        }
        guard let index = visibleItems.firstIndex(where: { $0.id == selectedID }) else {
            self.selectedID = visibleItems.first?.id
            return
        }
        let next = (index + offset + visibleItems.count) % visibleItems.count
        self.selectedID = visibleItems[next].id
    }

    private func activate(_ item: ClipboardItem) {
        let mode: PasteService.Mode = settings.pasteImmediately ? .paste : .copy
        services.paste.perform(item, mode: mode)
    }

    private func copy(_ item: ClipboardItem) {
        services.paste.perform(item, mode: .copy)
    }

    private func togglePin(_ item: ClipboardItem) {
        services.history.togglePin(id: item.id)
    }

    private func deleteSelected() {
        guard let selectedID else { return }
        let ids = services.history.items.map(\.id)
        let index = ids.firstIndex(of: selectedID) ?? 0
        services.history.delete(id: selectedID)
        let remaining = services.history.items
        self.selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }

    private func openDetail(_ item: ClipboardItem) {
        detailItem = item
        showDetail = true
    }
}
