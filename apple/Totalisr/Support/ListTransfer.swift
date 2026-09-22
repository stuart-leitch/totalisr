import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in Info.plist as an exported type, which is what makes AirDrop offer
    /// Totalisr as a destination for a `.totalisr` file rather than filing it under
    /// "everything else".
    ///
    /// Resolved by identifier and *not* with `UTType(exportedAs:)`, which raises a fatal
    /// error when the declaration is missing. Falling back to plain JSON means a problem
    /// with the Info.plist costs the file its custom icon and its "open in Totalisr"
    /// association, rather than crashing the app the moment a share button appears.
    static var totalisrList: UTType {
        UTType("com.stuartleitch.totalisr.list") ?? .json
    }
}

/// What `ShareLink` hands to AirDrop, Messages, Files and the rest. Carries the bytes
/// directly instead of writing a temporary file, so nothing has to be cleaned up.
struct SharedList: Transferable {
    let filename: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .totalisrList) { shared in
            shared.data
        }
        .suggestedFileName { shared in
            shared.filename
        }
    }
}

@MainActor
extension SharedList {
    init(exporting list: TotalList) throws {
        let document = ListDocument(exporting: list)
        self.init(filename: document.suggestedFilename, data: try document.encoded())
    }
}
