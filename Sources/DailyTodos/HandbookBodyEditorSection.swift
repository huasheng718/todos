import AppKit
import SwiftUI

/// 正文编辑器与工具栏之间的桥接器。
///
/// 工具栏（父层固定顶栏）与正文编辑器（滚动区内的隔离子视图）位于不同布局区域，
/// 无法直接共享 `@State`。桥接器持有正文编辑器暴露出来的 `Binding`，
/// 让工具栏在“不订阅正文变化”的前提下仍能读写正文——从而工具栏不会随每次击键重建。
///
/// 之所以用 class 存放：父面板以 `@State` 持有它时，SwiftUI 只跟踪其“身份”，
/// 修改内部属性不会触发父层失效，这正是隔离击键路径所需要的。
@MainActor
final class HandbookEditorBridge {
    /// 由正文编辑器子视图在 `onAppear` 时注册，指向其内部 `@State` 正文。
    var textBinding: Binding<String>?

    var currentText: String {
        textBinding?.wrappedValue ?? ""
    }

    /// 以“读取当前值 → 变换 → 写回”的方式安全地修改正文。
    func mutate(_ transform: (inout String) -> Void) {
        guard let textBinding else { return }
        var value = textBinding.wrappedValue
        transform(&value)
        textBinding.wrappedValue = value
    }
}

/// 存放正文编辑器相关状态与防抖任务的容器。
///
/// 若把这些 `Task` 直接放在详情面板的 `@State` 上，则每次击键“取消旧任务 + 建新任务”
/// 的重新赋值都会触发父面板 `body` 重算——即便正文本身已下沉隔离，父层仍会逐字重建。
/// `isDirty` 同理：它只在回调逻辑中使用，不驱动 UI，若作为 `@State` 每击键重新赋值
/// 会同样触发整棵详情面板重算。
/// 用 class 承载后，父面板以 `@State` 持有它（只跟踪身份），改内部属性不会触发失效。
@MainActor
final class HandbookEditorState {
    var isDirty = false
    var bodyMetrics: Task<Void, Never>?
    var autoSave: Task<Void, Never>?
}

/// 隔离后的手记正文编辑器。
///
/// 自持 `@State text`，因此每次击键只会重建“本视图”这一片叶子，
/// 而父面板的标题输入框、`HandbookDetailMetaBar`（含 `ViewThatFits` 双布局测量）、
/// 大纲、工具栏都不会被卷入重算。正文变更通过 `onChange` 回调上报给父面板，
/// 用于（防抖的）字数统计、大纲、脏标记与自动保存。
///
/// 编辑器高度在“含图片附件且正文很短”时会收缩以露出图片预览，逻辑从
/// `HandbookEditableCanvas` 平移至此，避免父层为计算该高度而读取逐字变化的正文。
struct HandbookBodyEditorSection: View {
    let editorHeight: CGFloat
    let hasImageAttachments: Bool
    var focusedField: FocusState<HandbookCanvasFocus?>.Binding
    let bridge: HandbookEditorBridge
    let onPasteImage: (NSImage) -> Void
    let onChange: (String) -> Void

    @State private var text: String

    init(
        seed: String,
        editorHeight: CGFloat,
        hasImageAttachments: Bool,
        focusedField: FocusState<HandbookCanvasFocus?>.Binding,
        bridge: HandbookEditorBridge,
        onPasteImage: @escaping (NSImage) -> Void,
        onChange: @escaping (String) -> Void
    ) {
        self.editorHeight = editorHeight
        self.hasImageAttachments = hasImageAttachments
        self.focusedField = focusedField
        self.bridge = bridge
        self.onPasteImage = onPasteImage
        self.onChange = onChange
        _text = State(initialValue: seed)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HandbookPastingTextEditor(
                text: $text,
                focusedField: focusedField,
                onPasteImage: onPasteImage
            )
            .frame(height: resolvedEditorHeight)

            if shouldShowBodyPlaceholder {
                Text("从这里开始写手记")
                    .font(.system(size: 15.5, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            bridge.textBinding = $text
        }
        .onChange(of: text) { _, newValue in
            onChange(newValue)
        }
    }

    private var shouldShowBodyPlaceholder: Bool {
        HandbookEditorPlaceholderPolicy.shouldShowBodyPlaceholder(
            isBodyEmpty: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isBodyFocused: focusedField.wrappedValue == .body
        )
    }

    private var resolvedEditorHeight: CGFloat {
        guard hasImageAttachments else { return editorHeight }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 112 }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 62) / 63)
            }
        return min(editorHeight, max(112, CGFloat(estimatedLines) * 25 + 34))
    }
}
