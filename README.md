# AdaptiveChat

可直接打开的 UIKit 示例工程，最低支持 iOS 15，适配 iPhone 和 iPad，采用 MVVM + Coordinator + Combine，无第三方依赖。

## 运行

1. 使用 Xcode 16 或更新版本打开 `AdaptiveChat.xcodeproj`。
2. 选择 `AdaptiveChat` Scheme，以及 iPhone 或 iPad 模拟器，运行。
3. 如需运行到真机，在 Signing & Capabilities 中选择自己的 Team 并设置 Bundle Identifier。

最低部署版本是 iOS 15；编译需要 iOS 18+ SDK，因为源代码包含受 `#available(iOS 18.0, *)` 保护的 `UITab` API。工程不需要 CocoaPods、SPM、XcodeGen 或 Storyboard。

## 控制器层级

```text
AppTabBarController
├── 聊天：ChatCoordinator.rootViewController (UISplitViewController)
│   ├── primary: UINavigationController → ChatListViewController
│   └── secondary: UINavigationController → ChatDetailViewController
├── 联系人：UINavigationController → InfoViewController
└── 设置：UINavigationController → InfoViewController
```

聊天模块包含完整的示例列表、详情、草稿与本地发送流程；联系人和设置为占位页面。

## 适配行为

| 环境 | 展示 |
| --- | --- |
| 折叠状态（通常出现在 compact 宽度） | 列表和详情单列导航；首次启动显示列表；详情可返回列表 |
| 展开状态，采用本例的双列展示模式 | 会话列表和聊天详情并列；未选择会话时右侧显示占位内容 |
| 窗口尺寸环境变化 | UIKit 管理 Split View 的折叠或展开；保持同一套控制器和 ViewModel |
| iOS 15–17 | 使用 `viewControllers` 配置普通 Tab |
| iOS 18+ | 使用 `UITab` 和 `.tabSidebar`；系统决定适合当前平台及宽度的外观 |

适配依据窗口环境，不根据 `UIDevice.current.userInterfaceIdiom` 手动选择 push 或双列。iPad 不是始终双列，iPhone 也不硬编码为永远 compact。系统具体栏位外观随 OS 和可用空间变化。

`ChatCoordinator` 配置 `.doubleColumn`，并在选中会话后调用 `show(.secondary)`：展开时详情保持在右侧，折叠时进入详情列。未提供 `.compact` 控制器，让系统负责同一组列的折叠导航。没有混用旧版 `collapseSecondary` 回调，也没有手工搬移子控制器或覆盖 Size Class。

全局 Sidebar 和会话列表是两个不同层级。iOS 18+ 展开 Sidebar 后，可能同时显示全局模块、会话列表和详情。若产品只需要顶部 Tab，可把 `AppTabBarController` 中的 `.tabSidebar` 改为 `.tabBar`。

## 展开与折叠：层级和交互分析

本工程在不同设备上使用相同的逻辑层级：Tab 管理全局模块，Split View 管理聊天模块的列表和详情，各列使用自己的 Navigation Controller。变化的是这些逻辑列如何呈现，以及 UIKit 如何组织折叠后的导航，不是为每一种设备创建另一套页面或 ViewModel。

以下以从左到右的界面为例。“iPad 宽窗口”和“iPhone”只是常见使用场景，代码不按设备名称分支。适配由当前窗口环境驱动；要判断容器实际是否折叠，应读取 `isCollapsed`，不能仅根据设备类型推断。

### 展开状态：层级并排展示

本例采用 `.oneBesideSecondary` 和 `.tile`，让会话列表与聊天详情同时可见：

```text
┌────────────────┬────────────────────────┐
│ 会话列表        │ 聊天详情                │
│                │                        │
│ 小林 ← 选中     │ 与小林的消息             │
│ 项目小组        │                        │
└────────────────┴────────────────────────┘
```

点击会话时，更新右侧详情的 ViewModel。列表仍然可见，用户可以直接切换其他会话，无需先返回列表。初次打开尚未选中会话时，右侧展示占位内容。

这里的并排效果来自本例的展示模式设置；不能把“未折叠”一概理解为“所有列始终可见”，其他展示模式也可以隐藏或覆盖前导列。

