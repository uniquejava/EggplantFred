import AppKit
import Combine
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [AppEntry] = []
    @Published var selectedIndex = 0

    private let appIndex: AppIndex
    private let onDismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(appIndex: AppIndex, onDismiss: @escaping () -> Void) {
        self.appIndex = appIndex
        self.onDismiss = onDismiss

        appIndex.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)

        $query
            .debounce(for: .milliseconds(40), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .launcherDidShow)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resetForShow()
            }
            .store(in: &cancellables)

        recompute()
    }

    func resetForShow() {
        query = ""
        selectedIndex = 0
        recompute()
    }

    func recompute() {
        let newResults = SearchEngine.search(query: query, in: appIndex.apps, limit: 9)
        let newIndex = min(selectedIndex, max(0, newResults.count - 1))
        // Defer publishes so we never mutate during an in-flight SwiftUI update
        // (avoids "Publishing changes from within view updates").
        Task { @MainActor in
            self.results = newResults
            self.selectedIndex = newIndex
        }
    }

    func moveSelection(by delta: Int) {
        Task { @MainActor in
            guard !self.results.isEmpty else { return }
            let count = self.results.count
            let next = (self.selectedIndex + delta) % count
            self.selectedIndex = next >= 0 ? next : next + count
        }
    }

    func selectIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
        openSelected()
    }

    func openSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        let app = results[selectedIndex]
        AppLauncher.open(app)
        onDismiss()
    }

    func shortcutHint(for index: Int) -> String {
        if index == selectedIndex {
            return "⏎"
        }
        if (0...8).contains(index) {
            return "⌘\(index + 1)"
        }
        return ""
    }
}
