import SwiftUI

/// The full form for one item. Reached by tapping a row — replacing the web version's
/// "delete the row and put it back in the input boxes" edit, which lost the item if you
/// changed your mind.
struct ItemEditor: View {
    let item: Item
    let list: TotalList

    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var amount = ""
    @State private var direction = AmountDirection.subtracts
    @State private var note = ""
    @State private var date = Date.now
    @State private var isDone = false

    private var parsedAmount: Int? { Quantity.parseMinorUnits(amount) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item", text: $label)
                    Picker("Direction", selection: $direction) {
                        ForEach(AmountDirection.allCases) { option in
                            Text(option.label(financial: list.isFinancial)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 4) {
                        Text("Amount")
                        Spacer(minLength: 12)
                        if list.isFinancial {
                            Text(Quantity.symbol(for: list.currencyCode))
                                .foregroundStyle(.secondary)
                        }
                        TextField("0", text: $amount)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .foregroundStyle(amount.isEmpty || parsedAmount != nil ? Color.primary : Color.red)
                            .frame(maxWidth: 140)
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            #endif
                    }
                } footer: {
                    Text(list.isFinancial
                         ? "Amounts are in \(list.currencyCode), which you can change under List Details."
                         : "Amounts are plain numbers, set under List Details.")
                }

                Section {
                    Toggle(list.doneLabel, isOn: $isDone)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).disabled(parsedAmount == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 320)
        .onAppear {
            label = item.label
            // The field holds the magnitude; the sign lives in the direction control, so
            // the two can never show contradictory things.
            amount = Quantity.editableString(minorUnits: abs(item.amountMinorUnits))
            direction = AmountDirection.of(item.amountMinorUnits)
            note = item.note
            date = item.date
            isDone = item.isDone
        }
    }

    private func save() {
        guard let parsedAmount else { return }
        item.label = label
        item.amountMinorUnits = direction.applied(toMagnitude: parsedAmount)
        item.note = note
        item.date = date
        item.isDone = isDone
        dismiss()
    }
}