### 折叠状态：层级依次展示

```text
会话列表 ──点击──→ 聊天详情
         ←─返回──
```

本例没有设置独立的 `.compact` 控制器，因此 Split View 折叠后，由系统将已有列组织为单列导航。用户先看列表，再进入详情；返回列表后可以选择其他会话。应用无需手工把详情控制器从一列搬到另一列。

### 行为对照

| 处理点 | 展开状态（通常为 iPad 宽窗口） | 折叠状态（通常为 iPhone） |
| --- | --- | --- |
| 首次打开 | 列表 + 空详情 | 只显示列表 |
| 点击会话 | 更新右侧内容 | 进入详情列 |
| 切换会话 | 直接点左侧列表 | 先返回列表 |
| 导航栏 | 每列管理自己的导航 | 系统管理折叠后的导航与返回 |
| 草稿、消息状态 | 同一套 ViewModel / Store | 同一套 ViewModel / Store |

设备名称仅表示常见场景，代码不区分 iPad / iPhone。实际行为取决于当前窗口环境与 Split View 状态；iPad 窄窗口也可能折叠。表中的展开状态指本例配置的双列并排模式。

### 一套导航入口，两种展示结果

`ChatCoordinator` 中的入口先更新会话内容，再请求显示详情列：

```swift
private func showConversation(id: String) {
    detailViewController.captureScrollPosition()
    detailViewModel.open(id: id)

    // 折叠时进入已有详情列；展开时不改变 secondary 的布局，
    // 详情页面直接呈现 ViewModel 更新后的内容。
    rootViewController.show(.secondary)
}
```

`show(.secondary)` 指向已经安装的逻辑列，不是在每次点击时新建一个聊天页面。展开时对 secondary 调用 show 不会强制恢复双列；并排布局由展示模式配置决定。折叠时则由 UIKit 将详情列带到顶部，避免应用另行向 primary 导航栈重复 push 同一个控制器。

### 折叠时显示哪一列，由业务策略决定

本工程在 `topColumnForCollapsingToProposedTopColumn` 回调中使用：

```swift
listViewModel.selectedID == nil ? .primary : .secondary
```

未选会话时返回 primary，避免初始折叠布局显示空详情；已有选中会话时返回 secondary，让用户继续阅读当前聊天。这个回调处理容器折叠，不会在每次点击会话时执行。

“选中的会话”与“当前停留的页面”是不同状态。当前实现返回列表时不清除 selectedID，因此后续再次展开再折叠，仍优先显示该会话。如果产品要求严格恢复最后停留的列表或详情，应另存导航位置，并用它决定折叠后的顶部列。

### 展示变化不应清除业务状态

Split View 负责列的展示与导航，Coordinator 负责路由和适配策略，ViewModel / Store 负责消息、选中会话、草稿与滚动锚点。窗口变化时不重建整套业务对象，才可以在单双列之间切换时保留聊天上下文。

本例的状态保留范围是同一个 Scene 的当前运行期间；它不等同于持久化，重启后的恢复和多窗口同步仍需单独实现。

## UISplitViewController 阅读指南

从 `AdaptiveChat/Coordinators/ChatCoordinator.swift` 开始阅读，代码按 1–7 步标注了配置与导航过程。

| API / 概念 | 在本例中的意义 |
| --- | --- |
| `init(style: .doubleColumn)` | 声明列表、详情两个逻辑列；不保证始终同时显示 |
| `.primary` / `.secondary` | 会话列表列 / 聊天详情列 |
| `setViewController(_:for:)` | 为指定列安装内容控制器，通常在初始化时配置 |
| `preferredDisplayMode` | 希望显示哪些列；`.oneBesideSecondary` 表示列表与详情并排 |
| `preferredSplitBehavior` | 列的布局方式；`.tile` 表示平铺占用各自空间 |
| `minimum/maximumPrimaryColumnWidth` | 展开时列表列的最小/最大宽度，单位 point |
| `preferredPrimaryColumnWidthFraction` | 展开时列表列期望占 Split View 可用宽度的比例 |
| `show(.secondary)` | 折叠时进入已有详情列；展开时对 secondary 不改变布局 |
| `isCollapsed` | 读取容器当前是否已经折叠，不能用它设置折叠状态 |
| `displayMode` | 读取实际展示模式；与表示偏好的 `preferredDisplayMode` 区分 |
| `topColumnForCollapsing…` | 折叠时决定顶部显示哪一列，返回 `Column` |
| `displayModeForExpanding…` | 展开时决定列的展示方式，返回 `DisplayMode` |
| `.compact` 列 | 可选的折叠专用替代内容；本例不设置，让系统复用已有列 |

