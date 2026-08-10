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
        results = SearchEngine.search(query: query, in: appIndex.apps, limit: 9)
        if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let next = selectedIndex + delta
        selectedIndex = max(0, min(results.count - 1, next))
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
