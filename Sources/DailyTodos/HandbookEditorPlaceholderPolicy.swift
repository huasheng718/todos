enum HandbookEditorPlaceholderPolicy {
    static func shouldShowBodyPlaceholder(isBodyEmpty: Bool, isBodyFocused: Bool) -> Bool {
        isBodyEmpty && !isBodyFocused
    }
}
