import Foundation
import Combine

@MainActor
final class ChatListViewModel {
    @Published private(set) var rows: [ConversationRow] = []
    @Published private(set) var selectedID: String?
    var onSelectConversation: ((String) -> Void)?
    private let store: ChatStore
    private var cancellables = Set<AnyCancellable>()

    init(store: ChatStore) {
        self.store = store
        store.$conversations
            .map { conversations in
                conversations.map {
                    ConversationRow(id: $0.id, title: $0.title,
                                    preview: $0.messages.last?.text ?? "暂无消息")
                }
            }
            .sink { [weak self] in self?.rows = $0 }
            .store(in: &cancellables)
    }

    func select(id: String) {
        guard store.conversation(id: id) != nil else { return }
        selectedID = id
        onSelectConversation?(id)
    }
}
