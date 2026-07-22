//
//  CommandQueryView.swift
//  redis-pro
//
//  Created by Antigravity on 2026-06-02.
//

import SwiftUI
import AppKit

// MARK: - Redis Syntax Highlighter
enum RedisHighlighter {
    private static let commandColor = NSColor(red: 0.15, green: 0.45, blue: 0.82, alpha: 1.0) // Bold blue
    private static let stringColor  = NSColor(red: 0.13, green: 0.60, blue: 0.35, alpha: 1.0) // Green
    private static let numberColor  = NSColor(red: 0.82, green: 0.45, blue: 0.13, alpha: 1.0) // Orange/Brown
    private static let commentColor = NSColor.secondaryLabelColor // Grey
    private static let constColor   = NSColor(red: 0.58, green: 0.22, blue: 0.80, alpha: 1.0) // Purple — for keyword args
    
    // Set of common Redis/Valkey commands for syntax highlighting and autocomplete
    static let redisCommands: Set<String> = [
        "ping", "echo", "set", "get", "del", "exists", "keys", "scan", "ttl", "expire",
        "incr", "decr", "incrby", "decrby", "hset", "hget", "hdel", "hgetall", "hkeys", "hvals",
        "lpush", "rpush", "lpop", "rpop", "lrange", "llen", "ltrim", "sadd", "sismember",
        "smembers", "srem", "sunion", "sinter", "sdiff", "zadd", "zrange", "zrevrange", "zrem",
        "zscore", "zcard", "zrangebyscore", "multi", "exec", "discard", "watch", "unwatch",
        "publish", "subscribe", "psubscribe", "config", "info", "client", "slowlog", "eval", "evalsha",
        "script", "flushdb", "flushall", "dbsize", "select", "auth", "quit"
    ]

    /// Pure-token keyword arguments — highlighted in purple when they appear in argument position.
    static let redisConstants: Set<String> = [
        // SET options
        "ex", "px", "exat", "pxat", "keepttl", "nx", "xx",
        // EXPIRE / GETEX options
        "gt", "lt", "persist",
        // COPY
        "replace",
        // ZADD options
        "ch", "incr",
        // ZRANGE / ZRANGEBYSCORE / ZRANGEBYLEX options
        "withscores", "byscore", "bylex", "rev", "limit",
        // GEORADIUS / GEOSEARCH options
        "frommember", "fromlonlat", "byradius", "bybox", "m", "km", "ft", "mi",
        "withcoord", "withdist", "any", "full", "storedist", "asc", "desc",
        // SORT options
        "alpha", "by", "store",
        // SCAN options
        "match", "count", "type",
        // LINSERT
        "before", "after",
        // LMOVE / LMPOP
        "left", "right",
        // ZUNIONSTORE / ZINTERSTORE aggregate
        "weights", "aggregate", "sum", "min", "max",
        // OBJECT subcommands / INFO sections
        "encoding", "idletime", "refcount", "freq", "help",
        // CONFIG options
        "resetstat", "rewrite",
        // XADD / XTRIM
        "maxlen", "minid", "nomkstream",
        // CLIENT
        "no-evict", "no-touch", "id", "addr", "laddr", "skipme",
        // WAIT / OBJECT
        "timeout",
        // Generic
        "async", "sync",
    ]
    
