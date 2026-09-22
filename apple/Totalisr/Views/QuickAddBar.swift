import SwiftUI
import SwiftData

/// Label + direction + amount + return, the way the web version's footer row worked.
/// Keeping fast entry on the main screen matters more than a tidy toolbar; the full
/// editor (notes, date, done) is a tap away on any row.
///
/// On a phone all five controls in one row leaves the item field too narrow to read what
/// you are typing, so it splits: the name gets a row of its own and the numbers sit
/// underneath.
struct QuickAddBar: View {
    let list: TotalList
    let compact: Bool

    @Environment(\.modelContext) private var context
    @State private var label = ""
    @State private var amount = ""
    @State private var direction: AmountDirection
    @FocusState private var focus: Field?

    private enum Field { case label, amount }

    init(list: TotalList, compact: Bool) {
        self.list = list
        self.compact = compact
        _direction = State(initialValue: list.defaultDirection)
    }

    private var parsedAmount: Int? { Quantity.parseMinorUnits(amount) }
    private var canAdd: Bool { parsedAmount != nil }

    var body: some View {
        Group {
            if compact {
                // The direction button rides on the item row so both text fields start
                // at the same x — offsetting them made the bar read as a diagonal.
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        itemField
                        directionButton
                    }
                    HStack(spacing: 8) {
                        currencySymbol
                        amountField
                        addButton
                    }
                }
            } else {
                HStack(spacing: 8) {
                    itemField
                    directionButton
                    currencySymbol
                    amountField
                    addButton
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var itemField: some View {
        TextField("Item", text: $label)
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .label)
            .onSubmit { focus = .amount }
    }

    /// Spelled out rather than an arrow: a control that silently flips the sign of
    /// everything you type has to say what it is currently doing.
    private var directionButton: some View {
        Button {
            direction = direction.opposite
        } label: {
            Label(direction.shortLabel(financial: list.isFinancial), systemImage: direction.symbolName)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(direction == .adds ? .green : .secondary)
        .help(direction.label(financial: list.isFinancial))
        .accessibilityLabel(direction.label(financial: list.isFinancial))
        .accessibilityHint("Switches to \(direction.opposite.label(financial: list.isFinancial))")
    }

    @ViewBuilder
    private var currencySymbol: some View {
        if list.isFinancial {
            Text(Quantity.symbol(for: list.currencyCode))
                .foregroundStyle(.secondary)
        }
    }

    private var amountField: some View {
        TextField("Amount", text: $amount)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: compact ? .infinity : 96)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .focused($focus, equals: .amount)
            .onSubmit(add)
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #endif
            // Turns red on unparseable input, as the web version did — but the Add button
            // is also disabled, so nothing can slip through as a silent zero.
            .foregroundStyle(amount.isEmpty || canAdd ? Color.primary : Color.red)
    }

    private var addButton: some View {
        Button("Add Item", systemImage: "plus.circle.fill", action: add)
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .foregroundStyle(canAdd ? Color.accentColor : .secondary)
    }

    private func add() {
        guard let magnitude = parsedAmount else {
            focus = .amount
            return
        }

        let item = Item(label: label, amountMinorUnits: direction.applied(toMagnitude: magnitude))
        context.insert(item)
        list.append(item)

        label = ""
        amount = ""
        // The direction is deliberately *not* reset: entering several money-in lines in a
        // row should not mean flipping the control back every time.
        focus = .label
    }
}
