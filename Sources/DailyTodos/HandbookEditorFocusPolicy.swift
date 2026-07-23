enum HandbookCanvasFocus: Hashable {
    case title
    case body
}

enum HandbookEditorFocusEvent: Equatable {
    case input(HandbookCanvasFocus)
    case editorControl
    case outside
    case system
}

enum HandbookEditorFocusDecision: Equatable {
    case transfer(HandbookCanvasFocus)
    case preserve(HandbookCanvasFocus)
    case exit
}

enum HandbookEditorFocusPolicy {
    static func decision(
        current: HandbookCanvasFocus,
        event: HandbookEditorFocusEvent
    ) -> HandbookEditorFocusDecision {
        switch event {
        case let .input(target):
            return .transfer(target)
        case .editorControl, .system:
            return .preserve(current)
        case .outside:
            return .exit
        }
    }
}
