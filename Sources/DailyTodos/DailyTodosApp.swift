import SwiftUI

@main
struct DailyTodosApp: App {
    @StateObject private var store = TodoStore()
    @StateObject private var aiSettings = AISettingsStore()
    @StateObject private var updateController = UpdateController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(aiSettings)
                .environmentObject(updateController)
                .frame(minWidth: 1100, idealWidth: 1280, minHeight: 760, idealHeight: 860)
                .background(WindowChromeConfigurator())
                .task {
                    store.loadStartupData()
                    updateController.startMonitoring()
                    try? await Task.sleep(for: .milliseconds(900))
                    updateController.checkForUpdatesIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    updateController.checkForUpdatesIfNeeded()
                    updateController.remindAboutAvailableUpdateIfNeeded()
                }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建待办") {
                    NotificationCenter.default.post(name: .newTodoRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    updateController.checkForUpdates()
                }
            }
        }
    }
}

extension Notification.Name {
    static let newTodoRequested = Notification.Name("newTodoRequested")
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
    }
}
