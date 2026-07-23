enum HandbookEditorSyncPolicy {
    static func preservesLocalTextEditsForSameItemUpdate(isDirty: Bool, ownsActiveEditor: Bool) -> Bool {
        isDirty || ownsActiveEditor
    }
}
