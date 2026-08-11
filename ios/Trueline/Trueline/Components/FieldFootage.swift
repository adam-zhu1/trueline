import Foundation

/// Field-test insurance: while enabled, every raw camera recording survives in
/// Documents/FieldFootage instead of dying on the normal cleanup paths — the
/// footage doubles as training data for the ball model, and the throws the
/// tracker fails on are exactly the ones worth keeping.
///
/// Toggle with the `-fieldFootageMode <1|0>` launch arg. Like `-bankFreeThrows`
/// it persists, so home-screen launches at the alley stay in the mode a paired
/// Mac set; App Store launches can't pass arguments, so shipping installs never
/// enter it on their own. The rescue paths only ever see camera recordings;
/// imported clips keep their originals in Photos.
enum FieldFootage {
    private static let key = "fieldFootageMode"

    /// Call once at launch. The argument domain shadows the persistent one, so
    /// reading the effective value and writing it back persists whatever a
    /// paired-Mac launch passed; with no argument it rewrites the stored value.
    static func syncFromLaunchArguments() {
        if UserDefaults.standard.object(forKey: key) != nil {
            UserDefaults.standard.set(UserDefaults.standard.bool(forKey: key), forKey: key)
        }
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    /// Documents, not Application Support: with file sharing enabled, Documents
    /// is the one directory Finder and the Files app can see, and nothing else
    /// in the app writes there — the launch orphan sweep and Settings' delete
    /// actions only ever touch Application Support/ShotVideos.
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("FieldFootage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Keep a clip that stays in the normal save pipeline (which will move,
    /// trim, and re-encode it): copy, original left in place.
    static func keepCopy(of url: URL) {
        guard isEnabled else { return }
        try? FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent))
    }

    /// Claim a clip the flow is about to delete: move. Returns false when the
    /// mode is off or the move failed — the caller should delete as usual.
    static func rescue(_ url: URL) -> Bool {
        guard isEnabled else { return false }
        do {
            try FileManager.default.moveItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent))
            return true
        } catch {
            return false
        }
    }
}