注意三个容易混淆的点：

- 「选择内容」与「显示列」是两步：先由 ViewModel 打开会话，再调用 `show(.secondary)`。Split View 不知道某个会话 ID 的含义。
- iPad 设备类型、窗口的 horizontal size class、Split View 的 `isCollapsed` 是不同概念。窗口缩窄可能导致折叠；不要仅按设备类型决定导航。
- 本例折叠策略是“有选中会话就展示详情”。返回列表不会清除选中项，因此下一次展开后再折叠仍进入该会话。若需要记住最后停留在列表还是详情，应另存导航位置。

## MVVM 分工

- `Models/Conversation.swift`：消息、会话、列表行及滚动锚点模型。
- `Services/ChatStore.swift`：唯一的内存数据源；发送消息、按会话保存草稿和滚动锚点。
- `ViewModels/ChatListViewModel.swift`：将会话转换为列表行，管理选中项，发出导航意图。
- `ViewModels/ChatDetailViewModel.swift`：当前会话、草稿修改、发送操作和滚动状态。
- `Coordinators/ChatCoordinator.swift`：接收导航意图，管理 Split View 与折叠时显示的列。
- `Views/`：UIKit 布局、事件转发和 Combine 绑定；不直接访问 Store。
- `App/`：应用入口与每个 Scene 的窗口创建。

ViewModel 不依赖 UIKit。Store 和 ViewModel 使用 `@MainActor`；Combine 发布的数据在主线程同步更新。视图绑定使用发布事件中的值，避免在 `@Published` 的 willSet 阶段读取尚未更新的属性。

每个 Scene 独立持有一套状态。草稿按会话 ID 保存，滚动位置使用消息 ID + 行内偏移；切换会话、Tab 或调整窗口不需要重建业务状态。消息列表用系统自适应行高和字体，输入区使用 iOS 15 的 `keyboardLayoutGuide` 避让键盘。

## 验证

无需模拟器即可在 Mac 执行状态检查：

```bash
bash scripts/check-models.sh
```

检查覆盖合法/非法会话路由、草稿隔离与恢复、滚动锚点保存、拒绝空消息、发送后清空草稿，以及列表和详情同步更新。该脚本检查业务状态，不替代 UIKit 交互测试。

建议在模拟器或真机检查以下交互：

1. iPhone 冷启动：显示会话列表；进入“设计讨论”，再通过返回按钮或手势返回。
2. iPad 宽窗口：初始右侧为空态；选择会话后右侧更新，左侧保留选中项。
3. 在会话 A 输入草稿，切到 B，再返回 A：草稿保留。发送后列表摘要更新。
4. 在“项目小组”滚动到中间，切换会话再返回，检查位置恢复。
5. 在详情打开时旋转设备，或在 iPad 调整窗口宽度：检查单双列切换、会话状态、返回导航及键盘布局。
6. 切换联系人/设置再返回聊天，检查聊天状态；在 iOS 18+ 展开与收起全局 Sidebar。
7. 分别在 iOS 15–17 和 iOS 18+ 验证旧 Tab 与新 Tab/Sidebar 分支。

## 示例范围

消息只在本地内存发送；未接入网络、数据库、登录、推送、附件或服务端同步。重启应用后重置，多个窗口的数据也不共享。联系人和设置仅演示顶层模块。生产项目可在 Store 层引入持久化和异步服务，而无需改变页面层级。

本次验证环境：Xcode 26.5。iOS 真机通用目标和 iOS Simulator 通用目标均编译成功；产物的最低系统版本确认为 15.0，设备家族为 iPhone 和 iPad；上述状态检查通过。当前执行环境无法连接 CoreSimulator 服务，未完成模拟器交互验证，也未在 iOS 15 运行时实测。
