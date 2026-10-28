import UIKit
import Combine

final class ChatListViewController: UITableViewController {
    private let viewModel: ChatListViewModel
    private var rows: [ConversationRow] = []
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ChatListViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
        title = "聊天"
    }

    required init?(coder: NSCoder) { fatalError("Use init(viewModel:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        tableView.accessibilityIdentifier = "conversationList"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "conversation")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        viewModel.$rows.sink { [weak self] rows in
            guard let self else { return }
            self.rows = rows
            self.tableView.reloadData()
            self.restoreSelection(id: self.viewModel.selectedID)
        }.store(in: &cancellables)
        viewModel.$selectedID.sink { [weak self] in self?.restoreSelection(id: $0) }
            .store(in: &cancellables)
    }

    private func restoreSelection(id: String?) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "conversation", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.preview
        content.secondaryTextProperties.numberOfLines = 2
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: "person.crop.circle.fill")
        content.imageProperties.tintColor = .systemIndigo
        cell.contentConfiguration = content
        cell.accessibilityIdentifier = "conversation.\(row.id)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.select(id: rows[indexPath.row].id)
    }
}
