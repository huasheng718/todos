import SwiftUI

@main
struct DailyTodosApp: App {
    @StateObject private var store = TodoStore()
    @StateObject private var handbookStore = HandbookStore()
    @StateObject private var credentialStore = CredentialStore()
    @StateObject private var credentialManagementActions = CredentialManagementActions()
    @StateObject private var aiSettings = AISettingsStore()
    @StateObject private var updateController = UpdateController()
    @StateObject private var moduleRegistry = AppModuleRegistry()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(handbookStore)
                .environmentObject(credentialStore)
                .environmentObject(credentialManagementActions)
                .environmentObject(aiSettings)
                .environmentObject(updateController)
                .environmentObject(moduleRegistry)
                .frame(minWidth: 1100, idealWidth: 1280, minHeight: 760, idealHeight: 860)
                .background(WindowChromeConfigurator())
                .task {
                    store.loadStartupData()
                    handbookStore.scheduleLoadHandbookItemsIfNeeded()
                    await credentialStore.load()
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
