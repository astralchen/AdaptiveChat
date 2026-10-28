import UIKit

/// 管理聊天模块的导航与自适应容器；ViewModel 不导入 UIKit。
///
/// UISplitViewController 是「容器控制器」：它管理各列的子控制器，
/// 并根据窗口环境把这些列并排展示，或折叠到单列导航中。
/// 它本身不提供会话列表、聊天 UI，也不负责保存草稿等业务数据。
///
/// 本例的层级：
/// UITabBarController → UISplitViewController(.doubleColumn)
///                       ├─ primary   → UINavigationController → 会话列表
///                       └─ secondary → UINavigationController → 聊天详情
///
/// 宽窗口： [会话列表 | 聊天详情]
/// 折叠后： [会话列表] → [聊天详情]，通过系统返回导航回到列表。
///
/// 适配不区分具体设备：本例不根据 iPad / iPhone、设备型号或屏幕宽度写导航分支。
/// UIKit 根据当前窗口的尺寸环境管理展开与折叠；iPad 的窄窗口也可能折叠。
/// Coordinator 只决定选中的内容，以及折叠/展开时的展示策略。
/// 若需要查询实际容器状态，读取 isCollapsed；不要用设备类型推断它。
///
/// 这里使用 iOS 14 引入的 column-style API，满足工程 iOS 15+ 的要求。
@MainActor
final class ChatCoordinator: NSObject, UISplitViewControllerDelegate {
    /// 作为「聊天」Tab 的根控制器。不要再在它外面套一层导航控制器；
    /// 本例让每一列分别拥有自己的 UINavigationController。
    let rootViewController: UISplitViewController
    private let listViewModel: ChatListViewModel
    private let detailViewModel: ChatDetailViewModel
    private let detailViewController: ChatDetailViewController

    init(store: ChatStore) {
        listViewModel = ChatListViewModel(store: store)
        detailViewModel = ChatDetailViewModel(store: store)
        detailViewController = ChatDetailViewController(viewModel: detailViewModel)
        // 1. 选择列结构。
        // .doubleColumn：primary（列表）+ secondary（详情），适合本例。
        // .tripleColumn：额外增加 supplementary，可表达「分类 → 列表 → 详情」。
        // 注意：doubleColumn 表示有两个逻辑列，并非任何窗口下都强制显示两列。
        rootViewController = UISplitViewController(style: .doubleColumn)
        super.init()

        let list = ChatListViewController(viewModel: listViewModel)
        // delegate 让业务决定「折叠后先看哪列」「展开后采用哪种展示模式」。
        // delegate 是弱引用，所以 AppTabBarController 必须持有 ChatCoordinator。
        rootViewController.delegate = self

        // 2. 配置展开时的展示偏好。
        // preferredDisplayMode：希望当前显示哪些列，以及列之间怎样排列。
        // .oneBesideSecondary：一个前导列紧邻详情；doubleColumn 中即列表 + 详情。
        // .secondaryOnly：仅详情；.automatic：交给系统选择。
        // 「preferred」是偏好，不是设备类型判断；实际结果可读 displayMode。
        rootViewController.preferredDisplayMode = .oneBesideSecondary

        // preferredSplitBehavior：限定展开状态下列的布局方式。
        // .tile：各列平铺、占用各自空间；不会把列表浮在详情上面。
        // .overlay 则允许前导列覆盖详情，但需要与对应的 displayMode 配合。
        // tile 不会阻止 compact 环境下的折叠；是否已折叠可读 isCollapsed。
        rootViewController.preferredSplitBehavior = .tile

        // 3. 设置 primary 列宽（单位为 point，不是屏幕像素）。
        // 希望列表占 Split View 可用宽度的 32%，并受最小/最大宽度约束。
        // 这不是整个设备屏幕的 32%：分屏、窗口大小和全局 Sidebar 都可能影响可用空间。
        // 这些属性调节展开时的列宽，不用来设置「多少宽度切换单列」的阈值。
        rootViewController.minimumPrimaryColumnWidth = 280
        rootViewController.maximumPrimaryColumnWidth = 400
        rootViewController.preferredPrimaryColumnWidthFraction = 0.32
        // 4. 给各个逻辑列安装内容控制器。使用 for: 明确列角色，避免依赖数组下标。
        // 每列显式包一层 UINavigationController，提供标题和该列内部的后续导航。
        // 对 primary/secondary 直接传普通 VC 时，系统也会自动包装导航控制器；
        // 本例显式创建，更容易看清层级，并便于以后配置每列的导航栏。
        rootViewController.setViewController(UINavigationController(rootViewController: list), for: .primary)
        rootViewController.setViewController(UINavigationController(rootViewController: detailViewController), for: .secondary)

        // 故意不设置 for: .compact 的控制器：
        // .compact 是一种「替代内容列」，不是对 horizontalSizeClass 的判断。
        // 设置它后，折叠时会显示这套独立内容；本例需要复用原来的列表与详情，
        // 因此让 UIKit 默认堆叠已有列并管理返回导航。
        // column-style 会管理列的显示/返回按钮，无需手动设置旧式 displayModeButtonItem。

        listViewModel.onSelectConversation = { [weak self] id in self?.showConversation(id: id) }
    }

