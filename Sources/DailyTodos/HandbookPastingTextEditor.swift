import AppKit
import SwiftUI

struct HandbookPastingTextEditor: NSViewRepresentable {
    @Binding var text: String
    let itemID: UUID
    let editorSession: HandbookEditorSessionController
    var focusedField: FocusState<HandbookCanvasFocus?>.Binding
    let onPasteImage: (NSImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PasteInterceptingTextView()
        textView.delegate = context.coordinator
        textView.onPasteImage = { image in
            onPasteImage(image)
        }
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 7)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        context.coordinator.textView = textView
        configure(textView)
        textView.string = text
        applyEditorAttributes(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? PasteInterceptingTextView else { return }
        context.coordinator.observeWindow(textView.window)

        textView.onPasteImage = { image in
            onPasteImage(image)
        }
        configure(textView)
        if textView.string != text {
            let selectedRanges = clampedSelectionRanges(textView.selectedRanges, textLength: (text as NSString).length)
            textView.string = text
            if !selectedRanges.isEmpty {
                textView.selectedRanges = selectedRanges
            }
        }
        applyEditorAttributes(to: textView)

        if focusedField.wrappedValue == .body,
           textView.window?.firstResponder !== textView {
            textView.window?.makeFirstResponder(textView)
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.observeWindow(nil)
        (scrollView.documentView as? NSTextView)?.delegate = nil
    }

    private func configure(_ textView: NSTextView) {
        textView.font = NSFont.systemFont(ofSize: 15.5, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
    }

    private func applyEditorAttributes(to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15.5, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.typingAttributes = attributes

        let length = (textView.string as NSString).length
        guard length > 0 else { return }
        textView.textStorage?.setAttributes(attributes, range: NSRange(location: 0, length: length))
    }

    private func clampedSelectionRanges(_ ranges: [NSValue], textLength: Int) -> [NSValue] {
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

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HandbookPastingTextEditor
        weak var textView: NSTextView?
        private var lastSelectionRanges: [NSValue] = []
        private var observedWindow: NSWindow?
        private var didBecomeKeyObserver: NSObjectProtocol?

        init(parent: HandbookPastingTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            observeWindow(textView?.window)
            parent.editorSession.begin(itemID: parent.itemID, focus: .body)
            parent.focusedField.wrappedValue = .body
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                lastSelectionRanges = textView.selectedRanges
            }
            let event = parent.editorSession.focusEventForCurrentTurn()
            switch HandbookEditorFocusPolicy.decision(current: .body, event: event) {
            case let .transfer(target):
                parent.focusedField.wrappedValue = target
            case .preserve:
                restoreBodyFocus()
            case .exit:
                break
            }
        }

        func observeWindow(_ window: NSWindow?) {
            guard observedWindow !== window else { return }
            if let didBecomeKeyObserver {
                NotificationCenter.default.removeObserver(didBecomeKeyObserver)
            }
            observedWindow = window
            guard let window else {
                didBecomeKeyObserver = nil
                return
            }
            didBecomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.restoreBodyFocus()
                }
            }
        }

        private func restoreBodyFocus() {
            let itemID = parent.itemID
            Task { @MainActor [weak self, weak textView] in
                await Task.yield()
                guard let self,
                      self.parent.editorSession.shouldRestore(itemID: itemID, focus: .body),
                      let textView,
                      let window = textView.window
                else { return }
                self.parent.focusedField.wrappedValue = .body
                window.makeFirstResponder(textView)
                let ranges = self.parent.clampedSelectionRanges(
                    self.lastSelectionRanges,
                    textLength: (textView.string as NSString).length
                )
                if !ranges.isEmpty {
                    textView.selectedRanges = ranges
                }
            }
        }

    }
}

private final class PasteInterceptingTextView: NSTextView {
    var onPasteImage: ((NSImage) -> Void)?

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)),
           HandbookPasteboardImageReader.image(from: NSPasteboard.general) != nil {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func paste(_ sender: Any?) {
        if let image = HandbookPasteboardImageReader.image(from: NSPasteboard.general) {
            onPasteImage?(image)
            return
        }
        super.paste(sender)
    }
}
