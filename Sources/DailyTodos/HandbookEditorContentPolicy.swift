import Foundation

enum HandbookEditorContentDecision: Equatable {
    case preserveEditor
    case synchronizeExternalText
}

enum HandbookEditorContentPolicy {
    static func decision(
        representedItemID: UUID,
        incomingItemID: UUID,
        isSessionOwner: Bool,
        isFirstResponder: Bool,
        hasMarkedText: Bool
    ) -> HandbookEditorContentDecision {
        guard representedItemID == incomingItemID else {
            return .synchronizeExternalText
        }
        if isSessionOwner || isFirstResponder || hasMarkedText {
            return .preserveEditor
        }
        return .synchronizeExternalText
    }
}
