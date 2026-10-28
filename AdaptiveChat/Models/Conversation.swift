import Foundation

struct Message: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isOutgoing: Bool

    init(text: String, isOutgoing: Bool) {
        id = UUID()
        self.text = text
        self.isOutgoing = isOutgoing
    }
}

struct Conversation: Identifiable, Equatable {
    let id: String
    let title: String
    var messages: [Message]
}

struct ConversationRow: Identifiable, Equatable {
    let id: String
    let title: String
    let preview: String
}

/// 用消息锚点而非绝对 contentOffset 恢复位置，适应旋转后的行高变化。
struct MessageScrollPosition {
    let messageID: UUID
    let offsetWithinRow: Double
}
