import UIKit
import Combine

final class ChatDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private let viewModel: ChatDetailViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let input = UITextField()
    private let sendButton = UIButton(type: .system)
    private let composer = UIStackView()
    private let emptyLabel = UILabel()
    private var displayedConversation: Conversation?
    private var pendingPosition: MessageScrollPosition?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ChatDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "选择会话"
    }

    required init?(coder: NSCoder) { fatalError("Use init(viewModel:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.accessibilityIdentifier = "messageList"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "message")

        emptyLabel.text = "选择一个会话，开始聊天"
        emptyLabel.font = .preferredFont(forTextStyle: .title3)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        input.borderStyle = .roundedRect
        input.placeholder = "输入消息"
        input.accessibilityIdentifier = "messageInput"
        input.font = .preferredFont(forTextStyle: .body)
        input.adjustsFontForContentSizeCategory = true
        input.returnKeyType = .send
        input.delegate = self
        input.addTarget(self, action: #selector(draftChanged), for: .editingChanged)
        sendButton.setTitle("发送", for: .normal)
        sendButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        sendButton.titleLabel?.adjustsFontForContentSizeCategory = true
        sendButton.accessibilityIdentifier = "sendMessage"
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)
        composer.axis = .horizontal
        composer.spacing = 12
        composer.alignment = .center
        composer.addArrangedSubview(input)
        composer.addArrangedSubview(sendButton)

        for child in [tableView, composer, emptyLabel] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -8),
            composer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            composer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            composer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            sendButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            emptyLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
        viewModel.$conversation.sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    private func render(_ conversation: Conversation?) {
        displayedConversation = conversation
        title = conversation?.title ?? "选择会话"
        emptyLabel.isHidden = conversation != nil
        composer.isHidden = conversation == nil
        tableView.isHidden = conversation == nil
        input.text = viewModel.draft
        updateSendButton()
        pendingPosition = viewModel.scrollPosition
        tableView.reloadData()
        if pendingPosition == nil {
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        }
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let position = pendingPosition {
            pendingPosition = nil
            restore(position)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        captureScrollPosition()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        captureScrollPosition()
        let position = viewModel.scrollPosition
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            if let position { self?.restore(position) }
        }
    }

    func captureScrollPosition() {
        guard isViewLoaded, let conversation = displayedConversation,
              conversation.id == viewModel.conversation?.id,
              let indexPath = tableView.indexPathsForVisibleRows?.sorted().first,
              conversation.messages.indices.contains(indexPath.row) else { return }
        let rowRect = tableView.rectForRow(at: indexPath)
        let offset = tableView.contentOffset.y + tableView.adjustedContentInset.top - rowRect.minY
        viewModel.saveScrollPosition(MessageScrollPosition(
            messageID: conversation.messages[indexPath.row].id, offsetWithinRow: Double(offset)))
    }

    private func restore(_ position: MessageScrollPosition) {
        guard let row = displayedConversation?.messages.firstIndex(where: { $0.id == position.messageID }) else { return }
        tableView.layoutIfNeeded()
        let path = IndexPath(row: row, section: 0)
        tableView.scrollToRow(at: path, at: .top, animated: false)
        tableView.layoutIfNeeded()
        let rect = tableView.rectForRow(at: path)
        let minimum = -tableView.adjustedContentInset.top
        let maximum = max(minimum, tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom)
        let offset = rect.minY + CGFloat(position.offsetWithinRow) - tableView.adjustedContentInset.top
        tableView.setContentOffset(CGPoint(x: 0, y: min(maximum, max(minimum, offset))), animated: false)
    }

    @objc private func draftChanged() {
        viewModel.updateDraft(input.text ?? "")
        updateSendButton()
    }

    private func updateSendButton() {
        sendButton.isEnabled = !(input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func send() {
        guard viewModel.sendDraft(), let count = displayedConversation?.messages.count, count > 0 else { return }
        pendingPosition = nil
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: IndexPath(row: count - 1, section: 0), at: .bottom, animated: false)
        captureScrollPosition()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool { send(); return false }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedConversation?.messages.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "message", for: indexPath)
        guard let message = displayedConversation?.messages[indexPath.row] else { return cell }
        var content = cell.defaultContentConfiguration()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = message.isOutgoing ? .right : .left
        content.attributedText = NSAttributedString(string: message.text, attributes: [.paragraphStyle: paragraph])
        content.textProperties.numberOfLines = 0
        content.secondaryAttributedText = NSAttributedString(
            string: message.isOutgoing ? "我" : (displayedConversation?.title ?? ""),
            attributes: [.paragraphStyle: paragraph])
        content.secondaryTextProperties.color = .secondaryLabel
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        cell.contentConfiguration = content
        cell.backgroundColor = message.isOutgoing ? .secondarySystemBackground : .systemBackground
        cell.selectionStyle = .none
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { captureScrollPosition() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { captureScrollPosition() }
    }
}
