import CoreTransferable
import Foundation

/// A video picked from the Photos library, copied into the app's temp directory
/// so the capture flow can treat it exactly like a fresh recording.
struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFile(url: copy)
        }
    }
}

/// Identifiable wrapper so an imported clip can drive a fullScreenCover.
struct ImportedClip: Identifiable {
    let id = UUID()
    let url: URL
}
