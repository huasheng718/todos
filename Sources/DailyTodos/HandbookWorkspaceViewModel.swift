import Foundation

@MainActor
final class HandbookWorkspaceViewModel: ObservableObject {
    @Published private(set) var summaries: [HandbookNoteSummary] = []
    @Published private(set) var sidebarIndex: HandbookSidebarIndex = .empty
    @Published private(set) var listSnapshot: HandbookNotesListSnapshot = .empty
    @Published private(set) var selectedItemID: UUID?
    @Published private(set) var selectedItem: HandbookItem?

    private var repository: HandbookRepository = LocalHandbookRepository(items: [])
    private var scope: HandbookScope = .all
    private var rebuildTask: Task<Void, Never>?

    func refresh(
        items: [HandbookItem],
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        let repository = LocalHandbookRepository(items: items)
        refresh(
            repository: repository,
            selectedCategory: selectedCategory,
            selectedFolder: selectedFolder,
            searchText: searchText
        )
    }

    func refresh(
        repository: HandbookRepository,
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        self.repository = repository
        summaries = repository.noteSummaries()
        scope = HandbookScope(category: selectedCategory, folder: selectedFolder, searchText: searchText)
        sidebarIndex = repository.sidebarIndex(selectedCategory: selectedCategory)
        rebuildListSnapshot(immediate: listSnapshot.cacheKey == .empty)
        syncSelectedItem()
    }

    func updateScope(
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        scope = HandbookScope(category: selectedCategory, folder: selectedFolder, searchText: searchText)
        sidebarIndex = HandbookSidebarIndex(summaries: summaries, selectedCategory: selectedCategory)
        rebuildListSnapshot(immediate: true)
        syncSelectedItem()
    }

    func selectItem(id: UUID?) {
        selectedItemID = id
        syncSelectedItem(shouldClearWhenOutsideScope: false)
    }

    func item(for id: UUID) -> HandbookItem? {
        repository.noteDetail(id: id)
    }

    private func rebuildListSnapshot(immediate: Bool = false) {
        let newKey = HandbookNotesListSnapshotKey(summaries: summaries, scope: scope)
        guard newKey != listSnapshot.cacheKey else { return }

        rebuildTask?.cancel()
        let sourceSummaries = summaries
        let currentScope = scope

        if immediate {
            listSnapshot = PerformanceMonitor.measure("HandbookWorkspace.listSnapshot.sync") {
                HandbookNotesListSnapshot(summaries: sourceSummaries, scope: currentScope)
            }
            return
        }

        rebuildTask = Task {
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            let newSnapshot = await Task.detached(priority: .userInitiated) {
                PerformanceMonitor.measure("HandbookWorkspace.listSnapshot") {
                    HandbookNotesListSnapshot(summaries: sourceSummaries, scope: currentScope)
                }
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                listSnapshot = newSnapshot
            }
        }
    }

    private func syncSelectedItem(shouldClearWhenOutsideScope: Bool = true) {
        guard let selectedItemID else {
            selectedItem = nil
            return
        }

        if shouldClearWhenOutsideScope {
            guard summaries.contains(where: { $0.id == selectedItemID && scope.contains($0) }) else {
                self.selectedItemID = nil
                selectedItem = nil
                return
            }
        }

        selectedItem = repository.noteDetail(id: selectedItemID)
        if selectedItem == nil {
            self.selectedItemID = nil
        }
    }
}
