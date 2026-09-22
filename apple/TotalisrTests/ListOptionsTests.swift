import Foundation
import SwiftData
import Testing
@testable import Totalisr

@MainActor
@Suite("List options")
struct ListOptionsTests {
    let container: ModelContainer
    let list: TotalList

    init() throws {
        container = try ModelContainer(
            for: TotalList.self, Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        list = TotalList(name: "Trip", currencyCode: "GBP")
        container.mainContext.insert(list)
    }

    @Test("A new list is financial and counts down")
    func defaults() {
        #expect(list.isFinancial)
        #expect(list.countsDown)
        #expect(list.defaultDirection == .subtracts)
        #expect(list.doneLabel == "Paid")
    }

    @Test("Counting up flips the default direction for new items")
    func countUp() {
        list.countsDown = false
        #expect(list.defaultDirection == .adds)
    }

    /// The direction option changes only what a new item starts as. Whatever it is set
    /// to, the arithmetic below it is identical — this is the guard against someone
    /// later reading "count down" as "invert the sign convention".
    @Test("Direction does not change the arithmetic")
    func directionIsEntryOnlyNotMaths() {
        for counting in [true, false] {
            list.countsDown = counting

            let budget = Item(label: "Budget", amountMinorUnits: 100_000)
            let spend = Item(label: "Flights", amountMinorUnits: -25_000)
            for item in [budget, spend] {
                container.mainContext.insert(item)
                list.append(item)
            }

            #expect(list.totalMinorUnits == 75_000)
            #expect(list.runningBalances == [100_000, 75_000])

            list.remove(atOffsets: IndexSet([0, 1]), in: container.mainContext)
        }
    }

    @Test("A financial list formats as currency")
    func financialFormatting() {
        let formatted = list.formatted(100_050)
        let hasDigits = formatted.contains(where: \.isNumber)
        #expect(hasDigits)
        #expect(formatted != "1000.5")
    }

    @Test("A non-financial list formats as a plain number with its unit")
    func plainFormatting() {
        list.isFinancial = false
        list.unitLabel = "km"

        #expect(list.formatted(1_200) == "12 km")
        #expect(list.formatted(1_250) == "12.5 km")
        #expect(list.doneLabel == "Done")
    }

    @Test("A non-financial list with no unit is just the number")
    func plainFormattingWithoutUnit() {
        list.isFinancial = false
        list.unitLabel = "   "

        #expect(list.formatted(1_200) == "12")
    }

    /// Currency and unit both survive the tick being flipped, so switching a list to
    /// non-financial and back does not silently lose the currency.
    @Test("The inactive field keeps its value")
    func inactiveFieldSurvives() {
        list.currencyCode = "JPY"
        list.isFinancial = false
        list.unitLabel = "hrs"

        #expect(list.currencyCode == "JPY")

        list.isFinancial = true
        #expect(list.currencyCode == "JPY")
        #expect(list.unitLabel == "hrs")
    }
}
