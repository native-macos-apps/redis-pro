//
//  AboutView.swift
//  redis-pro
//
//  Liquid Glass about / credits window.
//

import SwiftUI

struct AboutView: View {

    private let dependencies: [(String, String)] = [
        ("hiredis", "https://github.com/redis/hiredis"),
        ("NIOSSH", "https://github.com/apple/swift-nio-ssh"),
        ("SwiftTreeSitter", "https://github.com/tree-sitter/swift-tree-sitter"),
        ("TreeSitterJSON", "https://github.com/tree-sitter/tree-sitter-json"),
        ("swift-log", "https://github.com/apple/swift-log"),

    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.72)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)

                        Image(systemName: "server.rack")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(spacing: 4) {
                        Text("Redis Pro")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("A beautiful Redis client for macOS")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Link("github.com/cmushroom/redis-pro",
                             destination: URL(string: "https://github.com/cmushroom/redis-pro")!)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text("Open Source Libraries")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(0.5)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    VStack(spacing: 0) {
                        ForEach(dependencies, id: \.0) { dep in
                            HStack {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                Link(dep.0, destination: URL(string: dep.1)!)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.accentColor)

                                Spacer()

                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())

                            if dep.0 != dependencies.last?.0 {
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                }
                .padding(.top, 16)

                Spacer()

                Text("Made by the open-source community")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(16)
        }
        .background(.regularMaterial)
        .frame(minWidth: 400, maxWidth: 480, minHeight: 420, maxHeight: 520)
    }
}
