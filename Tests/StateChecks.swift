import Foundation

/// 可在 macOS 命令行执行，验证与 UIKit 无关的 MVVM 状态行为。
@main
struct StateChecks {
    @MainActor
    static func main() {
        let store = ChatStore()
        let list = ChatListViewModel(store: store)
        let detail = ChatDetailViewModel(store: store)
        var route: String?
        list.onSelectConversation = { route = $0; detail.open(id: $0) }
        precondition(list.rows.count == 3 && detail.conversation == nil)

        list.select(id: "missing")
        precondition(route == nil && list.selectedID == nil, "Invalid ID must not route")
        list.select(id: "design")
        precondition(route == "design" && detail.conversation?.id == "design")
        detail.updateDraft("设计草稿")
        let messageID = detail.conversation!.messages[0].id
        detail.saveScrollPosition(MessageScrollPosition(messageID: messageID, offsetWithinRow: 12))

        list.select(id: "team")
        precondition(detail.draft.isEmpty && detail.scrollPosition == nil)
        detail.updateDraft("项目草稿")
        list.select(id: "design")
        precondition(detail.draft == "设计草稿", "Draft must survive switching conversations")
        precondition(detail.scrollPosition?.messageID == messageID)
        precondition(detail.scrollPosition?.offsetWithinRow == 12)

        let count = detail.conversation!.messages.count
        detail.updateDraft("  \n ")
        precondition(!detail.sendDraft())
        precondition(detail.conversation!.messages.count == count)
        detail.updateDraft("  新消息  ")
        precondition(detail.sendDraft())
        precondition(detail.draft.isEmpty)
        precondition(detail.conversation!.messages.count == count + 1)
        precondition(detail.conversation!.messages.last?.text == "新消息")
        precondition(list.rows.first(where: { $0.id == "design" })?.preview == "新消息",
                     "List and detail must observe the same published message")
        list.select(id: "team")
        precondition(detail.draft == "项目草稿", "Sending elsewhere must not clear this draft")
        detail.open(id: "missing")
        precondition(detail.conversation?.id == "team")
        precondition(!store.send("hello", to: "missing"))
        print("PASS: selection, invalid routes, per-conversation drafts, scroll anchors, empty-send rejection, message publication, draft clearing")
    }
}
