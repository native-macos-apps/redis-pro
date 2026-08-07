//
//  RedisKeyNode.swift
//  redis-pro
//
//  Created by chengpanwang on 2024/2/5.
//

import Foundation
import SwiftUI

struct RedisKeyNode: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let fullName: String
    let type: String?      // nil = folder node
    var children: [RedisKeyNode]?
    var keyCount: Int

    var isFolder: Bool { children != nil }

    static func == (lhs: RedisKeyNode, rhs: RedisKeyNode) -> Bool {
        lhs.id == rhs.id && lhs.keyCount == rhs.keyCount && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tree Builder (internal reference node)

/// Mutable reference used only within `buildTree` — never escapes the function.
private final class _TreeNode {
    let name: String
    let fullName: String
    var type: String?
    var children: [String: _TreeNode] = [:]
    var keyCount: Int = 0

    init(name: String, fullName: String, type: String? = nil) {
        self.name = name
        self.fullName = fullName
        self.type = type
    }

    /// Converts to the immutable, value-type `RedisKeyNode` (folders first, then alpha).
    func toKeyNode() -> RedisKeyNode {
        let sorted = children.values
            .sorted {
                if $0.children.isEmpty != $1.children.isEmpty { return !$0.children.isEmpty }
                return $0.name < $1.name
            }
            .map { $0.toKeyNode() }

        return RedisKeyNode(
            id: fullName,
            name: name,
            fullName: fullName,
            type: type,
            children: sorted.isEmpty ? nil : sorted,
            keyCount: children.isEmpty ? 1 : children.values.reduce(0) { $0 + $1.keyCount }
        )
    }
}

// MARK: - Extension

extension RedisKeyNode {
    /// Builds a hierarchical tree from a flat list of `RedisKeyModel`, splitting keys on `:`.
    /// The result sorts folders before leaves at every level.
    static func buildTree(from keys: [RedisKeyModel]) -> [RedisKeyNode] {
        let root = _TreeNode(name: "", fullName: "")

        for key in keys {
            let parts = key.key.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            var current = root
            var pathSoFar = ""

            for (idx, part) in parts.enumerated() {
                pathSoFar = pathSoFar.isEmpty ? part : "\(pathSoFar):\(part)"
                let isLeaf = idx == parts.count - 1

                if let existing = current.children[part] {
                    current = existing
                    if isLeaf {
                        existing.type = key.type
                        existing.keyCount = 1
                    }
                } else {
                    let node = _TreeNode(name: part, fullName: pathSoFar)
                    if isLeaf {
                        node.type = key.type
                        node.keyCount = 1
                    }
                    current.children[part] = node
                    current = node
                }
            }
        }

        // Propagate folder key counts bottom-up
        func propagate(_ node: _TreeNode) -> Int {
            guard !node.children.isEmpty else { return 1 }
            let total = node.children.values.reduce(0) { $0 + propagate($1) }
            node.keyCount = total
            return total
        }
        _ = propagate(root)

        return root.children.values
            .sorted {
                if $0.children.isEmpty != $1.children.isEmpty { return !$0.children.isEmpty }
                return $0.name < $1.name
            }
            .map { $0.toKeyNode() }
    }
}
