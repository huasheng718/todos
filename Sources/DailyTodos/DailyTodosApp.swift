import SwiftUI

@main
struct DailyTodosApp: App {
    @StateObject private var store = TodoStore()
    @StateObject private var aiSettings = AISettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(aiSettings)
                .frame(minWidth: 1100, idealWidth: 1280, minHeight: 760, idealHeight: 860)
                .task {
                    store.load()
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
        }
    }
}

extension Notification.Name {
    static let newTodoRequested = Notification.Name("newTodoRequested")
}
