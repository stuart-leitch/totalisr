import SwiftUI

/// How one row arranges itself. Columns are worth keeping as far down as they will go —
/// a stack of numbers in the same row is hard to scan — so the stacked form is a
/// fallback for genuinely cramped cases, not the normal iPhone layout.
enum RowLayout {
    case wideColumns
    case compactColumns
    case stacked

    /// Chosen from the measured width, not the size class: a Mac window reports
    /// `.regular` however narrow it is dragged. Accessibility text sizes go straight to
    /// stacked, because at those sizes a single amount can be wider than a whole column.
    static func forWidth(_ width: CGFloat, accessibilityTextSize: Bool) -> RowLayout {
        if accessibilityTextSize { return .stacked }
        if width >= 520 { return .wideColumns }
        if width >= 330 { return .compactColumns }
        return .stacked
    }

    var isColumns: Bool { self != .stacked }

    /// Every iPhone is 375–440pt wide, so they all land on `compactColumns`; the narrower
    /// amount column and smaller figures are what make three columns fit there.
    var amountColumnWidth: CGFloat? {
        switch self {
        case .wideColumns: 112
        case .compactColumns: 84
        case .stacked: nil
        }
    }

    var amountFont: Font {
        switch self {
        case .wideColumns: .body
        case .compactColumns: .footnote
        case .stacked: .body
        }
    }

    var spacing: CGFloat {
        self == .wideColumns ? 12 : 8
    }
}

/// The per-row buttons are a desktop affordance: on iOS the same actions live on the
/// swipe, the context menu and the editor, so the column collapses to nothing.
#if os(macOS)
private let actionsColumnWidth: CGFloat = 96
#else
private let actionsColumnWidth: CGFloat = 0
#endif

struct ColumnHeader: View {
    let layout: RowLayout
    let showRunningBalance: Bool

    var body: some View {
        HStack(spacing: layout.spacing) {
            Text("Item")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Amount")
                .frame(width: layout.amountColumnWidth, alignment: .trailing)
            if showRunningBalance {
                Text("Running")
                    .frame(width: layout.amountColumnWidth, alignment: .trailing)
            }
            Color.clear.frame(width: actionsColumnWidth, height: 1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

struct ItemRow: View {
    let item: Item
    let list: TotalList
    let runningBalance: Int
    let showRunningBalance: Bool
    let layout: RowLayout
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: layout.spacing) {
            label

            if layout.isColumns {
                amount
                if showRunningBalance { running }
            } else {
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    amount
                    if showRunningBalance { running.font(.caption) }
                }
            }

            #if os(macOS)
            actions
            #endif
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.displayLabel)
                    .lineLimit(1)
                if item.isDone { DoneTag(text: list.doneLabel) }
            }
            Text(itemSubtitle(item))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: layout.isColumns ? .infinity : nil, alignment: .leading)
    }

    /// Item amounts are not coloured. Most entries on a budget are negative, so red on
    /// every one of them says nothing; red is reserved for the running balance and the
    /// total, where it marks the thing actually worth noticing.
    private var amount: some View {
        Text(list.formatted(item.amountMinorUnits))
            .font(layout.amountFont)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: layout.amountColumnWidth, alignment: .trailing)
    }

    private var running: some View {
        Text(list.formatted(runningBalance))
            .font(layout.amountFont)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(runningBalance < 0 ? Color.red : Color.secondary)
            .frame(width: layout.amountColumnWidth, alignment: .trailing)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(item.isDone ? "Mark as Not \(list.doneLabel)" : "Mark as \(list.doneLabel)", systemImage: "checkmark") {
                item.isDone.toggle()
            }
            .foregroundStyle(item.isDone ? Color.green : Color.secondary)

            Button("Edit", systemImage: "pencil", action: onEdit)

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to reorder")
                .accessibilityHidden(true)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(width: actionsColumnWidth, alignment: .trailing)
    }
}

private func itemSubtitle(_ item: Item) -> String {
    let date = item.date.formatted(.dateTime.day().month(.abbreviated).year())
    return item.hasNote ? "\(item.note) · \(date)" : date
}

/// Done state reads as a tag on the item, not as a checkbox in the leading position —
/// a column of circles down the left edge looks like a multi-select list.
private struct DoneTag: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.green, in: Capsule())
            .accessibilityLabel(text)
    }
}
