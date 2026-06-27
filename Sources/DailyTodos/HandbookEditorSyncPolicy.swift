enum HandbookEditorSyncPolicy {
    static func preservesLocalTextEditsForSameItemUpdate(isDirty: Bool, isEditorFocused: Bool) -> Bool {
        isDirty || isEditorFocused
    }
}
