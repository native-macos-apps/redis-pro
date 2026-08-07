//
//  RedisKeysOutlineView.swift
//  redis-pro
//
//  Native NSOutlineView sidebar — proper macOS UX:
//  source-list style, keyboard navigation, expansion state,
//  double-click rename, context menu, load-more row.
//

import AppKit
import SwiftUI

// MARK: - OutlineItem (class wrapper for struct identity)

/// `NSOutlineView` requires reference-type items for stable identity across reloads.
/// This thin class box wraps `RedisKeyNode` (a value type) and pre-builds
/// its child `OutlineItem` array so the outline can traverse the tree by reference.
final class OutlineItem: NSObject {
    let node: RedisKeyNode
    let children: [OutlineItem]   // empty for leaf nodes

    init(node: RedisKeyNode) {
        self.node = node
        self.children = node.children?.map { OutlineItem(node: $0) } ?? []
        super.init()
    }

    var isFolder: Bool { node.isFolder }
}

/// Recursively builds an `[OutlineItem]` tree from `[RedisKeyNode]`.
private func buildItems(_ nodes: [RedisKeyNode]) -> [OutlineItem] {
    nodes.map { OutlineItem(node: $0) }
}

// MARK: - NSOutlineView Subclass (for context menu)

/// Subclass required to override `menu(for:)` — `NSOutlineViewDelegate` has no
/// equivalent callback for contextual menus.
final class ContextMenuOutlineView: NSOutlineView {
    /// Called on main thread to provide context menu for an item.
    @MainActor var contextMenuProvider: ((OutlineItem) -> NSMenu?)?

    @MainActor override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        guard row >= 0, let item = self.item(atRow: row) as? OutlineItem else {
            return super.menu(for: event)
        }
        return contextMenuProvider?(item)
    }
}

// MARK: - SwiftUI Wrapper

struct RedisKeysOutlineView: NSViewRepresentable {
    let viewModel: RedisKeysViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        // ── Outline View ──────────────────────────────────────────────────
        let outline = ContextMenuOutlineView()
        outline.style = .sourceList
        outline.autoresizesOutlineColumn = true
        outline.headerView = nil

        let col = NSTableColumn(identifier: .init("main"))
        col.resizingMask = .autoresizingMask
        outline.addTableColumn(col)
        outline.outlineTableColumn = col

        outline.dataSource = coordinator
        outline.delegate   = coordinator

        // Double-click → rename
        outline.target = coordinator
        outline.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        coordinator.outlineView = outline
        // Context menu: use closure to bridge Coordinator (@MainActor) → subclass (non-isolated).
        // Safe because menu(for:) is always called on the main thread.
        outline.contextMenuProvider = { [weak coordinator] item in
            coordinator?.buildContextMenu(for: item)
        }

        // ── Scroll View ───────────────────────────────────────────────────
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        outline.backgroundColor = .clear

        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(
            nodes: viewModel.redisKeyNodes,
            selectedId: viewModel.selectedKeyId,
            hasMore: viewModel.hasMoreKeys,
            isLoadingMore: viewModel.isLoadingMore
        )
    }
}

// MARK: - Coordinator

