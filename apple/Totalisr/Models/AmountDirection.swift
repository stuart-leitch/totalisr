import Foundation

/// Which way an entry moves the total.
///
/// This is *derived from the sign of the amount*, never stored alongside it. A stored
/// flag and a signed number are two sources of truth that will eventually disagree, and
/// the one that loses is always the one the totals are computed from.
///
/// The cases are named for what they do to the total rather than for money, because a
/// list of hours or kilometres needs the same two directions with different words — so
/// the labels take the list's `isFinancial` and the arithmetic never varies.
enum AmountDirection: String, CaseIterable, Identifiable {
    /// The default: on a budget being burned down, most entries take money away.
    case subtracts
    case adds

    var id: String { rawValue }

    /// Wording depends on the list: money has its own vocabulary, everything else falls
    /// back to what the direction literally does to the total.
    func label(financial: Bool) -> String {
        switch (self, financial) {
        case (.subtracts, true): "Money out"
        case (.adds, true): "Money in"
        case (.subtracts, false): "Subtract"
        case (.adds, false): "Add"
        }
    }

    /// The short form, for the entry bar where there is no room for the full label.
    func shortLabel(financial: Bool) -> String {
        switch (self, financial) {
        case (.subtracts, true): "Out"
        case (.adds, true): "In"
        case (.subtracts, false): "Less"
        case (.adds, false): "More"
        }
    }

    var symbolName: String {
        switch self {
        case .subtracts: "arrow.down"
        case .adds: "arrow.up"
        }
    }

    var opposite: AmountDirection {
        self == .subtracts ? .adds : .subtracts
    }

    /// Applies this direction to a typed magnitude. The control wins over any sign the
    /// user typed, so "250" and "-250" both mean the same thing once a direction is set.
    func applied(toMagnitude magnitude: Int) -> Int {
        switch self {
        case .subtracts: -abs(magnitude)
        case .adds: abs(magnitude)
        }
    }

    /// Reads the direction back off a stored amount. Zero counts as `subtracts` so a
    /// blank new entry starts on the default rather than flipping to "money in".
    static func of(_ minorUnits: Int) -> AmountDirection {
        minorUnits > 0 ? .adds : .subtracts
    }
}