    static func highlight(_ text: String, commands: Set<String>? = nil) -> NSAttributedString {
        let nsAttr = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Default style (monospace font and default label color)
        nsAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
        nsAttr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        
        let cmds = commands ?? redisCommands  // fall back to built-in list
        
        // 1. Highlight Comments (# or //)
        let commentRegex = try! NSRegularExpression(pattern: "(?m)^\\s*(#|//).*$", options: [])
        commentRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: commentColor, range: range)
            }
        }
        
        // 2. Highlight Strings (single or double quotes)
        let stringRegex = try! NSRegularExpression(pattern: "\"([^\"]*)\"|'([^']*)'", options: [])
        stringRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                nsAttr.addAttribute(.foregroundColor, value: stringColor, range: range)
            }
        }
        
        // 3. Highlight Numbers
        let numberRegex = try! NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b", options: [])
        numberRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                let color = nsAttr.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
                if color != commentColor && color != stringColor {
                    nsAttr.addAttribute(.foregroundColor, value: numberColor, range: range)
                }
            }
        }
        
        // 4. Highlight Redis Commands & 5. Highlight Redis constant keyword arguments
        // Process line-by-line so we can distinguish position-0 (command) from argument positions.
        let lines = text.components(separatedBy: "\n")
        var lineStart = 0
        for line in lines {
            let lineLen = line.utf16.count
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip comment lines
            if !trimmed.hasPrefix("#") && !trimmed.hasPrefix("//") {
                let wordRegex = try! NSRegularExpression(pattern: "\\b\\w+\\b", options: [])
                var tokenIndex = 0  // 0 = command position, 1+ = argument positions

                wordRegex.enumerateMatches(in: line, options: [], range: NSRange(location: 0, length: lineLen)) { match, _, _ in
                    guard let matchRange = match?.range else { return }
                    // Translate local range to full-string range
                    let globalRange = NSRange(location: lineStart + matchRange.location, length: matchRange.length)
                    let word = (line as NSString).substring(with: matchRange).lowercased()
                    let currentColor = nsAttr.attribute(.foregroundColor, at: globalRange.location, effectiveRange: nil) as? NSColor
                    let isProtected = currentColor == commentColor || currentColor == stringColor

                    if !isProtected {
                        if tokenIndex == 0 {
                            // Command position — highlight if known command
                            if cmds.contains(word) {
                                nsAttr.addAttribute(.foregroundColor, value: commandColor, range: globalRange)
                                nsAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold), range: globalRange)
                            }
                        } else {
                            // Argument position — highlight if known constant
                            if redisConstants.contains(word) {
                                nsAttr.addAttribute(.foregroundColor, value: constColor, range: globalRange)
                            }
                        }
                    }
                    tokenIndex += 1
                }
            }

            lineStart += lineLen + 1  // +1 for the "\n" separator
        }
        
        return nsAttr
    }
}

// MARK: - Command Query Main View
struct CommandQueryView: View {
    @State var viewModel: CommandQueryViewModel
    
    /// Number of non-empty whitespace-separated tokens on the current editor line.
    private var typedTokenCount: Int {
        let line = viewModel.selectedCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty,
              !line.hasPrefix("#"),
              !line.hasPrefix("//") else { return 0 }
        return line.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// True when the current line ends with whitespace, meaning the user has finished
    /// typing the last token and is ready to start the next argument.
    private var hasTrailingSpace: Bool {
        // Use selectedCommand before trimming newlines only — preserve trailing spaces
        let line = viewModel.selectedCommand
            .trimmingCharacters(in: .newlines)
        guard !line.isEmpty else { return false }
        return line.last?.isWhitespace == true
    }
    
    var body: some View {
        HSplitView {
            // ── Left: Editor + Console ──────────────────────────────────
            VSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    CommandQueryTextEditor(
                        text: $viewModel.queryText,
                        selectedCommand: $viewModel.selectedCommand,
                        commandNames: viewModel.commandNames,
                        argCompletions: { cmd in viewModel.argCompletions(for: cmd) }
                    ) { cmd in
                        viewModel.executeCommand(cmd)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    
                    // ── Syntax Hint Bar ─────────────────────────────────
                    if let doc = viewModel.commandDoc, !doc.arguments.isEmpty {
                        CommandSyntaxHintBar(
                            doc: doc,
                            selectedCommand: viewModel.selectedCommand,
                            typedTokenCount: typedTokenCount,
                            hasTrailingSpace: hasTrailingSpace
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(minHeight: 120, maxHeight: .infinity)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Status bar
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(viewModel.selectedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0 commands selected" : "1 command selected")
                            .font(.system(.subheadline))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.executeCommand(viewModel.selectedCommand)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Execute Selected")
                                    .font(.system(.caption, design: .monospaced))
                                    .opacity(0.8)
                            }
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(viewModel.selectedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isExecuting)
                        
                        Divider().frame(height: 16)
                        
                        // Toggle docs sidebar button
                        Button(action: {
                            viewModel.showDocsSidebar.toggle()
                        }) {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 13))
                                .foregroundStyle(viewModel.showDocsSidebar ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(viewModel.showDocsSidebar ? "Hide Command Docs" : "Show Command Docs")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(NSColor.separatorColor))
                            .frame(height: 0.5)
                    }
                    
                    // Console Output
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.outputText.isEmpty ? "Console ready. Type a command and press Cmd+Enter to execute." : viewModel.outputText)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(viewModel.outputText.isEmpty ? .secondary : .primary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .id("output-bottom")
                            }
                            .onChange(of: viewModel.outputText) { _, _ in
                                withAnimation {
                                    proxy.scrollTo("output-bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    
                    // Bottom actions
                    Divider()
                    HStack {
                        Button(action: {
                            viewModel.clearOutput()
                        }) {
                            Label("Clear Console", systemImage: "trash")
                                .font(.system(.subheadline))
                        }
                        .buttonStyle(.plain)
                        .help("Clear Console Output")
                        
                        Spacer()
                        
                        Button(action: {
                            exportConsole()
                        }) {
                            Label("Export...", systemImage: "square.and.arrow.up")
                                .font(.system(.subheadline))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.outputText.isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity)
            .layoutPriority(1)
            
            // ── Right: Command Docs Sidebar ─────────────────────────────
            if viewModel.showDocsSidebar {
                CommandDocSidebarView(viewModel: viewModel)
                    .transition(.identity)
            }
        }
        .onChange(of: viewModel.currentDocCommand) { _, newCmd in
            viewModel.fetchCommandDocs(newCmd)
        }
        .onAppear {
            viewModel.fetchCommandList()
            if !viewModel.currentDocCommand.isEmpty {
                viewModel.fetchCommandDocs(viewModel.currentDocCommand)
            }
        }
    }
    
    private func exportConsole() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "redis_command_output.txt"
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try viewModel.outputText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    Messages.show(error)
                }
            }
        }
    }
}

// MARK: - Command Docs Sidebar
struct CommandDocSidebarView: View {
    let viewModel: CommandQueryViewModel
    
