import Foundation
import SwiftUI
import Testing
@testable import Totalisr

@Suite("Entry direction")
struct AmountDirectionTests {

    @Test("Money out subtracts, whatever sign was typed")
    func subtracts() {
        #expect(AmountDirection.subtracts.applied(toMagnitude: 25_000) == -25_000)
        #expect(AmountDirection.subtracts.applied(toMagnitude: -25_000) == -25_000)
        #expect(AmountDirection.subtracts.applied(toMagnitude: 0) == 0)
    }

    @Test("Money in adds, whatever sign was typed")
    func adds() {
        #expect(AmountDirection.adds.applied(toMagnitude: 100_000) == 100_000)
        #expect(AmountDirection.adds.applied(toMagnitude: -100_000) == 100_000)
        #expect(AmountDirection.adds.applied(toMagnitude: 0) == 0)
    }

    /// Direction is derived from the sign rather than stored beside it, so this is the
    /// guard that the two can never be read back as disagreeing.
    @Test("Direction reads back off the stored sign")
    func readBack() {
        #expect(AmountDirection.of(-25_000) == .subtracts)
        #expect(AmountDirection.of(100_000) == .adds)
    }

    @Test("A zero amount reads as money out, so a blank entry starts on the default")
    func zeroIsTheDefault() {
        #expect(AmountDirection.of(0) == .subtracts)
    }

    @Test("Applying a direction and reading it back round-trips")
    func roundTrip() {
        for direction in AmountDirection.allCases {
            for magnitude in [1, 250, 100_000] {
                let stored = direction.applied(toMagnitude: magnitude)
                #expect(AmountDirection.of(stored) == direction)
                #expect(abs(stored) == magnitude)
            }
        }
    }

    @Test("Labels follow the list's kind rather than assuming money")
    func labels() {
        #expect(AmountDirection.subtracts.label(financial: true) == "Money out")
        #expect(AmountDirection.adds.label(financial: true) == "Money in")
        #expect(AmountDirection.subtracts.label(financial: false) == "Subtract")
        #expect(AmountDirection.adds.label(financial: false) == "Add")

        for direction in AmountDirection.allCases {
            for financial in [true, false] {
                #expect(!direction.shortLabel(financial: financial).isEmpty)
            }
        }
    }

    @Test("Opposite flips and flips back")
    func opposite() {
        #expect(AmountDirection.subtracts.opposite == .adds)
        #expect(AmountDirection.adds.opposite == .subtracts)
        #expect(AmountDirection.subtracts.opposite.opposite == .subtracts)
    }
}

@Suite("Row layout")
struct RowLayoutTests {

    /// Every current iPhone is 375–440pt wide. If a change to the thresholds drops them
    /// back to the stacked fallback, this is what says so.
    @Test("Every iPhone width gets columns")
    func iPhonesGetColumns() {
        for width in [375.0, 390.0, 393.0, 402.0, 430.0, 440.0] as [CGFloat] {
            let layout = RowLayout.forWidth(width, accessibilityTextSize: false)
            #expect(layout == .compactColumns, "width \(width) fell back to \(layout)")
            #expect(layout.isColumns)
        }
    }

    @Test("Mac and iPad widths get the roomier columns")
    func wideGetsWideColumns() {
        #expect(RowLayout.forWidth(744, accessibilityTextSize: false) == .wideColumns)
        #expect(RowLayout.forWidth(900, accessibilityTextSize: false) == .wideColumns)
    }

    @Test("Very narrow widths stack")
    func narrowStacks() {
        #expect(RowLayout.forWidth(320, accessibilityTextSize: false) == .stacked)
        #expect(RowLayout.forWidth(0, accessibilityTextSize: false) == .stacked)
    }

    @Test("Accessibility text sizes stack at any width")
    func accessibilitySizesStack() {
        for width in [390.0, 744.0, 1400.0] as [CGFloat] {
            #expect(RowLayout.forWidth(width, accessibilityTextSize: true) == .stacked)
        }
    }

    @Test("Only the stacked layout has no fixed amount column")
    func columnWidths() {
        #expect(RowLayout.wideColumns.amountColumnWidth != nil)
        #expect(RowLayout.compactColumns.amountColumnWidth != nil)
        #expect(RowLayout.stacked.amountColumnWidth == nil)
        #expect(RowLayout.compactColumns.amountColumnWidth! < RowLayout.wideColumns.amountColumnWidth!)
    }
}
