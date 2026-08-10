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
    static let maxVisibleResults = 9
    static let rowHeight: CGFloat = 56
    static let rowSpacing: CGFloat = 2
    /// Clear inset so the rounded soft shadow isn't clipped into square
    /// corners (system `NSPanel` shadow is rectangular and leaves light ears
    /// on pale wallpapers). Keep this tight for cleaner window screenshots.
    static let shadowBleed: CGFloat = 20
    static let shadowRadius: CGFloat = 14
    static let shadowYOffset: CGFloat = 6

    static var panelWidth: CGFloat { chromeWidth + shadowBleed * 2 }
    static var compactHeight: CGFloat { contentHeight(resultCount: 0) }

    static func resultsListHeight(count: Int) -> CGFloat {
        let n = min(max(count, 0), maxVisibleResults)
        guard n > 0 else { return 0 }
        return CGFloat(n) * rowHeight + CGFloat(n - 1) * rowSpacing
    }

    /// Search-field block only (padding + field + padding). Stays fixed while typing.
    static var fieldChromeHeight: CGFloat { outerPadding * 2 + innerFieldHeight }

    /// Compact = field only; expanded = field + exactly N≤9 rows.
    static func chromeHeight(resultCount: Int) -> CGFloat {
        if resultCount <= 0 {
            return fieldChromeHeight
        }
        return fieldChromeHeight
            + resultsListHeight(count: resultCount)
            + outerPadding
    }

    static func contentHeight(resultCount: Int) -> CGFloat {
        chromeHeight(resultCount: resultCount) + shadowBleed * 2
    }

    var showsResults: Bool { !viewModel.results.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, Self.outerPadding)
                .padding(.top, Self.outerPadding)
                .padding(.bottom, Self.outerPadding)
                .frame(height: Self.fieldChromeHeight, alignment: .top)

            if showsResults {
                resultsList
                    .padding(.horizontal, Self.outerPadding)
                    .padding(.bottom, Self.outerPadding)
            }
        }
        .frame(width: Self.chromeWidth, alignment: .top)
        .frame(height: Self.chromeHeight(resultCount: viewModel.results.count), alignment: .top)
        .background(panelChrome)
        .padding(Self.shadowBleed)
        .frame(width: Self.panelWidth, alignment: .top)
        .frame(height: Self.contentHeight(resultCount: viewModel.results.count), alignment: .top)
        // No SwiftUI height animation — it fights NSPanel.setFrame and makes
        // the query field jitter while typing.
        .onAppear {
            focusQueryField()
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidShow)) { _ in
            focusQueryField()
        }
    }

    /// Bounce focus off→on so a stale `true` from the previous show still works.
    private func focusQueryField() {
        queryFocused = false
        Task { @MainActor in
            queryFocused = true
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

            StatusMenuHatIcon()
        }
        .padding(.horizontal, 14)
        .frame(height: Self.innerFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: Self.innerCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.12))
        )
    }

    private var resultsList: some View {
        // N≤9 rows, no ScrollView — height tracks count; query field stays pinned.
        VStack(spacing: Self.rowSpacing) {
            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, app in
                ResultRowView(
                    app: app,
                    isSelected: index == viewModel.selectedIndex,
                    shortcutHint: viewModel.shortcutHint(for: index)
                )
                .frame(height: Self.rowHeight)
                // Continuous hover so a slight move while already over a row
                // can unlock Alfred-style selection (plain onHover won't re-fire).
                .onContinuousHover { phase in
                    if case .active = phase {
                        viewModel.highlightIndex(index)
                    }
                }
                .onTapGesture {
                    viewModel.selectIndex(index)
                }
            }
        }
        .frame(height: Self.resultsListHeight(count: viewModel.results.count), alignment: .top)
    }

    /// Frosted chrome + soft rounded shadow (not the rectangular NSPanel shadow).
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
        .shadow(
            color: .black.opacity(0.22),
            radius: Self.shadowRadius,
            y: Self.shadowYOffset
        )
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
