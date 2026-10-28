import Foundation
import Combine

@MainActor
final class ChatDetailViewModel {
    @Published private(set) var conversation: Conversation?
    private let store: ChatStore
    private var selectedID: String?
    private var cancellables = Set<AnyCancellable>()

    var draft: String { selectedID.map { store.draft(for: $0) } ?? "" }
    var scrollPosition: MessageScrollPosition? {
        selectedID.flatMap { store.scrollPosition(for: $0) }
    }

    init(store: ChatStore) {
        self.store = store
        store.$conversations.sink { [weak self] conversations in
            guard let self, let id = self.selectedID else { return }
            // @Published 在 willSet 阶段发出事件，因此从事件值读取，不回读 store。
            self.conversation = conversations.first { $0.id == id }
        }.store(in: &cancellables)
    }

    func open(id: String) {
        guard let value = store.conversation(id: id) else { return }
        selectedID = id
        conversation = value
    }

    func updateDraft(_ text: String) {
        guard let id = selectedID else { return }
        store.saveDraft(text, for: id)
    }

    @discardableResult
    func sendDraft() -> Bool {
        guard let id = selectedID else { return false }
        return store.send(draft, to: id)
    }

    func saveScrollPosition(_ position: MessageScrollPosition) {
        guard let id = selectedID else { return }
        store.saveScrollPosition(position, for: id)
    }
}
