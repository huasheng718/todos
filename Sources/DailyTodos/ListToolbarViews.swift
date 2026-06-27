import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder = "搜索标题或备注"
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(text.isEmpty ? AppTheme.mutedInk : AppTheme.accent)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.ink)
            if !text.isEmpty {
                Button {
                    withAnimation(AppMotion.quick) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveWhite(isHovered ? 0.96 : 0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(text.isEmpty ? AppTheme.hairline.opacity(0.75) : AppTheme.accent.opacity(0.22))
        )
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.quick, value: text.isEmpty)
    }
}

struct AllTodosViewModePicker: View {
    @Binding var selection: AllTodosViewMode
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AllTodosViewMode.allCases) { mode in
                Button {
                    withAnimation(AppMotion.modeSwitch) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(mode.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selection == mode ? .white : AppTheme.mutedInk)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .background(modeBackground(for: mode))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == mode ? AppTheme.adaptiveWhite(0.24) : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.tactilePlain)
                .help("\(mode.label)视图")
            }
        }
        .padding(3)
        .frame(width: 318)
        .background(AppTheme.adaptiveWhite(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.82))
        )
        .animation(AppMotion.modeSwitch, value: selection)
    }

    @ViewBuilder
    private func modeBackground(for mode: AllTodosViewMode) -> some View {
        if selection == mode {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.accent)
                .matchedGeometryEffect(id: "allTodosModeSelection", in: selectionNamespace)
        }
    }
}
