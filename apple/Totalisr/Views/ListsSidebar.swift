import SwiftUI
import SwiftData

struct ListsSidebar: View {
    @Binding var selection: TotalList?

    @Environment(\.modelContext) private var context
    @Query(sort: \TotalList.createdAt, order: .reverse) private var lists: [TotalList]

    @State private var editing: TotalList?

    var body: some View {
        List(selection: $selection) {
            ForEach(lists) { list in
                NavigationLink(value: list) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.displayName)
                        Text(list.formatted(list.totalMinorUnits))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .contextMenu {
                    Button("Rename…", systemImage: "pencil") { editing = list }
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(list) }
                }
            }
            .onDelete { offsets in
                for list in offsets.map({ lists[$0] }) { delete(list) }
            }
        }
        .navigationTitle("Totalisr")
        .toolbar {
            ToolbarItem {
                Button("New List", systemImage: "plus", action: addList)
            }
        }
        .sheet(item: $editing) { list in
            ListEditor(list: list)
        }
        .overlay {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label("No Lists", systemImage: "sum")
                } description: {
                    Text("Create a list to start totalling.")
                } actions: {
                    Button("New List", action: addList)
                }
            }
        }
    }

    private func addList() {
        let list = TotalList(name: "")
        context.insert(list)
        selection = list
        editing = list
    }

    private func delete(_ list: TotalList) {
        if selection?.persistentModelID == list.persistentModelID { selection = nil }
        context.delete(list)
    }
}
