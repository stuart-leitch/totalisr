import Foundation
import SwiftData

/// A named list of items with a running total — the unit the app navigates between.
///
/// Every stored property has a default value and the relationship is optional, because
/// that is what SwiftData's CloudKit mirroring requires. The store is local until an
/// iCloud container is configured (see apple/ICLOUD.md), but the model is shaped for
/// sync from day one so turning it on is a build-settings change, not a migration.
@Model
final class TotalList {
    var name: String = ""
    var createdAt: Date = Date.now

    /// A stable identity that survives leaving this device.
    ///
    /// `persistentModelID` is local to one store and is no use for recognising a list
    /// that arrived from somewhere else, so shared files carry this instead. Not
    /// `@Attribute(.unique)` — CloudKit forbids unique constraints — so import looks it
    /// up by fetch rather than relying on the store to enforce it.
    var externalID: UUID = UUID()
    var currencyCode: String = Quantity.localCurrencyCode

    /// Financial lists format as currency; the rest format as plain numbers with
    /// `unitLabel` after them. The three fields are not redundant — the tick selects
    /// which of the other two is live, and the inactive one keeps its value so flipping
    /// back restores the currency rather than losing it.
    var isFinancial: Bool = true

    /// Only used when `isFinancial` is off: "hrs", "km", "pts". May be empty.
    var unitLabel: String = ""

    /// Which way new items lean. A budget being burned down counts down, so new entries
    /// default to taking away; a list accumulating hours or miles counts up. It sets the
    /// default of the per-item direction control and nothing else — the arithmetic and
    /// the sign convention are the same either way.
    var countsDown: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \Item.list)
    var items: [Item]? = []

    init(name: String = "", currencyCode: String? = nil) {
        self.name = name
        self.createdAt = .now
        self.externalID = UUID()
        self.currencyCode = currencyCode ?? Quantity.localCurrencyCode
        self.items = []
    }

    /// Items in user order. SwiftData makes no promise about the order of a to-many
    /// relationship, so `sortIndex` is the source of truth and this is the only way
    /// the views should read the items.
    var orderedItems: [Item] {
        (items ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalMinorUnits: Int {
        (items ?? []).reduce(0) { $0 + $1.amountMinorUnits }
    }

    var doneMinorUnits: Int {
        (items ?? []).filter(\.isDone).reduce(0) { $0 + $1.amountMinorUnits }
    }

    var remainingMinorUnits: Int {
        totalMinorUnits - doneMinorUnits
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled List" : name
    }

    func formatted(_ minorUnits: Int) -> String {
        isFinancial
            ? Quantity.formatted(minorUnits: minorUnits, currencyCode: currencyCode)
            : Quantity.formattedPlain(minorUnits: minorUnits, unit: unitLabel)
    }

    /// The direction a new item starts on.
    var defaultDirection: AmountDirection {
        countsDown ? .subtracts : .adds
    }

    /// Whether a negative figure is worth flagging in red.
    ///
    /// On a list counting down from a budget, crossing zero means overspent — the one
    /// thing you want to see coming. On a list counting up there is no budget to exceed,
    /// so a negative running total is just a number, and colouring it red cries wolf.
    var warnsOnNegative: Bool {
        countsDown
    }

    /// What `Item.isDone` is called in the UI. The flag means "settled"; a financial
    /// list says that as "Paid", a list of kilometres run says "Done".
    var doneLabel: String {
        isFinancial ? "Paid" : "Done"
    }

    /// Running balance after each item, accumulating from zero down the list.
    /// Index-aligned with `orderedItems`.
    var runningBalances: [Int] {
        var total = 0
        return orderedItems.map { item in
            total += item.amountMinorUnits
            return total
        }
    }

    /// Appends an item and gives it the next sort index.
    func append(_ item: Item) {
        item.sortIndex = (items ?? []).map(\.sortIndex).max().map { $0 + 1 } ?? 0
        item.list = self
        items?.append(item)
    }

    /// Rewrites `sortIndex` across the whole list so it stays 0..<n and gap-free.
    func reindex(_ ordered: [Item]) {
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
    }

    /// Reorders in place, matching SwiftUI's `onMove` offsets. Lives here rather than in
    /// the view so it can be tested without standing up a UI.
    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var ordered = orderedItems
        ordered.move(fromOffsets: offsets, toOffset: destination)
        reindex(ordered)
    }

    /// Moves one item one place towards the top.
    ///
    /// The `+ 2` in `moveDown` is not a typo: SwiftUI's `toOffset` is a position in the
    /// list *before* the move happens, so shifting down by one place means naming the
    /// slot two below. Wrapping it here keeps that off-by-one in one tested place
    /// instead of in every caller.
    func moveUp(_ index: Int) {
        guard index > 0, index < orderedItems.count else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    /// Moves one item one place towards the bottom.
    func moveDown(_ index: Int) {
        guard index >= 0, index < orderedItems.count - 1 else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
    }

    /// Deletes at SwiftUI's `onDelete` offsets and closes the gaps in `sortIndex`.
    ///
    /// The relationship is detached explicitly before `context.delete`, because deleting
    /// alone does not take the item out of `items` until the context next processes its
    /// changes — until then a deleted row still counts toward the total.
    func remove(atOffsets offsets: IndexSet, in context: ModelContext) {
        let ordered = orderedItems
        var remaining = ordered
        remaining.remove(atOffsets: offsets)

        let doomed = Set(offsets.map { ordered[$0].persistentModelID })
        items?.removeAll { doomed.contains($0.persistentModelID) }

        for item in ordered where doomed.contains(item.persistentModelID) {
            context.delete(item)
        }

        reindex(remaining)
    }
}
