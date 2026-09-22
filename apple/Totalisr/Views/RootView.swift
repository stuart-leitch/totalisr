import SwiftUI
import SwiftData

/// Lists on the left, the selected list's items on the right. On iPhone the split view
/// collapses to a push/pop stack; on iPad and Mac it stays side by side.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var selection: TotalList?
    @State private var pendingImport: PendingImport?
    @State private var importFailure: String?

    /// A decoded file waiting for the user to say yes. Import overwrites, so it never
    /// happens on the strength of an AirDrop alone.
    private struct PendingImport: Identifiable {
        let id = UUID()
        let document: ListDocument
        let replacing: String?

        var willReplace: Bool { replacing != nil }
    }

    var body: some View {
        NavigationSplitView {
            ListsSidebar(selection: $selection)
        } detail: {
            if let selection {
                ItemsView(list: selection)
                    // Rebuild the detail column when the selected list changes, so
                    // per-list view state (quick-add fields, edit mode) doesn't leak
                    // from one list into the next.
                    .id(selection.persistentModelID)
            } else {
                ContentUnavailableView("No List Selected", systemImage: "list.bullet.rectangle", description: Text("Pick a list, or create one."))
            }
        }
        .onOpenURL(perform: receive)
        .alert(
            pendingImport?.willReplace == true ? "Replace This List?" : "Import This List?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            presenting: pendingImport
        ) { pending in
            Button(pending.willReplace ? "Replace" : "Import", role: pending.willReplace ? .destructive : nil) {
                apply(pending.document)
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            if let replacing = pending.replacing {
                Text("“\(replacing)” already exists on this device. Importing replaces it and its \(pending.document.list.items.count) item(s) entirely.")
            } else {
                Text("Adds “\(pending.document.list.name)” with \(pending.document.list.items.count) item(s).")
            }
        }
        .alert(
            "Could Not Import",
            isPresented: Binding(
                get: { importFailure != nil },
                set: { if !$0 { importFailure = nil } }
            ),
            presenting: importFailure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure)
        }
    }

    private func receive(_ url: URL) {
        // A file handed over by AirDrop may be security-scoped; harmless to attempt for
        // one that isn't.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let document = try ListDocument(decoding: try Data(contentsOf: url))
            let existing = try ListImport.existingList(for: document, in: context)
            pendingImport = PendingImport(document: document, replacing: existing?.displayName)
        } catch {
            importFailure = error.localizedDescription
        }
    }

    private func apply(_ document: ListDocument) {
        do {
            let result = try ListImport.apply(document, to: context)
            selection = result.list
        } catch {
            importFailure = error.localizedDescription
        }
    }
}
