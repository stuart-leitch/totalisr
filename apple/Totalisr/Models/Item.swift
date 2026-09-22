import Foundation
import SwiftData

/// One line in a list: a label and a signed amount. Negative amounts are how you
/// subtract, exactly as in the original web version.
@Model
final class Item {
    var label: String = ""
    var amountMinorUnits: Int = 0
    var note: String = ""
    var date: Date = Date.now
    var isDone: Bool = false
    var sortIndex: Int = 0
    var list: TotalList?

    init(label: String = "", amountMinorUnits: Int = 0, note: String = "", date: Date = .now, isDone: Bool = false) {
        self.label = label
        self.amountMinorUnits = amountMinorUnits
        self.note = note
        self.date = date
        self.isDone = isDone
        self.sortIndex = 0
    }

    var amount: Decimal {
        get { Quantity.amount(fromMinorUnits: amountMinorUnits) }
        set { amountMinorUnits = Quantity.minorUnits(from: newValue) }
    }

    var displayLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : label
    }

    var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
