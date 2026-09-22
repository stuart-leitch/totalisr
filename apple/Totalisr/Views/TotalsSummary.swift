import SwiftUI

/// Total, and the done/remaining split of it. Pinned above the quick-add bar so it's
/// always on screen — the total is the whole point of the app.
struct TotalsSummary: View {
    let list: TotalList

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            figure("Total", list.totalMinorUnits, emphasis: true)
            Divider().frame(height: 28)
            figure(list.doneLabel, list.doneMinorUnits, emphasis: false)
            Divider().frame(height: 28)
            figure("Remaining", list.remainingMinorUnits, emphasis: false)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func figure(_ caption: String, _ minorUnits: Int, emphasis: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(caption)
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(list.formatted(minorUnits))
                .font(emphasis ? .headline : .subheadline)
                .monospacedDigit()
                .foregroundStyle(list.warnsOnNegative && minorUnits < 0 ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
