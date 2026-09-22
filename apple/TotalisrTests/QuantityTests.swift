import Foundation
import Testing
@testable import Totalisr

/// Every test passes `decimalSeparator` explicitly. The parser defaults to the current
/// locale's, which is right for the app and wrong for a test suite that has to give the
/// same answer on any machine.
@Suite("Amount parsing")
struct MoneyParsingTests {

    @Test("Whole numbers")
    func wholeNumbers() {
        #expect(Quantity.parseMinorUnits("0", decimalSeparator: ".") == 0)
        #expect(Quantity.parseMinorUnits("1", decimalSeparator: ".") == 100)
        #expect(Quantity.parseMinorUnits("250", decimalSeparator: ".") == 25_000)
        #expect(Quantity.parseMinorUnits(" 250 ", decimalSeparator: ".") == 25_000)
    }

    @Test("Decimals")
    func decimals() {
        #expect(Quantity.parseMinorUnits("1.5", decimalSeparator: ".") == 150)
        #expect(Quantity.parseMinorUnits("1.55", decimalSeparator: ".") == 155)
        #expect(Quantity.parseMinorUnits("0.01", decimalSeparator: ".") == 1)
        #expect(Quantity.parseMinorUnits(".5", decimalSeparator: ".") == 50)
        #expect(Quantity.parseMinorUnits("250.", decimalSeparator: ".") == 25_000)
    }

    @Test("More than two decimal places round to the nearest penny")
    func rounding() {
        #expect(Quantity.parseMinorUnits("1.554", decimalSeparator: ".") == 155)
        #expect(Quantity.parseMinorUnits("1.555", decimalSeparator: ".") == 156)
        #expect(Quantity.parseMinorUnits("1.556", decimalSeparator: ".") == 156)
    }

    @Test("Negatives, including the Unicode minus an iOS keypad can produce")
    func negatives() {
        #expect(Quantity.parseMinorUnits("-250", decimalSeparator: ".") == -25_000)
        #expect(Quantity.parseMinorUnits("-0.01", decimalSeparator: ".") == -1)
        #expect(Quantity.parseMinorUnits("\u{2212}250", decimalSeparator: ".") == -25_000)
        #expect(Quantity.parseMinorUnits("-1,000.50", decimalSeparator: ".") == -100_050)
    }

    @Test("A lone foreign separator with three digits after it is grouping, not a decimal point")
    func groupingHeuristic() {
        #expect(Quantity.parseMinorUnits("1,000", decimalSeparator: ".") == 100_000)
        #expect(Quantity.parseMinorUnits("1,50", decimalSeparator: ".") == 150)
        #expect(Quantity.parseMinorUnits("1.000", decimalSeparator: ",") == 100_000)
        #expect(Quantity.parseMinorUnits("1.50", decimalSeparator: ",") == 150)
    }

    @Test("A repeated separator can only be grouping")
    func repeatedSeparator() {
        #expect(Quantity.parseMinorUnits("1,000,000", decimalSeparator: ".") == 100_000_000)
        #expect(Quantity.parseMinorUnits("1.000.000", decimalSeparator: ".") == 100_000_000)
    }

    @Test("With both separators present, the last one is the decimal point")
    func mixedSeparators() {
        #expect(Quantity.parseMinorUnits("1,000.50", decimalSeparator: ".") == 100_050)
        #expect(Quantity.parseMinorUnits("1.000,50", decimalSeparator: ".") == 100_050)
        #expect(Quantity.parseMinorUnits("1,000.50", decimalSeparator: ",") == 100_050)
        #expect(Quantity.parseMinorUnits("1.000,50", decimalSeparator: ",") == 100_050)
    }

