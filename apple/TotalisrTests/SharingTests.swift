import Foundation
import SwiftData
import Testing
@testable import Totalisr

@MainActor
@Suite("Sharing a list")
struct SharingTests {
    let container: ModelContainer
    let list: TotalList

    init() throws {
        container = try ModelContainer(
            for: TotalList.self, Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        list = TotalList(name: "Japan Trip", currencyCode: "JPY")
        list.countsDown = true
        container.mainContext.insert(list)

        for spec in [("Budget", 400_000, false), ("Flights", -95_000, true), ("Ryokan", -120_000, false)] {
            let item = Item(label: spec.0, amountMinorUnits: spec.1, isDone: spec.2)
            container.mainContext.insert(item)
            list.append(item)
        }
    }

    @Test("A document round-trips through JSON unchanged")
    func roundTrip() throws {
        let document = ListDocument(exporting: list)
        let decoded = try ListDocument(decoding: try document.encoded())
        #expect(decoded == document)
    }

    @Test("Export captures the list's options and its items in order")
    func exportContents() {
        let document = ListDocument(exporting: list)

        #expect(document.list.id == list.externalID)
        #expect(document.list.name == "Japan Trip")
        #expect(document.list.currencyCode == "JPY")
        #expect(document.list.countsDown)
        #expect(document.list.items.map(\.label) == ["Budget", "Flights", "Ryokan"])
        #expect(document.list.items.map(\.amountMinorUnits) == [400_000, -95_000, -120_000])
        #expect(document.list.items.map(\.isDone) == [false, true, false])
    }

    @Test("A file from a newer version is refused rather than misread")
    func rejectsNewerFormat() throws {
        var document = ListDocument(exporting: list)
        document.formatVersion = ListDocument.currentFormatVersion + 1
        let data = try ListDocument.encoder().encode(document)

        #expect(throws: ListDocumentError.self) {
            try ListDocument(decoding: data)
        }
    }

    @Test("Something that isn't a list is refused")
    func rejectsGarbage() {
        #expect(throws: ListDocumentError.self) {
            try ListDocument(decoding: Data("not a list".utf8))
        }
    }

    @Test("The suggested filename is derived from the name and is path-safe")
    func filename() {
        #expect(ListDocument(exporting: list).suggestedFilename == "Japan Trip.totalisr")

        list.name = "Q1/Q2: budget?"
        #expect(ListDocument(exporting: list).suggestedFilename == "Q1Q2 budget.totalisr")

        list.name = "   "
        #expect(ListDocument(exporting: list).suggestedFilename == "Totalisr List.totalisr")
    }
}

@MainActor
@Suite("Importing a list")
struct ListImportTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: TotalList.self, Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeDocument(id: UUID = UUID(), name: String = "Japan Trip", items: [(String, Int)] = [("Budget", 400_000), ("Flights", -95_000)]) -> ListDocument {
        ListDocument(list: ListPayload(
            id: id,
            name: name,
            createdAt: .now,
            isFinancial: true,
            currencyCode: "JPY",
            unitLabel: "",
            countsDown: true,
            items: items.map {
                ItemPayload(label: $0.0, amountMinorUnits: $0.1, note: "", date: .now, isDone: false)
            }
        ))
    }

    @Test("An unseen list is created")
    func createsWhenNew() throws {
        let document = makeDocument()
        let result = try ListImport.apply(document, to: container.mainContext)

        #expect(result.outcome == .created)
        #expect(result.list.externalID == document.list.id)
        #expect(result.list.name == "Japan Trip")
        #expect(result.list.orderedItems.map(\.label) == ["Budget", "Flights"])
        #expect(result.list.totalMinorUnits == 305_000)
    }

    /// The point of carrying an external ID: a second delivery of the same list must not
    /// leave two of them behind.
    @Test("Importing the same list twice replaces it instead of duplicating")
    func replacesWhenKnown() throws {
        let document = makeDocument()
        try ListImport.apply(document, to: container.mainContext)

        let second = try ListImport.apply(document, to: container.mainContext)
        #expect(second.outcome == .replaced)

        let lists = try container.mainContext.fetch(FetchDescriptor<TotalList>())
        #expect(lists.count == 1)
    }

    @Test("Replacing overwrites the items wholesale, leaving none behind")
    func replaceOverwritesItems() throws {
        let id = UUID()
        try ListImport.apply(makeDocument(id: id), to: container.mainContext)

        let updated = makeDocument(id: id, name: "Japan Trip 2027", items: [("Budget", 500_000)])
        let result = try ListImport.apply(updated, to: container.mainContext)

        #expect(result.outcome == .replaced)
        #expect(result.list.name == "Japan Trip 2027")
        #expect(result.list.orderedItems.map(\.label) == ["Budget"])
        #expect(result.list.totalMinorUnits == 500_000)
        #expect(result.list.orderedItems.map(\.sortIndex) == [0])

        // The replaced items are gone from the store, not merely detached.
        try container.mainContext.save()
        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
    }

    @Test("Two different lists both survive")
    func differentIdsCoexist() throws {
        try ListImport.apply(makeDocument(name: "Japan"), to: container.mainContext)
        try ListImport.apply(makeDocument(name: "Kitchen"), to: container.mainContext)

        let lists = try container.mainContext.fetch(FetchDescriptor<TotalList>())
        #expect(lists.count == 2)
        #expect(Set(lists.map(\.name)) == ["Japan", "Kitchen"])
    }

    @Test("Checking for an existing list does not create one")
    func existenceCheckIsReadOnly() throws {
        let document = makeDocument()
        #expect(try ListImport.existingList(for: document, in: container.mainContext) == nil)

        try ListImport.apply(document, to: container.mainContext)
        let found = try ListImport.existingList(for: document, in: container.mainContext)
        #expect(found?.externalID == document.list.id)
    }

    @Test("A round trip through a file reproduces the list")
    func endToEnd() throws {
        let source = TotalList(name: "Kitchen", currencyCode: "GBP")
        container.mainContext.insert(source)
        for spec in [("Budget", 800_000), ("Worktop", -210_000), ("Tiles", -45_000)] {
            let item = Item(label: spec.0, amountMinorUnits: spec.1)
            container.mainContext.insert(item)
            source.append(item)
        }
        let data = try ListDocument(exporting: source).encoded()

        // A second device: its own store, which has never seen this list.
        let other = try ModelContainer(
            for: TotalList.self, Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let result = try ListImport.apply(try ListDocument(decoding: data), to: other.mainContext)

        #expect(result.outcome == .created)
        #expect(result.list.externalID == source.externalID)
        #expect(result.list.orderedItems.map(\.label) == ["Budget", "Worktop", "Tiles"])
        #expect(result.list.totalMinorUnits == source.totalMinorUnits)
        #expect(result.list.runningBalances == source.runningBalances)
    }
}
