import AppKit

@MainActor
enum HandbookNativeTextViewReconciler {
    static func initialize(_ textView: NSTextView, text: String) {
        let attributes = editorAttributes()
        textView.font = attributes[.font] as? NSFont
        textView.textColor = attributes[.foregroundColor] as? NSColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.typingAttributes = attributes
        textView.string = text
        applyDocumentAttributes(attributes, to: textView)
    }

    static func reconcile(
        _ textView: NSTextView,
        externalText: String,
        decision: HandbookEditorContentDecision
    ) {
        guard decision == .synchronizeExternalText,
              textView.string != externalText
        else { return }

        let textLength = (externalText as NSString).length
        let selections = clampedSelectionRanges(textView.selectedRanges, textLength: textLength)
        let attributes = editorAttributes()

        textView.string = externalText
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.typingAttributes = attributes
        applyDocumentAttributes(attributes, to: textView)
        if !selections.isEmpty {
            textView.selectedRanges = selections
        }
    }

    private static func editorAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        return [
            .font: NSFont.systemFont(ofSize: 15.5, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private static func applyDocumentAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to textView: NSTextView
    ) {
        let length = (textView.string as NSString).length
        guard length > 0 else { return }
        textView.textStorage?.setAttributes(
            attributes,
            range: NSRange(location: 0, length: length)
        )
    }

    private static func clampedSelectionRanges(
        _ ranges: [NSValue],
        textLength: Int
    ) -> [NSValue] {
        ranges.compactMap { value in
            let range = value.rangeValue
            guard range.location <= textLength else { return nil }
            return NSValue(
                range: NSRange(
                    location: range.location,
                    length: min(range.length, textLength - range.location)
                )
            )
        }
    }
}
