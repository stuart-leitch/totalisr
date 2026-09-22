import SwiftUI

/// Name, kind and direction for a list. Used for both "New List" and "Rename…".
struct ListEditor: View {
    let list: TotalList

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isFinancial = true
    @State private var currencyCode = Quantity.localCurrencyCode
    @State private var unitLabel = ""
    @State private var countsDown = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onSubmit(save)
                }

                Section {
                    Toggle("Financial", isOn: $isFinancial)

                    if isFinancial {
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(currencyOptions, id: \.self) { code in
                                Text(currencyLabel(code)).tag(code)
                            }
                        }
                    } else {
                        TextField("Unit", text: $unitLabel, prompt: Text("hrs, km, points…"))
                    }
                } footer: {
                    Text(isFinancial
                         ? "Amounts are shown as currency."
                         : "Amounts are shown as plain numbers, with the unit after them.")
                }

                Section {
                    Picker("New items", selection: $countsDown) {
                        Text("Count down").tag(true)
                        Text("Count up").tag(false)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Direction")
                } footer: {
                    Text(countsDown
                         ? "New items take away by default — a budget being spent down. You can still flip any single item the other way."
                         : "New items add by default — a total being built up. You can still flip any single item the other way.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(list.name.isEmpty ? "New List" : "List Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 420)
        .onAppear {
            name = list.name
            isFinancial = list.isFinancial
            currencyCode = list.currencyCode
            unitLabel = list.unitLabel
            countsDown = list.countsDown
        }
    }

    /// The list's own currency is always offered, even if it isn't one of the suggestions.
    private var currencyOptions: [String] {
        Quantity.suggestedCurrencyCodes.contains(currencyCode)
            ? Quantity.suggestedCurrencyCodes
            : [currencyCode] + Quantity.suggestedCurrencyCodes
    }

    private func currencyLabel(_ code: String) -> String {
        guard let name = Locale.current.localizedString(forCurrencyCode: code) else { return code }
        return "\(code) — \(name)"
    }

    private func save() {
        list.name = name
        list.isFinancial = isFinancial
        list.currencyCode = currencyCode
        list.unitLabel = unitLabel
        list.countsDown = countsDown
        dismiss()
    }
}
