import AppKit
import Foundation

@MainActor
final class AppIndex: ObservableObject {
    @Published private(set) var apps: [AppEntry] = []
    @Published private(set) var isLoading = false

    private let queue = DispatchQueue(label: "com.eggplantfred.appindex", qos: .userInitiated)

    func refresh() {
        isLoading = true
        queue.async { [weak self] in
            let scanned = ApplicationScanner.scan()
            Task { @MainActor in
                guard let self else { return }
                self.apps = scanned
                self.isLoading = false
            }
        }
    }
}

enum ApplicationScanner {
    static func scan() -> [AppEntry] {
        let fileManager = FileManager.default
        var roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        if let local = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first {
            roots.append(local)
        }

        var seen = Set<String>()
        var results: [AppEntry] = []

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension == "app" else { continue }
                let path = item.path
                guard seen.insert(path).inserted else { continue }

                results.append(
                    AppEntry(
                        id: path,
                        name: displayName(for: item),
                        path: path,
                        url: item
                    )
                )
            }
        }

        return results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func displayName(for url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !display.isEmpty {
                return display
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !name.isEmpty {
                return name
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