@MainActor
final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    // ── Dependencies ──────────────────────────────────────────────────────
    private let viewModel: RedisKeysViewModel
    weak var outlineView: NSOutlineView?

    // ── Data ──────────────────────────────────────────────────────────────
    /// Snapshot of the last-rendered nodes (value type, for diffing).
    private var currentNodes: [RedisKeyNode] = []
    /// Reference-type items backed by `currentNodes`.
    private var rootItems: [OutlineItem] = []
    private var hasMore: Bool = false
    private var isLoadingMore: Bool = false

    /// Node IDs of currently expanded folders — survives reloads.
    private var expandedIDs: Set<String> = []

    /// Guards against selection feedback loop.
    private var isUpdatingSelection = false

    init(viewModel: RedisKeysViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Update from SwiftUI

    func update(nodes: [RedisKeyNode],
                selectedId: String?,
                hasMore: Bool,
                isLoadingMore: Bool) {
        guard let outline = outlineView else { return }

        let nodesChanged = nodes != currentNodes
        let moreChanged  = hasMore != self.hasMore || isLoadingMore != self.isLoadingMore

        if nodesChanged || moreChanged {
            currentNodes     = nodes
            self.hasMore     = hasMore
            self.isLoadingMore = isLoadingMore

            // Rebuild reference-type item tree.
            rootItems = buildItems(currentNodes)

            outline.reloadData()

            // Restore expansion state using the newly-built item tree.
            restoreExpansion(in: outline, items: rootItems)
        }

        syncSelection(outline, selectedId: selectedId)
    }

    // MARK: - Expansion State

    private func restoreExpansion(in outline: NSOutlineView, items: [OutlineItem]) {
        for item in items {
            guard item.isFolder else { continue }
            if expandedIDs.contains(item.node.id) {
                outline.expandItem(item)
            }
            if !item.children.isEmpty {
                restoreExpansion(in: outline, items: item.children)
            }
        }
    }

    // MARK: - Selection Sync

    private func syncSelection(_ outline: NSOutlineView, selectedId: String?) {
        guard !isUpdatingSelection else { return }
        isUpdatingSelection = true
        defer { isUpdatingSelection = false }

        if let selectedId {
            if let target = findItem(id: selectedId, in: rootItems) {
                let row = outline.row(forItem: target)
                if row >= 0, outline.selectedRow != row {
                    outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    outline.scrollRowToVisible(row)
                }
            }
        } else if outline.selectedRow >= 0 {
            outline.deselectAll(nil)
        }
    }

    private func findItem(id: String, in items: [OutlineItem]) -> OutlineItem? {
        for item in items {
            if item.node.id == id { return item }
            if let found = findItem(id: id, in: item.children) { return found }
        }
        return nil
    }

    // MARK: - Double-click → rename keys / toggle expand folders

    @objc func handleDoubleClick(_ sender: Any?) {
        guard let outline = outlineView else { return }
        let row = outline.clickedRow
        guard row >= 0, let item = outline.item(atRow: row) as? OutlineItem else { return }

        if !item.isFolder {
            let key = item.node.fullName
            if let index = viewModel.table.datasource.firstIndex(where: { $0.key == key }) {
                viewModel.rename.key     = key
                viewModel.rename.newKey  = key
                viewModel.rename.index   = index
                viewModel.rename.visible = true
            }
        } else {
            if outline.isItemExpanded(item) {
                outline.collapseItem(item)
            } else {
                outline.expandItem(item)
            }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItems.count + (hasMore || isLoadingMore ? 1 : 0)
        }
        if let item = item as? OutlineItem {
            return item.children.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            if index == rootItems.count { return LoadMoreSentinel.shared }
            return rootItems[index]
        }
        if let item = item as? OutlineItem {
            return item.children[index]
        }
        fatalError("Unexpected item type in outlineView(_:child:ofItem:)")
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? OutlineItem)?.isFolder ?? false
    }

    // MARK: - NSOutlineViewDelegate: Cell Views

    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        if item is LoadMoreSentinel {
            return makeLoadMoreCell(outlineView)
        }
        guard let outlineItem = item as? OutlineItem else { return nil }
        return outlineItem.isFolder
            ? makeFolderCell(outlineView, item: outlineItem)
            : makeKeyCell(outlineView, item: outlineItem)
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let item = item as? OutlineItem else { return false }
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingSelection,
              let outline = notification.object as? NSOutlineView else { return }

        let row = outline.selectedRow

        // Nothing selected
        if row < 0 {
            viewModel.selectNode(nil)
            return
        }

        // Selected node (leaf key or folder) → notify viewModel
        if let item = outline.item(atRow: row) as? OutlineItem {
            isUpdatingSelection = true
            viewModel.selectNode(item.node.id)
            isUpdatingSelection = false
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? OutlineItem else { return }
        expandedIDs.insert(item.node.id)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? OutlineItem else { return }
        expandedIDs.remove(item.node.id)
    }

    // MARK: - Context Menu (called by ContextMenuOutlineView subclass)

    func buildContextMenu(for outlineItem: OutlineItem) -> NSMenu? {
        let node = outlineItem.node
        let menu = NSMenu()

        let copyName = NSMenuItem(title: "Copy Key Name",
                                  action: #selector(handleCopyKeyName(_:)),
                                  keyEquivalent: "")
        copyName.representedObject = node.fullName as NSString
        copyName.target = self
        menu.addItem(copyName)

        if !node.isFolder {
            let copyValue = NSMenuItem(title: "Copy Value",
                                       action: #selector(handleCopyValue(_:)),
                                       keyEquivalent: "")
            copyValue.representedObject = outlineItem
            copyValue.target = self
            menu.addItem(copyValue)
        }

        menu.addItem(.separator())

        let delete = NSMenuItem(title: "Delete",
                                action: #selector(handleDelete(_:)),
                                keyEquivalent: "")
        delete.representedObject = outlineItem
        delete.target = self
        delete.attributedTitle = NSAttributedString(
            string: "Delete",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        menu.addItem(delete)

        return menu
    }

    @objc private func handleCopyKeyName(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? NSString else { return }
        PasteboardHelper.copy(name as String)
    }

    @objc private func handleCopyValue(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? OutlineItem else { return }
        viewModel.copyValue(item.node)
    }

    @objc private func handleDelete(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? OutlineItem else { return }
        viewModel.deleteNodeConfirm(item.node)
    }

    // MARK: - Cell Factories (reuse queues)

    private func makeFolderCell(_ outline: NSOutlineView, item: OutlineItem) -> NSView {
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: FolderCellView
        if let reused = outline.makeView(withIdentifier: id, owner: self) as? FolderCellView {
            cell = reused
        } else {
            cell = FolderCellView()
            cell.identifier = id
        }
        cell.configure(node: item.node)
        return cell
    }

    private func makeKeyCell(_ outline: NSOutlineView, item: OutlineItem) -> NSView {
        let id = NSUserInterfaceItemIdentifier("KeyCell")
        let cell: KeyCellView
        if let reused = outline.makeView(withIdentifier: id, owner: self) as? KeyCellView {
            cell = reused
        } else {
            cell = KeyCellView()
            cell.identifier = id
        }
        cell.configure(node: item.node)
        return cell
    }

    private func makeLoadMoreCell(_ outline: NSOutlineView) -> NSView {
        let id = NSUserInterfaceItemIdentifier("LoadMoreCell")
        let cell: LoadMoreCellView
        if let reused = outline.makeView(withIdentifier: id, owner: self) as? LoadMoreCellView {
            cell = reused
        } else {
            cell = LoadMoreCellView()
            cell.identifier = id
        }
        cell.configure(isLoading: isLoadingMore) { [weak self] in
            self?.viewModel.loadMoreKeysIfNeeded()
        }
        return cell
    }
}

