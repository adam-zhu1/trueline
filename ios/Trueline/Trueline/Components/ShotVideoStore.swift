import AVFoundation
import Foundation

/// Where saved shots' replay videos live: Application Support/ShotVideos.
/// SwiftData rows hold only the file name — delete flows must remove the file
/// too, and the orphan sweep at launch catches anything that slipped through
/// (a crash between file move and model save, a failed delete).
enum ShotVideoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ShotVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Moves a finished clip into the store; returns the stored file name,
    /// or nil if the move failed (the shot then simply has no replay).
    static func store(clipURL: URL) -> String? {
        let ext = clipURL.pathExtension.isEmpty ? "mov" : clipURL.pathExtension
        let name = "shot-\(UUID().uuidString).\(ext)"
        do {
            try FileManager.default.moveItem(at: clipURL, to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    static func url(forName name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Re-encode a stored raw clip down to just the throw (±1 s padding) at
    /// 720p — the raw recording is mostly the walk back to the phone, so this
    /// is a 10–20× size cut. Returns the compact file's name and deletes the
    /// raw on success; nil means the export failed and the raw stays.
    static func compress(rawName: String, throwStart: Double?, throwEnd: Double?) async -> String? {
        let rawURL = url(forName: rawName)
        let asset = AVURLAsset(url: rawURL)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return nil
        }
        let outName = "shot-\(UUID().uuidString).mp4"
        let outURL = url(forName: outName)
        export.outputURL = outURL
        export.outputFileType = .mp4
        if let throwStart, let throwEnd,
           let duration = try? await asset.load(.duration) {
            let pad = 1.0
            let start = max(0, throwStart - pad)
            let end = min(duration.seconds, throwEnd + pad)
            if end > start {
                export.timeRange = CMTimeRange(
                    start: CMTime(seconds: start, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600)
                )
            }
        }
        await export.export()
        guard export.status == .completed else {
            try? FileManager.default.removeItem(at: outURL)
            return nil
        }
        try? FileManager.default.removeItem(at: rawURL)
        return outName
    }

    static func delete(name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: url(forName: name))
    }

    static func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(0) { sum, file in
            sum + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    static func deleteAll() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Removes files no saved shot references.
    static func sweepOrphans(keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
