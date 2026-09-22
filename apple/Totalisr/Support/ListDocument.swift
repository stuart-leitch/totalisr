import Foundation
import SwiftData

/// The on-disk form of a shared list: plain JSON, readable in a text editor, versioned
/// so a future format can be recognised rather than misparsed.
///
/// Deliberately separate types from the `@Model` classes. Making the models `Codable`
/// would tangle persistence with transport and hand every future schema change a second
/// job.
struct ListDocument: Codable, Equatable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var list: ListPayload

    init(list: ListPayload) {
        self.formatVersion = Self.currentFormatVersion
        self.list = list
    }
}

struct ListPayload: Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var isFinancial: Bool
    var currencyCode: String
    var unitLabel: String
    var countsDown: Bool
    var items: [ItemPayload]
}

struct ItemPayload: Codable, Equatable {
    var label: String
    var amountMinorUnits: Int
    var note: String
    var date: Date
    var isDone: Bool
}

// MARK: - Errors

enum ListDocumentError: LocalizedError {
    case unsupportedFormatVersion(Int)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            "This list was saved by a newer version of Totalisr (format \(version))."
        case .unreadable(let reason):
            "That file isn't a Totalisr list: \(reason)"
        }
    }
}

// MARK: - Encoding

extension ListDocument {
    /// Pretty-printed with sorted keys: a shared file people can open and read is worth
    /// more than a few saved bytes.
    /// Dates are whole seconds, in ISO 8601.
    ///
    /// `Date` carries sub-second precision that ISO 8601 text does not, so rather than
    /// let encoding quietly drop it, `init(exporting:)` rounds on the way out. The
    /// precision of the format is then the precision of the document, a decode of an
    /// encode is exactly equal, and nothing is lost where it can't be seen. Item dates
    /// are days and `createdAt` only orders the sidebar, so whole seconds is ample.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// The precision the document format holds.
    static func storable(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded())
    }

    func encoded() throws -> Data {
        try Self.encoder().encode(self)
    }

    init(decoding data: Data) throws {
        let document: ListDocument
        do {
            document = try Self.decoder().decode(ListDocument.self, from: data)
        } catch {
            throw ListDocumentError.unreadable(error.localizedDescription)
        }
        guard document.formatVersion <= Self.currentFormatVersion else {
            throw ListDocumentError.unsupportedFormatVersion(document.formatVersion)
        }
        self = document
    }

    /// A filename safe on every platform, derived from the list's name.
    var suggestedFilename: String {
        let cleaned = list.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? "Totalisr List" : cleaned
        return "\(base).totalisr"
    }
}

// MARK: - Reading a list out of the store

@MainActor
extension ListDocument {
    init(exporting list: TotalList) {
        self.init(list: ListPayload(
            id: list.externalID,
            name: list.name,
            createdAt: ListDocument.storable(list.createdAt),
            isFinancial: list.isFinancial,
            currencyCode: list.currencyCode,
            unitLabel: list.unitLabel,
            countsDown: list.countsDown,
            items: list.orderedItems.map {
                ItemPayload(
                    label: $0.label,
                    amountMinorUnits: $0.amountMinorUnits,
                    note: $0.note,
                    date: ListDocument.storable($0.date),
                    isDone: $0.isDone
                )
            }
        ))
    }
}

// MARK: - Writing a list back into the store

/// Import replaces a list wholesale rather than merging it. Merging two divergent
/// orderings without per-item identity is guesswork, and guessing with someone's numbers
/// is worse than telling them plainly that the file wins.
@MainActor
enum ListImport {
    enum Outcome: Equatable {
        case created
        case replaced
    }

    /// Whether applying this document would overwrite something, without applying it —
    /// so the UI can ask before destroying anything.
    static func existingList(for document: ListDocument, in context: ModelContext) throws -> TotalList? {
        let id = document.list.id
        var descriptor = FetchDescriptor<TotalList>(predicate: #Predicate { $0.externalID == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    static func apply(_ document: ListDocument, to context: ModelContext) throws -> (outcome: Outcome, list: TotalList) {
        let existing = try existingList(for: document, in: context)

        let target: TotalList
        let outcome: Outcome

        if let existing {
            target = existing
            outcome = .replaced

            // Detach before deleting: `context.delete` alone leaves the items in the
            // relationship until the context next processes changes, and a half-replaced
            // list would total wrongly in between.
            let previous = existing.orderedItems
            existing.items?.removeAll()
            for item in previous {
                context.delete(item)
            }
        } else {
            target = TotalList()
            target.externalID = document.list.id
            context.insert(target)
            outcome = .created
        }

        target.name = document.list.name
        target.createdAt = document.list.createdAt
        target.isFinancial = document.list.isFinancial
        target.currencyCode = document.list.currencyCode
        target.unitLabel = document.list.unitLabel
        target.countsDown = document.list.countsDown

        // Order comes from the file's array order, not from any stored index.
        for payload in document.list.items {
            let item = Item(
                label: payload.label,
                amountMinorUnits: payload.amountMinorUnits,
                note: payload.note,
                date: payload.date,
                isDone: payload.isDone
            )
            context.insert(item)
            target.append(item)
        }

        return (outcome, target)
    }
}
