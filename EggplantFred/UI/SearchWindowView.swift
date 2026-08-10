import AppKit
import SwiftUI

struct SearchWindowView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var queryFocused: Bool

    /// Alfred-style chrome: outer padding around an inset search field.
    static let outerPadding: CGFloat = 12
    static let innerFieldHeight: CGFloat = 52
    static let chromeWidth: CGFloat = 720
    static let outerCornerRadius: CGFloat = 16
    static let innerCornerRadius: CGFloat = 10
    /// Extra clear space so the soft shadow isn't clipped into a rectangle
    /// (clipped shadows read as black corners on light wallpapers).
    static let shadowBleed: CGFloat = 36

    static var contentCompactHeight: CGFloat { outerPadding * 2 + innerFieldHeight }
    static var contentExpandedHeight: CGFloat { 480 }
    static var panelWidth: CGFloat { chromeWidth + shadowBleed * 2 }
    static var compactHeight: CGFloat { contentCompactHeight + shadowBleed * 2 }
    static var expandedHeight: CGFloat { contentExpandedHeight + shadowBleed * 2 }

    var showsResults: Bool { !viewModel.results.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(Self.outerPadding)

            if showsResults {
                resultsList
                    .padding(.horizontal, Self.outerPadding)
                    .padding(.bottom, Self.outerPadding)
            }
        }
        .frame(width: Self.chromeWidth)
        .frame(
            height: showsResults ? Self.contentExpandedHeight : Self.contentCompactHeight,
            alignment: .top
        )
        .background(panelChrome)
        .padding(Self.shadowBleed)
        .frame(width: Self.panelWidth)
        .frame(height: showsResults ? Self.expandedHeight : Self.compactHeight, alignment: .top)
        .animation(.easeOut(duration: 0.14), value: showsResults)
        .onAppear {
            queryFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidShow)) { _ in
            queryFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            TextField("", text: $viewModel.query, prompt: Text("Search apps"))
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .regular))
                .focused($queryFocused)
                .onSubmit { viewModel.openSelected() }

            Image(systemName: "hat.widebrim.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.monochrome)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(height: Self.innerFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: Self.innerCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, app in
                        ResultRowView(
                            app: app,
                            isSelected: index == viewModel.selectedIndex,
                            shortcutHint: viewModel.shortcutHint(for: index)
                        )
                        .id(app.id)
                        .onTapGesture {
                            viewModel.selectIndex(index)
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, newValue in
                guard viewModel.results.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(viewModel.results[newValue].id, anchor: .center)
                }
            }
        }
    }

    private var panelChrome: some View {
        RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}
