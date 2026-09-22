import SwiftUI
import SwiftData

struct ItemsView: View {
    let list: TotalList

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editingItem: Item?
    @State private var editingList = false
    @State private var width: CGFloat = 0
    @AppStorage("showRunningBalance") private var showRunningBalance = true

    private var layout: RowLayout {
        RowLayout.forWidth(width, accessibilityTextSize: dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        let items = list.orderedItems
        let balances = list.runningBalances

        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                    row(for: item, at: index, of: items.count, runningBalance: balances[index])
                }
                .onMove(perform: move)
                .onDelete(perform: deleteOffsets)
            } header: {
                if layout.isColumns, !items.isEmpty {
                    ColumnHeader(layout: layout, showRunningBalance: showRunningBalance)
                }
            }
        }
        .navigationTitle(list.displayName)
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "plus.forwardslash.minus", description: Text("Add an item below."))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                TotalsSummary(list: list)
                QuickAddBar(list: list, compact: layout != .wideColumns)
            }
            .background(.bar)
        }
        .toolbar {
            #if os(iOS)
            // Edit mode is what puts the system's grab handles on the rows; on macOS the
            // rows are draggable without it.
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            #endif
            ToolbarItem {
                if let shared = try? SharedList(exporting: list) {
                    ShareLink(item: shared, preview: SharePreview(list.displayName)) {
                        Label("Share List", systemImage: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem {
                Menu {
                    Toggle("Show Running Balance", isOn: $showRunningBalance)
                    Button("List Details…", systemImage: "pencil") { editingList = true }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(item: item, list: list)
        }
        .sheet(isPresented: $editingList) {
            ListEditor(list: list)
        }
    }

    @ViewBuilder
    private func row(for item: Item, at index: Int, of count: Int, runningBalance: Int) -> some View {
        ItemRow(
            item: item,
            list: list,
            runningBalance: runningBalance,
            showRunningBalance: showRunningBalance,
            layout: layout,
            onEdit: { editingItem = item },
            onDelete: { delete(item) }
        )
        .contentShape(.rect)
        // A single tap over the whole row swallows the drag before List's reorder sees
        // it, which is why dragging did nothing on the Mac. Double-click there instead;
        // on iOS reordering happens in edit mode, so a single tap is free to open the
        // editor.
        #if os(macOS)
        .onTapGesture(count: 2) { editingItem = item }
        #else
        .onTapGesture { editingItem = item }
        #endif
        .swipeActions(edge: .leading) {
            Button(item.isDone ? "Not \(list.doneLabel)" : list.doneLabel, systemImage: item.isDone ? "circle" : "checkmark.circle") {
                item.isDone.toggle()
            }
            .tint(item.isDone ? .gray : .green)
        }
        .contextMenu {
            Button("Edit…", systemImage: "pencil") { editingItem = item }
            Button(
                item.isDone ? "Mark as Not \(list.doneLabel)" : "Mark as \(list.doneLabel)",
                systemImage: item.isDone ? "circle" : "checkmark.circle"
            ) {
                item.isDone.toggle()
            }

            Divider()

            Button("Move Up", systemImage: "arrow.up") { list.moveUp(index) }
                .disabled(index == 0)
            Button("Move Down", systemImage: "arrow.down") { list.moveDown(index) }
                .disabled(index == count - 1)

            Divider()

            Button(role: .destructive) { delete(item) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        list.move(fromOffsets: offsets, toOffset: destination)
    }

    private func deleteOffsets(_ offsets: IndexSet) {
        list.remove(atOffsets: offsets, in: context)
    }

    private func delete(_ item: Item) {
        guard let index = list.orderedItems.firstIndex(where: { $0.persistentModelID == item.persistentModelID }) else { return }
        list.remove(atOffsets: IndexSet(integer: index), in: context)
    }
}
