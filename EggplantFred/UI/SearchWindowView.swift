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
            Task { @MainActor in queryFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidShow)) { _ in
            Task { @MainActor in queryFocused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            TextField("", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .regular))
                .focused($queryFocused)
                .onSubmit { viewModel.openSelected() }
                // Steal ↑/↓ from the field editor so they only move list selection.
                .onKeyPress(.upArrow) {
                    viewModel.moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    viewModel.moveSelection(by: 1)
                    return .handled
                }

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
                .fill(Color.primary.opacity(0.12))
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

    /// Frosted chrome: vibrancy lets the wallpaper peek through a little;
    /// a light tint keeps text readable.
    private var panelChrome: some View {
        ZStack {
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                cornerRadius: Self.outerCornerRadius
            )
            RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.62))
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.outerCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        applyMask(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        applyMask(to: nsView)
    }

    private func applyMask(to view: NSVisualEffectView) {
        guard let layer = view.layer else { return }
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.backgroundColor = NSColor.clear.cgColor
    }
}
