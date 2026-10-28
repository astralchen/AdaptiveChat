import Foundation
import Combine

/// 示例数据源。所有修改在主线程进行；接入服务端时在此替换存储实现。
/// 每个 Scene 拥有一个实例；数据只在当前运行期间保留。
@MainActor
final class ChatStore {
    @Published private(set) var conversations: [Conversation]
    private var drafts: [String: String] = [:]
    private var positions: [String: MessageScrollPosition] = [:]

    init(conversations: [Conversation]? = nil) {
        self.conversations = conversations ?? Self.sampleConversations
    }

    func conversation(id: String) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func draft(for id: String) -> String { drafts[id, default: ""] }

    func saveDraft(_ text: String, for id: String) { drafts[id] = text }

    func scrollPosition(for id: String) -> MessageScrollPosition? { positions[id] }

    func saveScrollPosition(_ position: MessageScrollPosition, for id: String) {
        positions[id] = position
    }

    @discardableResult
    func send(_ text: String, to id: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == id }) else { return false }
        drafts[id] = ""
        var updated = conversations
        updated[index].messages.append(Message(text: trimmed, isOutgoing: true))
        conversations = updated
        return true
    }

    static let sampleConversations: [Conversation] = [
        Conversation(id: "design", title: "设计讨论", messages: [
            Message(text: "iPad 上可以同时查看会话列表和聊天内容。", isOutgoing: false),
            Message(text: "iPhone 和窄窗口则使用单列导航。", isOutgoing: true),
            Message(text: "试试输入草稿，再切换会话或旋转设备。", isOutgoing: false)
        ]),
        Conversation(id: "team", title: "项目小组", messages:
            (1...30).map { Message(text: "第 \($0) 条讨论：这是用于验证滚动位置恢复的示例消息。", isOutgoing: $0.isMultiple(of: 3)) }),
        Conversation(id: "alex", title: "小林", messages: [
            Message(text: "下午一起看看新的导航方案吧。", isOutgoing: false)
        ])
    ]
}
