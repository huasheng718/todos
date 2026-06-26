import SwiftUI

struct InlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var isEmphasized = false

    init(_ placeholder: String, text: Binding<String>, isEmphasized: Bool = false) {
        self.placeholder = placeholder
        _text = text
        self.isEmphasized = isEmphasized
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: isEmphasized ? .semibold : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )
            .accessibilityLabel(placeholder)
    }
}

struct CompactNotesField: View {
    @Binding var text: String
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 16)
                .accessibilityHidden(true)

            TextField("备注（可选，添加背景、链接、判断依据）…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .submitLabel(.done)
                .onSubmit {
                    onSubmit?()
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 30)
        .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("备注")
    }
}
