import AppKit
import SwiftUI

enum HandbookEditorRegionRole: Hashable {
    case title
    case body
    case control
}

extension Notification.Name {
    static let handbookEditorDidRequestExit = Notification.Name("HandbookEditorDidRequestExit")
}

@MainActor
final class HandbookEditorSessionController {
    private struct Region {
        let role: HandbookEditorRegionRole
        let frame: NSRect
    }

    private(set) var itemID: UUID?
    private(set) var preferredFocus: HandbookCanvasFocus?
    private(set) var isExitPending = false

    private weak var window: NSWindow?
    private var regions: [UUID: Region] = [:]
    private var monitor: Any?
    private var currentFocusEvent: HandbookEditorFocusEvent = .system
    private var eventGeneration = 0

    func begin(itemID: UUID, focus: HandbookCanvasFocus) {
        self.itemID = itemID
        preferredFocus = focus
        isExitPending = false
        installMonitorIfNeeded()
    }

    func finish(itemID: UUID) {
        guard self.itemID == itemID else { return }
        self.itemID = nil
        preferredFocus = nil
        isExitPending = false
        currentFocusEvent = .system
        removeMonitor()
    }

    func cancel() {
        itemID = nil
        preferredFocus = nil
        isExitPending = false
        currentFocusEvent = .system
        regions.removeAll()
        window = nil
        removeMonitor()
    }

    func focusEventForCurrentTurn() -> HandbookEditorFocusEvent {
        currentFocusEvent
    }

    func shouldRestore(itemID: UUID, focus: HandbookCanvasFocus) -> Bool {
        self.itemID == itemID
            && preferredFocus == focus
            && !isExitPending
            && (window?.isKeyWindow ?? false)
    }

    fileprivate func register(
        id: UUID,
        role: HandbookEditorRegionRole,
        frame: NSRect,
        window newWindow: NSWindow
    ) {
        if window !== newWindow {
            removeMonitor()
            regions.removeAll()
            window = newWindow
        }
        regions[id] = Region(role: role, frame: frame)
        installMonitorIfNeeded()
    }

    fileprivate func unregister(id: UUID) {
        regions[id] = nil
    }

    private var hasValidGeometry: Bool {
        let roles = Set(regions.values.map(\.role))
        return roles.contains(.title) && roles.contains(.body) && roles.contains(.control)
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil, itemID != nil, window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseDown(event)
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let itemID else { return }
        let focusEvent = classify(event)
        rememberForCurrentTurn(focusEvent)
        guard focusEvent == .outside, !isExitPending else { return }

        isExitPending = true
        NotificationCenter.default.post(
            name: .handbookEditorDidRequestExit,
            object: self,
            userInfo: ["itemID": itemID]
        )
    }

    private func classify(_ event: NSEvent) -> HandbookEditorFocusEvent {
        guard let window, hasValidGeometry else { return .system }
        guard event.window === window else { return .outside }

        let location = event.locationInWindow
        let matchingRoles = regions.values.compactMap { region in
            region.frame.contains(location) ? region.role : nil
        }
        if matchingRoles.contains(.title) { return .input(.title) }
        if matchingRoles.contains(.body) { return .input(.body) }
        if matchingRoles.contains(.control) { return .editorControl }
        return .outside
    }

    private func rememberForCurrentTurn(_ event: HandbookEditorFocusEvent) {
        eventGeneration += 1
        let generation = eventGeneration
        currentFocusEvent = event
        DispatchQueue.main.async { [weak self] in
            guard let self, self.eventGeneration == generation, !self.isExitPending else { return }
            self.currentFocusEvent = .system
        }
    }

}

private struct HandbookEditorRegionModifier: ViewModifier {
    let role: HandbookEditorRegionRole
    let session: HandbookEditorSessionController
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content.background {
            HandbookEditorRegionReader(id: id, role: role, session: session)
        }
    }
}

private struct HandbookEditorRegionReader: NSViewRepresentable {
    let id: UUID
    let role: HandbookEditorRegionRole
    let session: HandbookEditorSessionController

    func makeNSView(context: Context) -> HandbookEditorRegionTrackingView {
        HandbookEditorRegionTrackingView(id: id, role: role, session: session)
    }

    func updateNSView(_ view: HandbookEditorRegionTrackingView, context: Context) {
        view.configure(id: id, role: role, session: session)
        view.publishFrame()
    }

    static func dismantleNSView(_ view: HandbookEditorRegionTrackingView, coordinator: Void) {
        view.unregister()
    }
}

@MainActor
private final class HandbookEditorRegionTrackingView: NSView {
    private var id: UUID
    private var role: HandbookEditorRegionRole
    private var session: HandbookEditorSessionController

    init(id: UUID, role: HandbookEditorRegionRole, session: HandbookEditorSessionController) {
        self.id = id
        self.role = role
        self.session = session
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(id: UUID, role: HandbookEditorRegionRole, session: HandbookEditorSessionController) {
        if self.id != id || self.session !== session {
            self.session.unregister(id: self.id)
        }
        self.id = id
        self.role = role
        self.session = session
    }

    override func layout() {
        super.layout()
        publishFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publishFrame()
    }

    func publishFrame() {
        guard let window else { return }
        session.register(id: id, role: role, frame: convert(bounds, to: nil), window: window)
    }

    func unregister() {
        session.unregister(id: id)
    }
}

extension View {
    func handbookEditorRegion(
        _ role: HandbookEditorRegionRole,
        session: HandbookEditorSessionController
    ) -> some View {
        modifier(HandbookEditorRegionModifier(role: role, session: session))
    }
}
