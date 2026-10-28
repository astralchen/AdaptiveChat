import UIKit

final class AppTabBarController: UITabBarController {
    // 持有 Coordinator：UISplitViewController.delegate 是弱引用，不能只用局部变量创建它。
    private let chatCoordinator = ChatCoordinator(store: ChatStore())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = .systemIndigo
        // 聊天 Tab 直接使用 Split View 作为根容器；两列各自的 Navigation Controller
        // 已在 ChatCoordinator 中配置。Tab 切模块，Split View 管模块内部的列表/详情。
        let chat = chatCoordinator.rootViewController
        let contacts = UINavigationController(rootViewController: InfoViewController(
            title: "联系人", symbol: "person.2", text: "联系人模块\n可在这里接入联系人列表及详情。"))
        let settings = UINavigationController(rootViewController: InfoViewController(
            title: "设置", symbol: "gearshape", text: "Adaptive Chat\niOS 15+ · UIKit · MVVM + Coordinator\n\n消息和草稿为内存中的示例数据，重启后重置。"))

        if #available(iOS 18.0, *) {
            // 新 API 与旧 viewControllers API 分支使用，不混用。
            // 这是全局模块导航的 Sidebar，与聊天 Split View 的 primary 列不同。
            // 此设置不会自动把会话列表和聊天详情拆成双列；双列由 ChatCoordinator 配置。
            mode = .tabSidebar
            tabs = [
                UITab(title: "聊天", image: UIImage(systemName: "bubble.left.and.bubble.right"), identifier: "chat") { _ in chat },
                UITab(title: "联系人", image: UIImage(systemName: "person.2"), identifier: "contacts") { _ in contacts },
                UITab(title: "设置", image: UIImage(systemName: "gearshape"), identifier: "settings") { _ in settings }
            ]
        } else {
            chat.tabBarItem = UITabBarItem(title: "聊天", image: UIImage(systemName: "bubble.left.and.bubble.right"), tag: 0)
            contacts.tabBarItem = UITabBarItem(title: "联系人", image: UIImage(systemName: "person.2"), tag: 1)
            settings.tabBarItem = UITabBarItem(title: "设置", image: UIImage(systemName: "gearshape"), tag: 2)
            viewControllers = [chat, contacts, settings]
        }
    }
}

final class InfoViewController: UIViewController {
    private let symbol: String
    private let text: String

    init(title: String, symbol: String, text: String) {
        self.symbol = symbol
        self.text = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("Use init(title:symbol:text:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.preferredSymbolConfiguration = .init(pointSize: 42)
        icon.contentMode = .scaleAspectFit
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
    }
}
