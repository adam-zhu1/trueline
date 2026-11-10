import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Saved shots as CSV, for spreadsheets and coaches. Plain numbers with a dot
/// decimal whatever the phone's region, empty cells for metrics a throw
/// didn't produce, and local times written the way spreadsheets parse them.
enum ShotCSV {
    static let header = [
        "date", "session", "speed_mph", "board_at_arrows", "breakpoint_board",
        "breakpoint_ft", "entry_board", "entry_angle_deg", "analyzer_version",
    ]

    static func make(shots: [SavedShot], timeZone: TimeZone = .current) -> String {
        let dateFormat = formatter(timeZone: timeZone)
        let rows = shots.sorted { $0.date < $1.date }.map { shot in
            [
                dateFormat.string(from: shot.date),
                shot.session.map { dateFormat.string(from: $0.date) } ?? "",
                number(shot.speedMph),
                number(shot.arrowBoard),
                number(shot.breakpointBoard),
                number(shot.breakpointFeet),
                number(shot.entryBoard),
                number(shot.entryAngleDegrees),
                String(shot.analyzerVersion),
            ]
        }
        // RFC 4180 line endings, so Excel and Numbers agree on rows.
        return ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field only when it has to: commas, quotes, or line breaks.
    /// Inner quotes double. A leading = + - @ is prefixed with an apostrophe
    /// so a spreadsheet never runs a cell as a formula (today every field
    /// is a number or a date, but session names may join later).
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+@".contains(first) || (first == "-" && Double(value) == nil) {
            value = "'" + value
        }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}

/// A ready-made CSV for ShareLink. The text is built up front (models stay on
/// the main actor); the file is written only when the user picks a target.
struct ShotCSVFile: Transferable {
    let text: String
    let fileName: String

    init(shots: [SavedShot], name: String) {
        text = ShotCSV.make(shots: shots)
        fileName = name
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.fileName }
    }
}
