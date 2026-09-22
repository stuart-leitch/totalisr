# Totalisr (Apple)

A SwiftUI + SwiftData rewrite of the web prototype in the repo root. One target builds
for iPhone, iPad and Mac.

## Running it

Open `Totalisr.xcodeproj` in Xcode, pick a destination, and Run. There is no dependency
to fetch and nothing to generate.

**On this Mac.** Choose **My Mac** in the destination popup — it's the same target, and
it needs no Apple ID: macOS builds are signed ad-hoc (`CODE_SIGN_IDENTITY[sdk=macosx*] =
"-"`, what Xcode's UI calls "Sign to Run Locally").

**On an iPhone.** Set a Team under Signing & Capabilities first. A free Apple ID works;
the app then needs re-signing every 7 days.

The project file was written by hand using Xcode 16+ file-system-synchronized groups, so
adding a `.swift` file anywhere under `Totalisr/` or `TotalisrTests/` puts it in the
right target automatically — no project edit, no merge conflict.

## Tests

⌘U, or:

    xcodebuild test -project Totalisr.xcodeproj -scheme Totalisr -destination 'platform=macOS'

57 tests in `TotalisrTests/`, using Swift Testing. They cover the two things most likely
to break silently as features land: amount parsing (`MoneyTests.swift`) and the
list/ordering/total behaviour (`ModelTests.swift`).

Reordering and deletion are tested on `TotalList`, not through the UI — that is why
`move(fromOffsets:toOffset:)`, `moveUp(_:)`, `moveDown(_:)` and `remove(atOffsets:in:)`
live on the model rather than in `ItemsView`. Keep new behaviour there and it stays
testable.

Two notes for writing more:

- A suite that needs SwiftData must **store** its `ModelContainer` in a property. Bind it
  to `_` and it deallocates, taking every model with it — the failure is a crash in
  `BackingData.swift`, not a readable assertion.
- Anything locale-dependent takes an explicit argument. `Money.parseMinorUnits` accepts a
  `decimalSeparator` for exactly this reason; a suite that leans on the machine's locale
  passes at your desk and fails in CI.

## Layout

    Totalisr/
      TotalisrApp.swift        app entry, model container
      Models/TotalList.swift   a named list: currency, totals, ordering
      Models/Item.swift        one line: label, amount, note, date, paid
      Support/Quantity.swift   minor-unit storage, parsing, formatting
      Views/RootView.swift     NavigationSplitView: lists | items
      Views/ListsSidebar.swift the list of lists
      Models/AmountDirection.swift  which way an entry moves the total
      Views/ItemsView.swift    rows, reorder, delete, swipe-to-pay
      Views/ItemRow.swift      the three row layouts
      Views/TotalsSummary.swift  total / paid / remaining, pinned
      Views/QuickAddBar.swift  label + amount + return, always on screen
      Views/ItemEditor.swift   full form for one item
      Views/ListEditor.swift   list name, kind and direction

## Decisions worth knowing

**Amounts are stored in pence.** `amountMinorUnits` is a whole number of pence (cents,
or whatever the list's currency calls its hundredth) — £250.00 is stored as 25000.
Integers round-trip exactly through SwiftData and CloudKit; `Double` does not, and
CloudKit stores decimal attributes as doubles. See `Support/Money.swift`.

**The models are already CloudKit-shaped** — every property has a default, the
relationship is optional, nothing is uniquely constrained — so turning sync on is a
capability change rather than a migration. See `ICLOUD.md`.

**Each list has two options, and they are independent.** *Financial* decides whether
amounts format as currency or as plain numbers with a unit after them. *Count down / count
up* sets the direction new items start on — and nothing else. The arithmetic and the sign
convention are identical either way; a test asserts that, because "count down" is easy to
misread later as "invert the signs".

`isFinancial` + `currencyCode` + `unitLabel` is not the two-sources-of-truth problem
below: none is derivable from the others, the tick selects which is live, and the
inactive one keeps its value so flipping back restores the currency instead of losing it.

**Direction is derived, never stored.** The money-in / money-out control writes the sign
of `amountMinorUnits`; there is no second flag beside it. A stored direction and a signed
number are two sources of truth that eventually disagree, and the loser is always the one
the totals are computed from. See `Models/AmountDirection.swift`.

**The cases are named `adds` / `subtracts`, not income / expense.** Only `label` assumes
currency. A list of hours or kilometres needs the same two directions with different
words, and that is the only thing it would have to override.

**Order is explicit.** SwiftData makes no promise about the order of a to-many
relationship, so `Item.sortIndex` is the source of truth and `TotalList.orderedItems` is
the only way views read items.

**An empty amount is refused, not stored as zero.** The web version treated a blank
amount as 0, because `isNaN("")` is `false`.

## The app icon

Generated, not drawn by hand, so it can be regenerated or changed in one place:

    xcrun swiftc -O Tools/MakeAppIcon.swift -o /tmp/makeicon
    /tmp/makeicon Totalisr/Assets.xcassets/AppIcon.appiconset

A summation sigma on a green gradient. iOS gets a full-bleed opaque square (the system
masks it); macOS gets the rounded shape and its margin baked in, at all ten sizes.

## Not done yet

- Swift language mode is 5, not 6.
- No UI tests. The views are thin, but `QuickAddBar`'s focus handling isn't covered.
  `RowLayout.forWidth` is tested directly instead, including that no current iPhone width
  falls back to the stacked layout.
- Nothing keeps the Xcode project's own wiring honest — `TEST_HOST`, asset compilation,
  signing. `⌘U` is the check on that.
- No receipt capture, attachments, or anything resembling an accounting package. The tool
  totals a list of numbers.