    private func showConversation(id: String) {
        // 先保存旧会话的滚动锚点，再让同一个详情 ViewModel 展示新的会话。
        // Split View 负责容器展示；草稿和消息由 Store/ViewModel 保存。
        detailViewController.captureScrollPosition()
        detailViewModel.open(id: id)

        // 5. 显示「已经安装好的 secondary 列」，无需再创建详情控制器。
        // 折叠时：如果详情列不在顶部，系统将其带到顶部，形成列表 → 详情导航；
        //         如果详情已经在顶部，则不重复进入详情。
        // 展开时：对 secondary 的 show 调用不改变布局，更新后的内容直接显示在详情列。
        //         它并不负责强制恢复双列，展开布局由前面的 displayMode 设置决定。
        //
        // 与 showDetailViewController(_:sender:) 的区别：
        // 后者接收一个内容 VC，表达「展示这份详情」；show(.secondary) 指定已有列。
        // 本例只有一个复用的详情 VC，因此使用 column API。
        // 不要再手动向 primary 的 navigationController push 同一个详情 VC，
        // 否则会与 Split View 对列的管理冲突。
        rootViewController.show(.secondary)
    }

    /// 6. 系统将要从展开状态折叠时，询问「折叠后的顶部列是哪一列」。
    /// 该回调也可能参与初始 compact 布局；并不是每次点击会话都会调用。
    /// proposedTopColumn 是系统建议；若无需定制，直接返回该值即可。
    /// 只需返回列枚举，具体控制器的折叠交给 UIKit，不要在这里手工 push/pop。
    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column)
        -> UISplitViewController.Column {
        // 未选会话 → primary：避免初始折叠布局展示空白详情，与具体设备无关。
        // 已选会话 → secondary：窗口缩窄后继续阅读当前聊天。
        // 这是本例的产品策略：返回列表不会清除 selectedID，
        // 因此之后再次「展开 → 折叠」仍优先展示已选会话。
        // 若产品要求保留用户最后停留的列，应另外记录导航位置，不能只看 selectedID。
        listViewModel.selectedID == nil ? .primary : .secondary
    }

    /// 7. 系统将要从折叠状态展开时，询问「展开后采用哪种 displayMode」。
    /// proposedDisplayMode 是系统建议；本例明确希望恢复会话列表与详情并排。
    /// 返回展示模式即可，不需要重新安装列或重建 ViewModel。
    /// 这与上一个回调的返回类型不同：折叠返回 Column，展开返回 DisplayMode。
    func splitViewController(_ svc: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode)
        -> UISplitViewController.DisplayMode {
        .oneBesideSecondary
    }
}
