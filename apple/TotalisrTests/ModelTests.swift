import Foundation
import SwiftData
import Testing
@testable import Totalisr

private let budget: [(label: String, minorUnits: Int, done: Bool)] = [
    ("Budget", 100_000, false),
    ("Flights", -25_000, true),
    ("Accommodation", -50_000, false),
]

/// Builds an in-memory store. The container comes back with the list because it has to
/// be *stored* by the caller: if it deallocates, SwiftData tears down the context and
/// every model it vended becomes unusable. Each suite below keeps it in a property, and
/// Swift Testing makes a fresh suite instance per test, so the tests stay isolated.
@MainActor
private func makeList(_ items: [(label: String, minorUnits: Int, done: Bool)] = []) throws -> (ModelContainer, TotalList) {
    let container = try ModelContainer(
        for: TotalList.self, Item.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let list = TotalList(name: "Trip", currencyCode: "GBP")
    container.mainContext.insert(list)

    for spec in items {
        let item = Item(label: spec.label, amountMinorUnits: spec.minorUnits, isDone: spec.done)
        container.mainContext.insert(item)
        list.append(item)
    }

    return (container, list)
}

@MainActor
@Suite("An empty list")
struct EmptyListTests {
    let container: ModelContainer
    let list: TotalList

    init() throws { (container, list) = try makeList() }

    @Test("Totals and balances are all zero or empty")
    func zeroed() {
        #expect(list.totalMinorUnits == 0)
        #expect(list.doneMinorUnits == 0)
        #expect(list.remainingMinorUnits == 0)
        #expect(list.orderedItems.isEmpty)
        #expect(list.runningBalances.isEmpty)
    }

    @Test("A blank name falls back to a placeholder")
    func placeholderName() {
        list.name = "   "
        #expect(list.displayName == "Untitled List")
        list.name = "Japan"
        #expect(list.displayName == "Japan")
    }
}

@MainActor
@Suite("Totals")
struct TotalsTests {
    let container: ModelContainer
    let list: TotalList

    init() throws { (container, list) = try makeList(budget) }

    @Test("The total is the signed sum of every item")
    func total() {
        #expect(list.totalMinorUnits == 25_000)
    }

    @Test("Done and remaining split the total between them")
    func doneSplit() {
        #expect(list.doneMinorUnits == -25_000)
        #expect(list.remainingMinorUnits == 50_000)
        #expect(list.doneMinorUnits + list.remainingMinorUnits == list.totalMinorUnits)
    }

    @Test("Marking an item done moves it across without changing the total")
    func togglingDone() {
        let before = list.totalMinorUnits

        list.orderedItems[2].isDone = true

        #expect(list.totalMinorUnits == before)
        #expect(list.doneMinorUnits == -75_000)
        #expect(list.remainingMinorUnits == 100_000)
    }

    @Test("Running balances accumulate from zero, one per item")
    func runningBalances() {
        #expect(list.runningBalances == [100_000, 75_000, 25_000])
        #expect(list.runningBalances.count == list.orderedItems.count)
        #expect(list.runningBalances.last == list.totalMinorUnits)
    }
}

@MainActor
@Suite("Ordering")
struct OrderingTests {
    let container: ModelContainer
    let list: TotalList

    init() throws { (container, list) = try makeList(budget) }

    @Test("Appending assigns increasing sort indexes")
    func appendOrders() {
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1, 2])
        #expect(list.orderedItems.map(\.label) == ["Budget", "Flights", "Accommodation"])
    }

    /// SwiftData makes no promise about the order of a to-many relationship, so this is
    /// the guard that `orderedItems` — not `items` — is what the views read.
    @Test("Order comes from sortIndex, not from the relationship's own order")
    func sortIndexWins() {
        list.orderedItems[0].sortIndex = 99
        #expect(list.orderedItems.map(\.label) == ["Flights", "Accommodation", "Budget"])
    }

    @Test("Moving an item down reorders and leaves indexes gap-free")
    func moveDown() {
        list.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(list.orderedItems.map(\.label) == ["Flights", "Accommodation", "Budget"])
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1, 2])
    }

    @Test("Moving an item up reorders and leaves indexes gap-free")
    func moveUp() {
        list.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(list.orderedItems.map(\.label) == ["Accommodation", "Budget", "Flights"])
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1, 2])
    }

    /// The one-place moves wrap a SwiftUI off-by-one (`toOffset` counts positions before
    /// the move), so they get their own tests rather than riding on `move`.
    @Test("Moving one place up swaps with the item above")
    func moveUpOnePlace() {
        list.moveUp(1)
        #expect(list.orderedItems.map(\.label) == ["Flights", "Budget", "Accommodation"])
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1, 2])
    }

    @Test("Moving one place down swaps with the item below")
    func moveDownOnePlace() {
        list.moveDown(1)
        #expect(list.orderedItems.map(\.label) == ["Budget", "Accommodation", "Flights"])
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1, 2])
    }

    @Test("One-place moves at the ends of the list do nothing")
    func moveAtBoundaries() {
        let original = list.orderedItems.map(\.label)

        list.moveUp(0)
        #expect(list.orderedItems.map(\.label) == original)

        list.moveDown(2)
        #expect(list.orderedItems.map(\.label) == original)
    }

    @Test("One-place moves with an out-of-range index do nothing")
    func moveOutOfRange() {
        let original = list.orderedItems.map(\.label)

        list.moveUp(99)
        list.moveDown(-1)
        list.moveDown(99)

        #expect(list.orderedItems.map(\.label) == original)
    }

    @Test("Reordering changes the running balances but not the total")
    func reorderKeepsTotal() {
        let total = list.totalMinorUnits

        list.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(list.totalMinorUnits == total)
        #expect(list.runningBalances == [-50_000, 50_000, 25_000])
    }

    @Test("Deleting removes the item, closes the index gap and updates the total")
    func delete() {
        list.remove(atOffsets: IndexSet(integer: 1), in: container.mainContext)

        #expect(list.orderedItems.map(\.label) == ["Budget", "Accommodation"])
        #expect(list.orderedItems.map(\.sortIndex) == [0, 1])
        #expect(list.totalMinorUnits == 50_000)
        #expect(list.doneMinorUnits == 0)
    }

    @Test("Appending after a delete does not reuse a sort index")
    func appendAfterDelete() {
        list.remove(atOffsets: IndexSet(integer: 2), in: container.mainContext)

        let extra = Item(label: "Insurance", amountMinorUnits: -5_000)
        container.mainContext.insert(extra)
        list.append(extra)

        #expect(list.orderedItems.map(\.label) == ["Budget", "Flights", "Insurance"])
        #expect(Set(list.orderedItems.map(\.sortIndex)).count == 3)
    }
}