    @Test("Input with no digits is refused rather than treated as zero")
    func refusesNonNumeric() {
        #expect(Quantity.parseMinorUnits("", decimalSeparator: ".") == nil)
        #expect(Quantity.parseMinorUnits("   ", decimalSeparator: ".") == nil)
        #expect(Quantity.parseMinorUnits("abc", decimalSeparator: ".") == nil)
        #expect(Quantity.parseMinorUnits("-", decimalSeparator: ".") == nil)
        #expect(Quantity.parseMinorUnits(".", decimalSeparator: ".") == nil)
        #expect(Quantity.parseMinorUnits("£", decimalSeparator: ".") == nil)
    }

    @Test("Stray currency symbols and spaces are ignored")
    func ignoresDecoration() {
        #expect(Quantity.parseMinorUnits("£250", decimalSeparator: ".") == 25_000)
        #expect(Quantity.parseMinorUnits("250 GBP", decimalSeparator: ".") == 25_000)
        #expect(Quantity.parseMinorUnits("1 000", decimalSeparator: ".") == 100_000)
    }
}

@Suite("Amount conversion and formatting")
struct MoneyConversionTests {

    @Test("Minor units convert to an exact decimal")
    func exactConversion() {
        #expect(Quantity.amount(fromMinorUnits: 0) == Decimal(0))
        #expect(Quantity.amount(fromMinorUnits: 1) == Decimal(string: "0.01"))
        #expect(Quantity.amount(fromMinorUnits: -25_000) == Decimal(string: "-250"))
        #expect(Quantity.amount(fromMinorUnits: 100_050) == Decimal(string: "1000.50"))
    }

    @Test("Decimals convert to minor units, rounding half away from zero")
    func conversionRounds() {
        #expect(Quantity.minorUnits(from: Decimal(string: "1.005")!) == 101)
        #expect(Quantity.minorUnits(from: Decimal(string: "-1.005")!) == -101)
        #expect(Quantity.minorUnits(from: Decimal(string: "0.004")!) == 0)
    }

    /// Guards the one thing the editor depends on: opening an item and saving it without
    /// touching the amount must not change the amount.
    @Test("Editable strings round-trip through the parser in the current locale")
    func editRoundTrip() {
        for units in [0, 1, -1, 150, -25_000, 100_050, 999_999_99] {
            let text = Quantity.editableString(minorUnits: units)
            #expect(Quantity.parseMinorUnits(text) == units, "round trip failed for \(units) via \"\(text)\"")
        }
    }

    @Test("Editable strings carry no grouping separators")
    func editableHasNoGrouping() {
        let text = Quantity.editableString(minorUnits: 100_000_000)
        let separatorCount = text.filter { $0 == "." || $0 == "," }.count
        #expect(!text.contains(","))
        #expect(separatorCount <= 1)
    }

    /// The symbol is locale-dependent (GBP may render "£" or "GB£" depending on where
    /// you are), so this checks only the properties the UI relies on.
    @Test("Every currency code yields a usable symbol")
    func currencySymbols() {
        for code in Quantity.suggestedCurrencyCodes {
            let symbol = Quantity.symbol(for: code)
            let hasDigits = symbol.contains(where: \.isNumber)
            #expect(!symbol.isEmpty, "no symbol for \(code)")
            #expect(!hasDigits, "symbol for \(code) contains digits: \(symbol)")
        }
    }

    @Test("An unrecognised currency code falls back to something printable")
    func unknownCurrencySymbol() {
        #expect(!Quantity.symbol(for: "ZZZ").isEmpty)
    }

    /// Formatting is locale-dependent, so this checks only what must be true everywhere.
    @Test("Formatting produces something with the digits in it")
    func formatting() {
        // Bound outside the macro: #expect can't expand a call to a rethrows function.
        let formatted = Quantity.formatted(minorUnits: 100_050, currencyCode: "GBP")
        let hasDigits = formatted.contains(where: \.isNumber)
        #expect(hasDigits)
        #expect(!Quantity.formatted(minorUnits: 0, currencyCode: "GBP").isEmpty)
    }
}