    private var docsPageURL: URL? {
        let base = "https://redis.io/docs/latest/commands/"
        let cmd = viewModel.currentDocCommand
        return URL(string: cmd.isEmpty ? base : base + cmd)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                if viewModel.isLoadingDoc {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("Loading docs...")
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let doc = viewModel.commandDoc {
                    CommandDocContentView(doc: doc)
                } else if let err = viewModel.docError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)
                        Text(err)
                            .font(.system(.callout))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("Place cursor on a command\nto view its documentation")
                            .font(.system(.callout))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 260, maxWidth: 400)
    }
}

// MARK: - Native doc content
struct CommandDocContentView: View {
    let doc: CommandDoc
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                // Command name
                Text(doc.name.uppercased())
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .textSelection(.enabled)
                
                // Deprecated badge
                if doc.docFlags.contains("deprecated") {
                    Label("Deprecated", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                // Summary
                if !doc.summary.isEmpty {
                    Text(doc.summary)
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                
                // Group + Since badges
                HStack(spacing: 6) {
                    if !doc.group.isEmpty {
                        Text(doc.group.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if !doc.since.isEmpty {
                        Text("Since v\(doc.since)")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                // Complexity
                if !doc.complexity.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Complexity", systemImage: "clock")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(doc.complexity)
                            .font(.system(.caption, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                
                // Arguments
                if !doc.arguments.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ARGUMENTS")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.secondary)
                            .kerning(1)
                            .padding(.bottom, 2)
                        ForEach(doc.arguments) { arg in
                            CommandArgRow(arg: arg, indent: 0)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Argument row
struct CommandArgRow: View {
    let arg: CommandArgDoc
    let indent: Int
    
    private var typeColor: Color {
        switch arg.type {
        case "key":        return .green
        case "integer", "double": return .orange
        case "pure-token": return Color.accentColor
        case "oneof":      return .purple
        case "block":      return .indigo
        default:           return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let tok = arg.token {
                    Text(tok)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .textSelection(.enabled)
                }
                Text(arg.displayText.isEmpty ? arg.name : arg.displayText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Text(arg.type)
                    .font(.system(.caption2))
                    .foregroundStyle(typeColor)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(typeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            
            if !arg.flags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(arg.flags, id: \.self) { flag in
                        Text(flag)
                            .font(.system(.caption2))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 0.8)
                            }
                    }
                }
            }
            
            // Nested args (oneof / block)
            if !arg.arguments.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(arg.arguments) { nested in
                        HStack(alignment: .top, spacing: 5) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1.5)
                                .padding(.leading, 4)
                            CommandArgRow(arg: nested, indent: indent + 1)
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(indent == 0 ? 0.6 : 0.35))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Command Syntax Hint Bar
struct CommandSyntaxHintBar: View {
    let doc: CommandDoc
    let selectedCommand: String
    /// Total tokens typed on the current line including the command name itself.
    let typedTokenCount: Int
    /// Whether the current line ends with whitespace (user finished typing the last token).
    let hasTrailingSpace: Bool

    /// The index of the argument token the user is currently typing, excluding the command name.
    /// A trailing space moves the cursor to the next argument slot.
    private var currentArgTokenIndex: Int {
        guard typedTokenCount > 0 else { return -1 }
        let argCount = argumentTokens.count
        guard argCount > 0 || hasTrailingSpace else { return -1 }
        return hasTrailingSpace ? argCount : max(0, argCount - 1)
    }

    private var argumentTokens: [String] {
        RedisCommandParser.parse(selectedCommand)?.args ?? []
    }
    
    // MARK: Segment model
    private struct HintSegment: Identifiable {
        let id: Int
        let text: String
    }
    
    private var segments: [HintSegment] {
        doc.arguments.enumerated().map { i, arg in
            HintSegment(id: i, text: formatArgText(arg))
        }
    }

    // MARK: Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Tiny chevron icon
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 7)
                    
                    // Command name — highlight based on currentArgIndex
                    syntaxToken(doc.name.uppercased(),
                                bold: true,
                                style: currentArgTokenIndex >= 0 ? .covered : (typedTokenCount >= 1 ? .current : .future))
                    .id(commandScrollID)
                    
                    // Argument segments — light up progressively
                    ForEach(segments) { seg in
                        let style = segmentStyle(for: seg.id)
                        let position = segmentStartPosition(for: seg.id)
                        
                        HStack(spacing: 0) {
                            Text(" ")
                                .font(.system(size: 11, design: .monospaced))
                            
                            syntaxSegment(doc.arguments[seg.id], text: seg.text, style: style, position: position)
                        }
                        .id(segmentScrollID(seg.id))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .onAppear {
                scrollToCurrentTarget(proxy, targetID: scrollTargetID)
            }
            .onChange(of: scrollTargetID) { _, targetID in
                scrollToCurrentTarget(proxy, targetID: targetID)
            }
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
        }
        .animation(.easeInOut(duration: 0.15), value: typedTokenCount)
    }
    
    // MARK: Helpers
    private enum SegStyle { case covered, current, future }
    
    private var commandScrollID: String { "command" }
    
    private func segmentScrollID(_ segmentIndex: Int) -> String {
        "arg-\(segmentIndex)"
    }
    
    private var scrollTargetID: String {
        guard currentArgTokenIndex >= 0 else { return commandScrollID }
        
        if let current = segments.first(where: { segmentStyle(for: $0.id) == .current }) {
            return segmentScrollID(current.id)
        }
        
        if let covered = segments.last(where: { segmentStyle(for: $0.id) == .covered }) {
            return segmentScrollID(covered.id)
        }
        
        return commandScrollID
    }
    
    private func scrollToCurrentTarget(_ proxy: ScrollViewProxy, targetID: String) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
    }
    
    private struct ArgSpan {
        let matches: Bool
        let tokenCount: Int
    }

    private struct OptionPiece {
        let text: String
        let tokenOffset: Int?
    }

    private func segmentStyle(for segmentIndex: Int) -> SegStyle {
        guard currentArgTokenIndex >= 0 else { return .future }

        var styles = Array(repeating: SegStyle.future, count: doc.arguments.count)
        var position = 0

        for (index, arg) in doc.arguments.enumerated() {
            if position > currentArgTokenIndex { break }

            let span = argumentSpan(arg, from: position)
            if span.matches {
                let end = position + span.tokenCount
                if currentArgTokenIndex < end {
                    styles[index] = .current
                    break
                }

                styles[index] = .covered
                position = end
                continue
            }

            if isOptional(arg) {
                // With no token typed for this slot yet, show the next optional segment as current.
                if position == currentArgTokenIndex && currentArgTokenIndex >= argumentTokens.count {
                    styles[index] = .current
                    break
                }

                continue
            }

            styles[index] = .current
            break
        }

        return segmentIndex < styles.count ? styles[segmentIndex] : .future
    }

    private func segmentStartPosition(for segmentIndex: Int) -> Int {
        var position = 0

        for index in 0..<min(segmentIndex, doc.arguments.count) {
            let arg = doc.arguments[index]
            let span = argumentSpan(arg, from: position)

            if span.matches {
                position += span.tokenCount
            } else if !isOptional(arg) {
                break
            }
        }

        return position
    }
    
    @ViewBuilder
    private func syntaxToken(_ text: String, bold: Bool, style: SegStyle) -> some View {
        Text(text)
            .font(.system(size: 11, weight: bold ? .bold : (style == .current ? .semibold : .regular), design: .monospaced))
            .foregroundStyle(color(for: style))
    }

    @ViewBuilder
    private func syntaxSegment(_ arg: CommandArgDoc, text: String, style: SegStyle, position: Int) -> some View {
        if arg.type == "oneof" {
            oneOfSegment(arg, style: style, position: position)
        } else {
            syntaxToken(text, bold: style == .current, style: style)
        }
    }

    @ViewBuilder
    private func oneOfSegment(_ arg: CommandArgDoc, style: SegStyle, position: Int) -> some View {
        let selectedOption = selectedOneOfOptionIndex(arg, from: position)
        let shouldWrap = isOptional(arg)

        HStack(spacing: 0) {
            if shouldWrap {
                syntaxToken("[", bold: false, style: style)
            }

            ForEach(Array(arg.arguments.enumerated()), id: \.offset) { optionIndex, option in
                if optionIndex > 0 {
                    syntaxToken(" | ", bold: false, style: selectedOption == nil ? style : .future)
                }

                let optionIsSelected = selectedOption == optionIndex
                let optionIsAvailable = selectedOption == nil
                let pieces = optionDisplayPieces(option)

                ForEach(Array(pieces.enumerated()), id: \.offset) { pieceIndex, piece in
                    let pieceTokenIndex = piece.tokenOffset.map { position + $0 }
                    let pieceStyle = oneOfPieceStyle(
                        pieceTokenIndex: pieceTokenIndex,
                        segmentStyle: style,
                        pieceKeyword: keywordCandidate(piece.text),
                        optionIsSelected: optionIsSelected,
                        optionIsAvailable: optionIsAvailable
                    )

                    if pieceIndex > 0 {
                        Text(" ")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(color(for: pieceStyle))
                    }

                    if pieceIndex == 0 {
                        syntaxToken(piece.text, bold: pieceStyle == .current, style: pieceStyle)
                    } else {
                        Text(piece.text)
                            .font(.system(size: 11, weight: pieceStyle == .current ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(color(for: pieceStyle))
                    }
                }
            }

            if shouldWrap {
                syntaxToken("]", bold: false, style: style)
            }
        }
    }

    private func color(for style: SegStyle) -> Color {
        switch style {
        case .covered: return Color.primary.opacity(0.82)
        case .current: return Color.accentColor
        case .future:  return Color.secondary.opacity(0.35)
        }
    }

    private func oneOfPieceStyle(
        pieceTokenIndex: Int?,
        segmentStyle: SegStyle,
        pieceKeyword: String?,
        optionIsSelected: Bool,
        optionIsAvailable: Bool
    ) -> SegStyle {
        guard segmentStyle != .future else { return .future }
        guard let pieceTokenIndex else { return optionIsSelected ? segmentStyle : .future }

        if optionIsAvailable {
            guard segmentStyle == .current && pieceTokenIndex == currentArgTokenIndex else { return .future }

            if hasToken(at: pieceTokenIndex), let pieceKeyword {
                return keywordMatchRank(at: pieceTokenIndex, keyword: pieceKeyword) > 0 ? .current : .future
            }

            return .current
        }

        guard optionIsSelected else { return .future }

        if hasToken(at: pieceTokenIndex), let pieceKeyword {
            guard keywordMatchRank(at: pieceTokenIndex, keyword: pieceKeyword) > 0 else { return .future }
        }

        if pieceTokenIndex < currentArgTokenIndex { return .covered }
        if pieceTokenIndex == currentArgTokenIndex { return .current }
        return .future
    }
    
    // MARK: Recursive arg → display text
    private func isOptional(_ arg: CommandArgDoc) -> Bool {
        arg.flags.contains("optional")
    }

    private func argumentSpan(_ arg: CommandArgDoc, from position: Int) -> ArgSpan {
        let expectedTokenCount = tokenCountEstimate(arg, from: position)

        if let keyword = keywordToken(for: arg) {
            return ArgSpan(
                matches: token(at: position, matchesKeyword: keyword),
                tokenCount: max(1, expectedTokenCount)
            )
        }

        if arg.type == "oneof" {
            if let matched = matchingOneOfOption(arg, from: position) {
                return matched.span
            }
            return ArgSpan(matches: false, tokenCount: max(1, expectedTokenCount))
        }

        if arg.type == "block" {
            return ArgSpan(
                matches: hasToken(at: position),
                tokenCount: max(1, childTokenCount(arg.arguments, from: position))
            )
        }

        return ArgSpan(matches: hasToken(at: position), tokenCount: max(1, expectedTokenCount))
    }

    private func tokenCountEstimate(_ arg: CommandArgDoc, from position: Int) -> Int {
        if arg.type == "pure-token" { return 1 }

        if keywordToken(for: arg) != nil {
            if arg.arguments.isEmpty { return 2 }
            return 1 + childTokenCount(arg.arguments, from: position + 1)
        }

        if arg.type == "oneof" {
            if let matchingChild = matchingOneOfOption(arg, from: position) {
                return tokenCountEstimate(arg.arguments[matchingChild.index], from: position)
            }
            return arg.arguments.map { tokenCountEstimate($0, from: position) }.min() ?? 1
        }

        if arg.type == "block" {
            return childTokenCount(arg.arguments, from: position)
        }

        return 1
    }

    private func childTokenCount(_ args: [CommandArgDoc], from position: Int) -> Int {
        var total = 0
        var childPosition = position

        for child in args {
            let span = argumentSpan(child, from: childPosition)
            if span.matches || !isOptional(child) {
                total += span.tokenCount
                childPosition += span.tokenCount
            }
        }

        return total
    }

    private func keywordToken(for arg: CommandArgDoc) -> String? {
        if let token = arg.token, !token.isEmpty {
            return token
        }

        if arg.type == "pure-token" {
            return arg.name
        }

        return nil
    }

    private func hasToken(at index: Int) -> Bool {
        index >= 0 && index < argumentTokens.count
    }

    private func token(at index: Int, matchesKeyword keyword: String) -> Bool {
        guard hasToken(at: index) else { return false }

        let typed = argumentTokens[index].lowercased()
        let expected = keyword.lowercased()

        if index == currentArgTokenIndex && !hasTrailingSpace {
            return expected.hasPrefix(typed)
        }

        return typed == expected
    }

    private func selectedOneOfOptionIndex(_ arg: CommandArgDoc, from position: Int) -> Int? {
        matchingOneOfOption(arg, from: position)?.index
    }

    private func matchingOneOfOption(_ arg: CommandArgDoc, from position: Int) -> (index: Int, span: ArgSpan)? {
        var hasKeywordOptions = false
        var bestKeywordMatch: (index: Int, rank: Int)?

        for (index, option) in arg.arguments.enumerated() {
            guard let keyword = optionKeyword(for: option) else { continue }

            hasKeywordOptions = true
            let rank = keywordMatchRank(at: position, keyword: keyword)
            guard rank > 0 else { continue }

            if bestKeywordMatch == nil || rank > bestKeywordMatch!.rank {
                bestKeywordMatch = (index, rank)
            }
        }

        if let bestKeywordMatch {
            return (bestKeywordMatch.index, argumentSpan(arg.arguments[bestKeywordMatch.index], from: position))
        }

        if hasKeywordOptions {
            return nil
        }

        for (index, option) in arg.arguments.enumerated() {
            let span = argumentSpan(option, from: position)
            if span.matches {
                return (index, span)
            }
        }

        return nil
    }

    private func keywordMatchRank(at index: Int, keyword: String) -> Int {
        guard hasToken(at: index) else { return 0 }

        let typed = argumentTokens[index].lowercased()
        let expected = keyword.lowercased()

        if typed == expected { return 2 }

        if index == currentArgTokenIndex && !hasTrailingSpace && expected.hasPrefix(typed) {
            return 1
        }

        return 0
    }

    private func optionKeyword(for arg: CommandArgDoc) -> String? {
        var candidates: [String] = []

        if let token = arg.token, !token.isEmpty {
            candidates.append(token)
        }

        candidates.append(arg.name)

        if !arg.displayText.isEmpty {
            candidates.append(arg.displayText)
        }

        if let firstPiece = optionDisplayPieces(arg).first {
            candidates.append(firstPiece.text)
        }

        for candidate in candidates {
            if let keyword = keywordCandidate(candidate) {
                return keyword
            }
        }

        return nil
    }

    private func keywordCandidate(_ text: String) -> String? {
        let keyword = text.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return RedisHighlighter.redisConstants.contains(keyword.lowercased()) ? keyword : nil
    }

    private func optionDisplayPieces(_ arg: CommandArgDoc) -> [OptionPiece] {
        let rawPieces = formatArgText(arg)
            .split(separator: " ")
            .map(String.init)

        var pieces: [OptionPiece] = []
        var nextTokenOffset = 0
        var alternativeTokenOffset: Int? = nil

        for rawPiece in rawPieces {
            if rawPiece == "|" {
                if alternativeTokenOffset == nil {
                    alternativeTokenOffset = pieces.last?.tokenOffset
                }

                pieces.append(OptionPiece(text: rawPiece, tokenOffset: nil))
                continue
            }

            if let alternativeTokenOffset {
                pieces.append(OptionPiece(text: rawPiece, tokenOffset: alternativeTokenOffset))
            } else {
                pieces.append(OptionPiece(text: rawPiece, tokenOffset: nextTokenOffset))
                nextTokenOffset += 1
            }
        }

        return pieces
    }

    private func formatArgText(_ arg: CommandArgDoc) -> String {
        let isOptional = arg.flags.contains("optional")
        let isMultiple = arg.flags.contains("multiple") || arg.flags.contains("variadic")
        
        var inner: String
        switch arg.type {
        case "pure-token":
            inner = arg.token ?? arg.name.uppercased()
        case "oneof":
            // Join nested options with " | "
            let parts = arg.arguments.map { formatArgText($0) }
            inner = parts.joined(separator: " | ")
        case "block":
            // Block carries its keyword token at the block level (e.g. token: "EX")
            // plus the value args nested inside (e.g. seconds).
            // Prepend the block token if present, then space-join nested args.
            var parts: [String] = []
            if let tok = arg.token, !tok.isEmpty {
                parts.append(tok.uppercased())
            }
            parts += arg.arguments.map { formatArgText($0) }
            inner = parts.joined(separator: " ")
        default:
            // key, string, integer, double, unix-time, posix-time, etc.
            // Many of these carry a keyword token (e.g. token: "EX" on an integer arg).
            // Prepend it so "EX seconds" renders correctly instead of just "seconds".
            let display = arg.displayText.isEmpty ? arg.name : arg.displayText
            if let tok = arg.token, !tok.isEmpty {
                inner = "\(tok.uppercased()) \(display)"
            } else {
                inner = display
            }
        }
        
        var result = isOptional ? "[\(inner)]" : inner
        if isMultiple { result += " ..." }
        return result
    }
}

// MARK: - Command Query Text Editor (NSViewRepresentable)
struct CommandQueryTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedCommand: String
    /// Live command list from the server; empty until COMMAND LIST resolves.
    var commandNames: [String]
    /// Returns argument token completions for a given command name (from COMMAND DOCS cache).
    var argCompletions: (String) -> [String]
    var onExecute: (String) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = CommandQueryInternalTextView()
        textView.onExecute = { [weak textView] in
            guard let textView = textView else { return }
            
            let string = textView.string
            let selectedRange = textView.selectedRange()
            let commandToExecute: String
            
            if selectedRange.length > 0 {
                commandToExecute = (string as NSString).substring(with: selectedRange)
            } else {
                let nsString = string as NSString
                let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
                commandToExecute = nsString.substring(with: lineRange)
            }
            
            let trimmed = commandToExecute.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onExecute(trimmed)
            }
        }
        
        scrollView.documentView = textView
        
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Initial highlighting
        let highlighted = RedisHighlighter.highlight(text)
        textView.textStorage?.setAttributedString(highlighted)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        let coordinator = context.coordinator
        
        // Sync dynamic command set when COMMAND LIST arrives; re-highlight immediately
        let newSet: Set<String>? = commandNames.isEmpty ? nil : Set(commandNames)
        if newSet != coordinator.dynamicCommandSet {
            coordinator.dynamicCommandSet = newSet
            if !coordinator.isUpdating {
                coordinator.isUpdating = true
                let sel = textView.selectedRange()
                let highlighted = RedisHighlighter.highlight(textView.string, commands: newSet)
                textView.textStorage?.setAttributedString(highlighted)
                if sel.location <= highlighted.length { textView.setSelectedRange(sel) }
                coordinator.isUpdating = false
            }
        }
        
        if textView.string != text {
            coordinator.isUpdating = true
            let selectedRange = textView.selectedRange()
            let highlighted = RedisHighlighter.highlight(text, commands: coordinator.dynamicCommandSet)
            textView.textStorage?.setAttributedString(highlighted)
            if selectedRange.location <= highlighted.length {
                textView.setSelectedRange(selectedRange)
            }
            coordinator.isUpdating = false
            
            // Initial update of selectedCommand if empty
            if selectedCommand.isEmpty {
                coordinator.updateSelectedCommand(textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CommandQueryTextEditor
        var isUpdating = false
        var isDeleting = false
        /// Live command set from the server; nil until COMMAND LIST completes (falls back to static list).
        var dynamicCommandSet: Set<String>? = nil
        
        init(_ parent: CommandQueryTextEditor) {
            self.parent = parent
        }
        
        // Track whether text was deleted to avoid popping autocomplete lists on backspace
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if let rep = replacementString, rep.isEmpty {
                isDeleting = true
            } else {
                isDeleting = false
            }
            return true
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdating else { return }
            
            isUpdating = true
            let selectedRange = textView.selectedRange()
            let highlighted = RedisHighlighter.highlight(textView.string, commands: dynamicCommandSet)
            textView.textStorage?.setAttributedString(highlighted)
            if selectedRange.location <= highlighted.length {
                textView.setSelectedRange(selectedRange)
            }
            
            if parent.text != textView.string {
                parent.text = textView.string
            }
            isUpdating = false
            
            updateSelectedCommand(textView)
            
            // Autocomplete if user is typing forward
            if !isDeleting {
                triggerAutocomplete(textView)
            }
        }
        
        private func triggerAutocomplete(_ textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.length == 0 && selectedRange.location > 0 else { return }
            
            let nsString = textView.string as NSString
            let char = nsString.substring(with: NSRange(location: selectedRange.location - 1, length: 1))
            
            // Only trigger autocomplete when typing letters
            guard CharacterSet.letters.contains(UnicodeScalar(char) ?? UnicodeScalar(0)) else { return }
            
            // Trigger for both command-name position AND argument position.
            // We used to skip if there was a space before the partial word — now we allow it
            // so argument token completions (EX, NX, GT, …) pop up too.
            DispatchQueue.main.async {
                if textView.window?.firstResponder == textView {
                    textView.complete(nil)
                }
            }
        }
        
        // Autocomplete list completions
        func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let nsString = textView.string as NSString
            let partialWord = nsString.substring(with: charRange).lowercased()
            guard !partialWord.isEmpty else { return [] }
            
            // Determine the position context: are we at the command-name position or an argument position?
            let cursorLocation = charRange.location
            let lineRange = nsString.lineRange(for: NSRange(location: cursorLocation, length: 0))
            let linePrefix = nsString.substring(with: NSRange(location: lineRange.location, length: cursorLocation - lineRange.location))
            let trimmedPrefix = linePrefix.trimmingCharacters(in: .whitespaces)
            
            // ── Argument mode: there is content (command + at least one space) before the partial word ──
            if trimmedPrefix.contains(" ") || trimmedPrefix.contains("\t") {
                // Extract the command name (first token on the line)
                let lineTokens = trimmedPrefix
                    .trimmingCharacters(in: .init(charactersIn: "# \t"))
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                guard let commandName = lineTokens.first else { return [] }
                
                // Already-typed arguments on this line (excluding partial word)
                let typedArgs = Set(lineTokens.dropFirst().map { $0.uppercased() })
                
                // Get argument token completions from COMMAND DOCS cache
                let tokens = parent.argCompletions(commandName.lowercased())
                let matches = tokens
                    .filter { $0.lowercased().hasPrefix(partialWord) }
                    .filter { !typedArgs.contains($0) }  // don't re-suggest already-typed tokens
                    .sorted()
                
                if !matches.isEmpty {
                    index?.pointee = -1  // no pre-selection
                    return matches
                }
                return []
            }
            
            // ── Command-name mode: partial word is the first token on the line ──
            let commandSet = dynamicCommandSet ?? RedisHighlighter.redisCommands
            let matches = commandSet.filter { $0.hasPrefix(partialWord) }.sorted()
            if !matches.isEmpty {
                // Do not pre-select any item — let user manually pick
                index?.pointee = -1
                return matches
            }
            return []
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateSelectedCommand(textView)
        }
        
        func updateSelectedCommand(_ textView: NSTextView) {
            let string = textView.string
            let selectedRange = textView.selectedRange()
            let commandToExecute: String
            
            if selectedRange.length > 0 {
                commandToExecute = (string as NSString).substring(with: selectedRange)
            } else {
                let nsString = string as NSString
                let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
                commandToExecute = nsString.substring(with: lineRange)
            }
            
            if parent.selectedCommand != commandToExecute {
                parent.selectedCommand = commandToExecute
            }
        }
    }
}

class CommandQueryInternalTextView: NSTextView {
    var onExecute: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags == .command && (event.keyCode == 36 || event.keyCode == 76) {
            onExecute?()
            return
        }
        super.keyDown(with: event)
    }
    
    // Allow Esc to cancel autocomplete popup
    override func cancelOperation(_ sender: Any?) {
        // If the completion popup is visible, dismiss it by calling complete with a non-nil sender
        // which cancels the current completion session
        if NSApp.keyWindow?.firstResponder == self {
            // Dismiss completion list if shown
            let event = NSApp.currentEvent
            if event?.keyCode == 53 { // Esc key
                self.complete(self) // calling with non-nil cancels completion
                return
            }
        }
        super.cancelOperation(sender)
    }
}