@MainActor
@Suite("Model details")
struct ModelDetailTests {
    let container: ModelContainer
    let list: TotalList

    init() throws { (container, list) = try makeList(budget) }

    @Test("An item's decimal amount round-trips through its stored minor units")
    func amountRoundTrip() {
        let item = list.orderedItems[1]
        #expect(item.amount == Decimal(string: "-250"))

        item.amount = Decimal(string: "12.34")!
        #expect(item.amountMinorUnits == 1_234)

        item.amount = Decimal(string: "12.345")!
        #expect(item.amountMinorUnits == 1_235)
    }

    @Test("A blank item label falls back to a placeholder")
    func placeholderLabel() {
        let item = list.orderedItems[0]
        item.label = ""
        #expect(item.displayLabel == "Untitled")

        item.label = "Flights"
        #expect(item.displayLabel == "Flights")
    }

    @Test("A note counts as present only when it has content")
    func notePresence() {
        let item = list.orderedItems[0]
        #expect(!item.hasNote)

        item.note = "   "
        #expect(!item.hasNote)

        item.note = "BA2490"
        #expect(item.hasNote)
    }

    @Test("A new list takes the locale's currency unless told otherwise")
    func currencyDefault() {
        #expect(TotalList(name: "A").currencyCode == Quantity.localCurrencyCode)
        #expect(TotalList(name: "A", currencyCode: "JPY").currencyCode == "JPY")
    }

    @Test("Deleting a list takes its items with it")
    func cascadeDelete() throws {
        container.mainContext.delete(list)
        try container.mainContext.save()

        let remaining = try container.mainContext.fetch(FetchDescriptor<Item>())
        #expect(remaining.isEmpty)
    }
}
