import AppKit
import SwiftUI

struct ResultRowView: View {
    let app: AppEntry
    let isSelected: Bool
    let shortcutHint: String

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon(size: 40))
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name.hasSuffix(".app") ? app.name : "\(app.name).app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)

                Text(app.displayPath)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(shortcutHint)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(red: 0.35, green: 0.18, blue: 0.55) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.08), value: isSelected)
    }
}
