import Foundation

protocol HandbookRepository {
    func sidebarIndex(selectedCategory: HandbookCategory?) -> HandbookSidebarIndex
    func noteSummaries() -> [HandbookNoteSummary]
    func noteDetail(id: UUID) -> HandbookItem?
}

struct LocalHandbookRepository: HandbookRepository {
    private let items: [HandbookItem]
    private let summaries: [HandbookNoteSummary]
    private let itemsByID: [UUID: HandbookItem]

    init(items: [HandbookItem]) {
        self.items = items
        self.summaries = items.map(HandbookNoteSummary.init)
        self.itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    func sidebarIndex(selectedCategory: HandbookCategory?) -> HandbookSidebarIndex {
        HandbookSidebarIndex(summaries: summaries, selectedCategory: selectedCategory)
    }

    func noteSummaries() -> [HandbookNoteSummary] {
        summaries
    }

    func noteDetail(id: UUID) -> HandbookItem? {
        itemsByID[id]
    }
}

