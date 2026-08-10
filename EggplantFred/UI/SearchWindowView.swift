import AppKit
import SwiftUI

struct SearchWindowView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var queryFocused: Bool

    /// Compact bar height when there are no matches; expands when results appear.
    static let compactHeight: CGFloat = 64
    static let expandedHeight: CGFloat = 480
    static let panelWidth: CGFloat = 720

    var showsResults: Bool { !viewModel.results.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if showsResults {
                Divider().opacity(0.25)
                resultsList
            }
        }
        .frame(width: Self.panelWidth)
        .frame(height: showsResults ? Self.expandedHeight : Self.compactHeight, alignment: .top)
        .background(WindowBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .animation(.easeOut(duration: 0.14), value: showsResults)
        .onAppear {
            queryFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidShow)) { _ in
            queryFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            TextField("", text: $viewModel.query, prompt: Text("Search apps"))
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .regular))
                .focused($queryFocused)
                .onSubmit { viewModel.openSelected() }

            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(height: Self.compactHeight)
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
                .padding(8)
            }
            .onChange(of: viewModel.selectedIndex) { _, newValue in
                guard viewModel.results.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(viewModel.results[newValue].id, anchor: .center)
                }
            }
        }
    }
}

private struct WindowBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            Color(nsColor: .windowBackgroundColor).opacity(0.55)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
