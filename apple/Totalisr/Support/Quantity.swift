import Foundation

/// Amounts are stored as a whole number of hundredths — pence, cents, or hundredths of
/// an hour on a list that isn't financial at all — rather than as `Double` or `Decimal`.
///
/// Integers round-trip exactly through SwiftData *and* CloudKit; `Double` does not, and
/// CloudKit stores decimal attributes as doubles. Money that drifts by 0.000001 is money
/// you can't reconcile, so the storage type is the one that can't drift.
///
/// The scale is fixed at 2 regardless of currency. Zero-decimal currencies (JPY, KRW)
/// still work: the formatter drops the fraction on display, and entry is in whole units.
enum Quantity {
    static let minorUnitsPerUnit = 100

    /// The user's currency, used as the default for new lists.
    static var localCurrencyCode: String {
        Locale.current.currency?.identifier ?? "GBP"
    }

    static func minorUnits(from amount: Decimal) -> Int {
        var scaled = amount * Decimal(minorUnitsPerUnit)
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func amount(fromMinorUnits units: Int) -> Decimal {
        Decimal(units) / Decimal(minorUnitsPerUnit)
    }

    static func formatted(minorUnits units: Int, currencyCode: String) -> String {
        amount(fromMinorUnits: units).formatted(.currency(code: currencyCode))
    }

    /// For lists that aren't financial: a plain number with an optional unit after it
    /// ("12.5 hrs"). No currency symbol, no forced two decimal places — 12 kilometres
    /// should read as "12 km", not "12.00 km".
    static func formattedPlain(minorUnits units: Int, unit: String) -> String {
        let number = amount(fromMinorUnits: units).formatted(.number.precision(.fractionLength(0...2)))
        let label = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? number : "\(number) \(label)"
    }

    /// Reads a typed amount into minor units, leniently.
    ///
    /// Accepts a leading `-` (hyphen or the Unicode minus an iOS keypad can produce) and
    /// both `.` and `,`, working out which is the decimal point and which is grouping:
    ///
    /// - both present → the last one is the decimal point ("1,000.50" and "1.000,50")
    /// - one, repeated → grouping ("1,000,000")
    /// - one, matching the locale's decimal separator → decimal point ("1.5" in en_GB)
    /// - one, foreign → grouping if exactly three digits follow, else a decimal point,
    ///   so "1,000" is a thousand but "1,50" is one-fifty
    ///
    /// Returns nil for anything with no digits in it, which is how the UI knows to refuse
    /// the entry rather than store a silent zero — the original web version treated a
    /// blank amount as 0, because `isNaN("")` is `false`.
    ///
    /// `decimalSeparator` defaults to the current locale's; pass it explicitly to get a
    /// deterministic result regardless of where the code is running.
    static func parseMinorUnits(_ input: String, decimalSeparator: Character? = nil) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isNegative = trimmed.hasPrefix("-") || trimmed.hasPrefix("\u{2212}")
        let separators: Set<Character> = [".", ","]
        let decimalPoint = decimalSeparator ?? Locale.current.decimalSeparator?.first ?? "."
        let body = trimmed.filter { $0.isNumber || separators.contains($0) }

        var integerPart = body
        var fractionPart = ""

        let separatorIndices = body.indices.filter { separators.contains(body[$0]) }
        if let last = separatorIndices.last {
            let tail = String(body[body.index(after: last)...])
            let distinctSeparators = Set(separatorIndices.map { body[$0] })

            let isDecimalPoint: Bool
            if distinctSeparators.count > 1 {
                isDecimalPoint = true
            } else if separatorIndices.count > 1 {
                isDecimalPoint = false
            } else if body[last] == decimalPoint {
                isDecimalPoint = true
            } else {
                isDecimalPoint = tail.count != 3
            }

            if isDecimalPoint {
                integerPart = String(body[..<last])
                fractionPart = tail
            }
        }

        let digits = integerPart.filter(\.isNumber)
        let fractionDigits = fractionPart.filter(\.isNumber)
        guard !(digits.isEmpty && fractionDigits.isEmpty) else { return nil }

        let normalized = fractionDigits.isEmpty ? digits : digits + "." + fractionDigits
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return nil }

        let units = minorUnits(from: value)
        return isNegative ? -units : units
    }

    /// Plain digits for editing, without currency symbol or grouping — what belongs in a
    /// text field the user is about to retype. Round-trips through `parseMinorUnits`.
    static func editableString(minorUnits units: Int) -> String {
        amount(fromMinorUnits: units).formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    /// The symbol for a currency code ("£" for GBP), localized like the formatter's own
    /// output. Falls back to the code itself for a currency with no symbol.
    static func symbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        guard let symbol = formatter.currencySymbol, !symbol.isEmpty else { return currencyCode }
        return symbol
    }

    /// Currencies offered when creating or renaming a list.
    static let suggestedCurrencyCodes = ["GBP", "EUR", "USD", "CAD", "AUD", "JPY", "CHF", "SEK", "NOK", "DKK"]
}
