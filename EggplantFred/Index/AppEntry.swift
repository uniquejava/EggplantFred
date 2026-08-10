import AppKit
import Foundation

struct AppEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let url: URL

    var displayPath: String { path }

    func icon(size: CGFloat = 36) -> NSImage {
        IconCache.shared.icon(for: path, size: size)
    }
}

final class IconCache: @unchecked Sendable {
    static let shared = IconCache()

    private let lock = NSLock()
    private var cache: [String: NSImage] = [:]

    func icon(for path: String, size: CGFloat) -> NSImage {
        let key = "\(path)|\(Int(size))"
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let original = NSWorkspace.shared.icon(forFile: path)
        let sized = original.copy() as? NSImage ?? original
        sized.size = NSSize(width: size, height: size)

        lock.lock()
        cache[key] = sized
        lock.unlock()
        return sized
    }
}
