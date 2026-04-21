//
//  KeysTab.swift
//  keyDrop
//

import SwiftUI

struct KeysTab: View {
    @Environment(KeyStore.self) private var store

    @State private var selection: KeyEntry.ID?
    @State private var hoverTarget: HoverTarget?
    @State private var hoverTask: Task<Void, Never>?
    @State private var popoverTarget: HoverTarget?
    @State private var editTarget: EditTarget?
    @State private var deleteConfirmTarget: KeyEntry?
    @State private var rowStatus: RowStatus?
    @State private var rowStatusTask: Task<Void, Never>?

    private static let hoverDelayNanos: UInt64 = 2_000_000_000

    private enum Column { case label, key }

    private struct HoverTarget: Equatable {
        let entryId: UUID
        let column: Column
    }

    private struct EditTarget: Identifiable {
        let id: UUID
        let entry: KeyEntry
        let currentKey: String
    }

    private struct RowStatus: Equatable, Identifiable {
        let id = UUID()
        let entryId: UUID
        let column: Column
        let text: String
        let kind: Kind
        enum Kind { case success, error }
    }

    private var sortedEntries: [KeyEntry] {
        store.entries.sorted { $0.createdAt > $1.createdAt }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                emptyState
            } else {
                table
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $editTarget) { target in
            EditKeySheet(entry: target.entry, initialKey: target.currentKey) { newLabel, newKey in
                store.updateEntry(id: target.entry.id, newLabel: newLabel, newKey: newKey)
            }
        }
        .alert("Delete key?", isPresented: deleteAlertBinding, presenting: deleteConfirmTarget) { target in
            Button("Delete", role: .destructive) {
                performDelete(target)
            }
            Button("Cancel", role: .cancel) { }
        } message: { target in
            Text("\"\(target.label)\" will be removed from the keychain. This cannot be undone. Authentication is required.")
                .font(AppFont.small)
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteConfirmTarget != nil },
            set: { if !$0 { deleteConfirmTarget = nil } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No keys yet")
                .font(AppFont.title)
            Text("Drop a key from the menu bar to see it here.")
                .font(AppFont.small)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var table: some View {
        Table(sortedEntries, selection: $selection) {
            TableColumn("LABEL") { entry in
                labelCell(entry)
            }
            .width(min: 200, ideal: 200, max: 200)

            TableColumn("KEY") { entry in
                keyCell(entry)
            }
            .width(min: 220, ideal: 220, max: 220)

            TableColumn("CREATED") { entry in
                Text(Self.dateFormatter.string(from: entry.createdAt))
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 160, ideal: 160, max: 160)
        }
        .tableStyle(.inset)
        .font(AppFont.body)
        .contextMenu(forSelectionType: KeyEntry.ID.self) { ids in
            contextMenuItems(for: ids)
        }
    }

    private func labelCell(_ entry: KeyEntry) -> some View {
        Text(displayLabel(for: entry))
            .font(AppFont.body)
            .foregroundStyle(labelColor(for: entry))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { copyAction(entry, column: .label) }
            .onHover { hovering in handleHover(entry: entry, column: .label, hovering: hovering) }
            .popover(isPresented: popoverBinding(for: entry, column: .label), arrowEdge: .top) {
                hoverPopover(entry)
            }
    }

    private func keyCell(_ entry: KeyEntry) -> some View {
        Text(displayKey(for: entry))
            .font(AppFont.monoBody)
            .foregroundStyle(keyColor(for: entry))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { copyAction(entry, column: .key) }
            .onHover { hovering in handleHover(entry: entry, column: .key, hovering: hovering) }
            .popover(isPresented: popoverBinding(for: entry, column: .key), arrowEdge: .top) {
                hoverPopover(entry)
            }
    }

    @ViewBuilder
    private func contextMenuItems(for ids: Set<KeyEntry.ID>) -> some View {
        if ids.count == 1,
           let id = ids.first,
           let entry = store.entries.first(where: { $0.id == id }) {
            Button("Edit") { editRequest(entry) }
            Divider()
            Button("Delete...", role: .destructive) {
                deleteConfirmTarget = entry
            }
        }
    }

    private func hoverPopover(_ entry: KeyEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LABEL")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            Text(entry.label)
                .font(AppFont.body)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Divider()
            Text("KEY")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            Text(displayKey(for: entry))
                .font(AppFont.monoBody)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isRevealed(entry) ? Color.primary : Color.secondary)
        }
        .padding(14)
        .frame(width: 320)
    }

    private var footer: some View {
        HStack {
            Text("\(store.entries.count) key\(store.entries.count == 1 ? "" : "s")")
                .font(AppFont.small)
                .foregroundStyle(.secondary)
            Spacer()
            if let err = store.lastError {
                Text(err)
                    .font(AppFont.small)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Display helpers

    private func isRevealed(_ entry: KeyEntry) -> Bool {
        store.auth.isWithinGrace && store.revealedValues[entry.id] != nil
    }

    private func displayKey(for entry: KeyEntry) -> String {
        if let status = rowStatus, status.entryId == entry.id, status.column == .key {
            return status.text
        }
        if isRevealed(entry), let value = store.revealedValues[entry.id] {
            return value
        }
        return entry.keyPreview
    }

    private func displayLabel(for entry: KeyEntry) -> String {
        if let status = rowStatus, status.entryId == entry.id, status.column == .label {
            return status.text
        }
        return entry.label
    }

    private func labelColor(for entry: KeyEntry) -> Color {
        if let status = rowStatus, status.entryId == entry.id, status.column == .label {
            return status.kind == .success ? .green : .red
        }
        return .primary
    }

    private func keyColor(for entry: KeyEntry) -> Color {
        if let status = rowStatus, status.entryId == entry.id, status.column == .key {
            return status.kind == .success ? .green : .red
        }
        return isRevealed(entry) ? Color.primary : Color.secondary
    }

    // MARK: - Hover

    private func handleHover(entry: KeyEntry, column: Column, hovering: Bool) {
        let target = HoverTarget(entryId: entry.id, column: column)
        if hovering {
            hoverTarget = target
            hoverTask?.cancel()
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.hoverDelayNanos)
                guard !Task.isCancelled, hoverTarget == target else { return }
                popoverTarget = target
            }
        } else if hoverTarget == target {
            hoverTarget = nil
            hoverTask?.cancel()
            hoverTask = nil
            if popoverTarget == target {
                popoverTarget = nil
            }
        }
    }

    private func popoverBinding(for entry: KeyEntry, column: Column) -> Binding<Bool> {
        Binding(
            get: {
                guard let t = popoverTarget else { return false }
                return t.entryId == entry.id && t.column == column
            },
            set: { newValue in
                if !newValue,
                   let t = popoverTarget,
                   t.entryId == entry.id, t.column == column {
                    popoverTarget = nil
                }
            }
        )
    }

    // MARK: - Actions

    private func copyAction(_ entry: KeyEntry, column: Column) {
        popoverTarget = nil
        hoverTask?.cancel()
        let needsAuth = !store.auth.isWithinGrace
        if needsAuth {
            showRowStatus(RowStatus(entryId: entry.id, column: column, text: "Please authenticate.", kind: .error), persistent: true)
        }
        store.copyKey(entry) { success in
            if success {
                showRowStatus(RowStatus(entryId: entry.id, column: column, text: "Copied!", kind: .success))
            } else if let err = store.lastError {
                showRowStatus(RowStatus(entryId: entry.id, column: column, text: err, kind: .error))
            } else {
                clearRowStatus()
            }
        }
    }

    private func editRequest(_ entry: KeyEntry) {
        popoverTarget = nil
        hoverTask?.cancel()
        let needsAuth = !store.auth.isWithinGrace
        if needsAuth {
            showRowStatus(RowStatus(entryId: entry.id, column: .label, text: "Please authenticate.", kind: .error), persistent: true)
        }
        store.revealKey(entry) { value in
            if let value {
                clearRowStatus()
                editTarget = EditTarget(id: entry.id, entry: entry, currentKey: value)
            } else if let err = store.lastError {
                showRowStatus(RowStatus(entryId: entry.id, column: .label, text: err, kind: .error))
            } else {
                clearRowStatus()
            }
        }
    }

    private func performDelete(_ entry: KeyEntry) {
        showRowStatus(RowStatus(entryId: entry.id, column: .label, text: "Please authenticate.", kind: .error), persistent: true)
        store.deleteWithAuth(entry) { success in
            if success {
                clearRowStatus()
            } else if let err = store.lastError {
                showRowStatus(RowStatus(entryId: entry.id, column: .label, text: err, kind: .error))
            } else {
                clearRowStatus()
            }
        }
    }

    private func showRowStatus(_ status: RowStatus, persistent: Bool = false) {
        rowStatus = status
        rowStatusTask?.cancel()
        rowStatusTask = nil
        guard !persistent else { return }
        let lifetime: TimeInterval = status.kind == .error ? 5 : 2.0
        rowStatusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if rowStatus == status { rowStatus = nil }
        }
    }

    private func clearRowStatus() {
        rowStatusTask?.cancel()
        rowStatusTask = nil
        rowStatus = nil
    }
}

private struct EditKeySheet: View {
    let entry: KeyEntry
    let initialKey: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftLabel: String
    @State private var draftKey: String

    init(entry: KeyEntry, initialKey: String, onSave: @escaping (String, String) -> Void) {
        self.entry = entry
        self.initialKey = initialKey
        self.onSave = onSave
        self._draftLabel = State(initialValue: entry.label)
        self._draftKey = State(initialValue: initialKey)
    }

    private var canSave: Bool {
        !draftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit key")
                .font(AppFont.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("LABEL")
                    .font(AppFont.label)
                    .foregroundStyle(.secondary)
                TextField("Label", text: $draftLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("KEY")
                    .font(AppFont.label)
                    .foregroundStyle(.secondary)
                TextField("Key", text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.monoBody)
                    .lineLimit(1)
            }

            Text("Changes will be written to the keychain.")
                .font(AppFont.small)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draftLabel, draftKey)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