// MARK: - Load More Sentinel

/// Singleton sentinel used as the "load more" row item.
final class LoadMoreSentinel: NSObject, @unchecked Sendable {
    static let shared = LoadMoreSentinel()
    private override init() {}
}

// MARK: - Folder Cell View

final class FolderCellView: NSTableCellView {

    private let iconView   = NSImageView()
    private let nameLabel  = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints   = false
        nameLabel.translatesAutoresizingMaskIntoConstraints  = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.symbolConfiguration = .init(pointSize: NSFont.systemFontSize, weight: .regular)

        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.cell?.wraps = false

        countLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.alignment = .right
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -6),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(node: RedisKeyNode) {
        nameLabel.stringValue  = node.name
        countLabel.stringValue = "\(node.keyCount)"
    }
}

// MARK: - Key Cell View

final class KeyCellView: NSTableCellView {

    private let badge     = TypeBadgeNSView()
    private let nameLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        badge.translatesAutoresizingMaskIntoConstraints     = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.cell?.wraps = false

        addSubview(badge)
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 15),
            badge.heightAnchor.constraint(equalToConstant: 15),

            nameLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 5),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    func configure(node: RedisKeyNode) {
        nameLabel.stringValue = node.name
        badge.configure(type: node.type ?? "")
    }
}

// MARK: - Type Badge (pure AppKit)

/// Colored rounded rectangle with the first letter of the Redis key type.
final class TypeBadgeNSView: NSView {

    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 9, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.drawsBackground = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(type: String) {
        let upper = type.uppercased()
        label.stringValue = upper.isEmpty ? "–" : String(upper.prefix(1))
        layer?.backgroundColor = color(for: upper).cgColor
    }

    private func color(for type: String) -> NSColor {
        switch type {
        case "STRING": return NSColor(red: 0.20, green: 0.74, blue: 0.40, alpha: 1) // jade green
        case "HASH":   return NSColor(red: 0.94, green: 0.36, blue: 0.36, alpha: 1) // coral red
        case "LIST":   return NSColor(red: 0.28, green: 0.56, blue: 0.95, alpha: 1) // sky blue
        case "SET":    return NSColor(red: 0.98, green: 0.62, blue: 0.22, alpha: 1) // amber
        case "ZSET":   return NSColor(red: 0.62, green: 0.38, blue: 0.96, alpha: 1) // violet
        default:       return NSColor.secondaryLabelColor
        }
    }
}

// MARK: - Load More Cell View

final class LoadMoreCellView: NSTableCellView {

    private let button = NSButton(title: "", target: nil, action: nil)
    private var onTap: (@MainActor () -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = .systemFont(ofSize: 11.5)
        button.contentTintColor = .secondaryLabelColor
        button.alignment = .center
        button.target = self
        button.action = #selector(tapped)

        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(isLoading: Bool, onTap: @escaping @MainActor () -> Void) {
        self.onTap       = onTap
        button.title     = isLoading ? "Loading more keys…" : "Load more"
        button.isEnabled = !isLoading
    }

    @objc private func tapped() {
        MainActor.assumeIsolated { onTap?() }
    }
}
