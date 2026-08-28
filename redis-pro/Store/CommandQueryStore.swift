//
//  CommandQueryStore.swift
//  redis-pro
//
//  Created by Antigravity on 2026-06-02.
//

import Foundation
import Observation
import Logging

private let logger = Logger(label: "command-query-store")

@MainActor
@Observable
final class CommandQueryViewModel {
    var queryText: String = ""
    var selectedCommand: String = ""
    var outputText: String = ""
    var isExecuting: Bool = false
    var showDocsSidebar: Bool = true
    var commandDoc: CommandDoc? = nil
    var isLoadingDoc: Bool = false
    var docError: String? = nil
    private var lastFetchedDocCommand: String = ""
    /// Command names fetched from COMMAND LIST — drives autocomplete + highlighting.
    var commandNames: [String] = []
    var commandDocsCache: [String: CommandDoc] = [:]
    private var isCommandListLoaded: Bool = false
    
    /// The Redis command name currently under cursor/selection, used to load docs.
    var currentDocCommand: String {
        let trimmed = selectedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Take the first token (the command name)
        return trimmed.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
    }
    
    private let redisInstance: RedisInstanceModel
    
    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        self.queryText = RedisDefaults.getCommandQueryText()
    }
    
    func executeCommand(_ commandString: String) {
        let trimmed = commandString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        guard let parsed = RedisCommandParser.parse(trimmed) else {
            self.outputText += "\n> \(trimmed)\nError: Could not parse command. Make sure quotes are balanced.\n"
            return
        }
        
        isExecuting = true
        
        // Save the full editor content to defaults
        RedisDefaults.saveCommandQueryText(queryText)
        
        Task {
            do {
                let client = redisInstance.getClient()
                
                // execute using raw command
                let responseReply = try await client.execute(command: parsed.command, args: parsed.args)
                
                let formatted = formatReply(responseReply)
                self.outputText += "\n> \(trimmed)\n\(formatted)\n"
            } catch {
                self.outputText += "\n> \(trimmed)\nError: \(error.localizedDescription)\n"
            }
            isExecuting = false
        }
    }
    
    func clearOutput() {
        self.outputText = ""
    }
    
    private func formatReply(_ reply: RedisReply) -> String {
        switch reply {
        case .string(let s):
            return s
        case .status(let s):
            return s
        case .verbatim(let s):
            return s
        case .integer(let i):
            return "(integer) \(i)"
        case .double(let d):
            return "\(d)"
        case .boolean(let b):
            return b ? "true" : "false"
        case .nil:
            return "(nil)"
        case .error(let err):
            return "(error) \(err)"
        case .array(let arr), .set(let arr), .push(let arr):
            if arr.isEmpty {
                return "(empty array)"
            }
            return arr.enumerated().map { index, item in
                let formattedItem = formatReply(item)
                let indented = formattedItem.components(separatedBy: .newlines).map { "  " + $0 }.joined(separator: "\n")
                return "\(index + 1))\n\(indented)"
            }.joined(separator: "\n")
        case .map(let dict):
            if dict.isEmpty {
                return "(empty map)"
            }
            return dict.map { entry in
                let keyStr = formatReply(entry.key)
                let valStr = formatReply(entry.value)
                return "\(keyStr) => \(valStr)"
            }.joined(separator: "\n")
        }
    }
    
    // MARK: - Command Docs
    
    /// Fetch all command names from COMMAND LIST (once per session) for autocomplete.
    /// Returns all keyword tokens (pure-token arguments) for a command, derived from cached COMMAND DOCS.
    /// These are the completable argument keywords like EX, NX, GT, LIMIT, WITHSCORES, etc.
    func argCompletions(for command: String) -> [String] {
        let cmd = command.lowercased().trimmingCharacters(in: .whitespaces)
        guard let doc = commandDocsCache[cmd], !doc.arguments.isEmpty else { return [] }
        var tokens: [String] = []
        collectTokens(from: doc.arguments, into: &tokens)
        return tokens
    }
    
    private func collectTokens(from args: [CommandArgDoc], into result: inout [String]) {
        for arg in args {
            if arg.type != "oneof", let tok = arg.token, !tok.isEmpty {
                result.append(tok.uppercased())
            }
            if !arg.arguments.isEmpty {
                collectTokens(from: arg.arguments, into: &result)
            }
        }
    }
    
    /// Fetch all command names from COMMAND LIST (once per session) for autocomplete.
    func fetchCommandList() {
        guard !isCommandListLoaded else { return }
        isCommandListLoaded = true
        Task {
            do {
                let client = redisInstance.getClient()
                let response = try await client.execute(command: "COMMAND", args: ["LIST"])
                if let arr = response.arrayValue {
                    let names = arr
                        .compactMap { $0.stringValue }
                        .filter { !$0.isEmpty }
                        .sorted()
                    self.commandNames = names
                    logger.info("COMMAND LIST loaded \(names.count) commands")
                }
            } catch {
                logger.warning("COMMAND LIST failed: \(error) — falling back to built-in list")
            }
        }
    }
    
    func fetchCommandDocs(_ command: String) {
        let cmd = command.lowercased().trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else {
            commandDoc = nil
            docError = nil
            lastFetchedDocCommand = ""
            return
        }
        guard cmd != lastFetchedDocCommand else { return }
        lastFetchedDocCommand = cmd
        
        // Return cached doc immediately (no network hit)
        if let cached = commandDocsCache[cmd] {
            self.commandDoc = cached
            self.isLoadingDoc = false
            self.docError = nil
            return
        }
        isLoadingDoc = true
        docError = nil
        commandDoc = nil
        
        Task {
            do {
                let client = redisInstance.getClient()
                let response = try await client.execute(command: "COMMAND", args: ["DOCS", cmd])
                if let doc = parseCommandDoc(cmd, from: response) {
                    self.commandDocsCache[cmd] = doc   // cache for the session
                    self.commandDoc = doc
                } else {
                    self.docError = "No documentation found for \"\(cmd.uppercased())\""
                }
            } catch {
                self.docError = "Failed to load docs: \(error.localizedDescription)"
            }
            self.isLoadingDoc = false
        }
    }
    
    private func replyToMap(_ reply: RedisReply) -> [String: RedisReply] {
        var result: [String: RedisReply] = [:]
        if let map = reply.mapValue {
            for (k, v) in map {
                if let keyStr = k.stringValue {
                    result[keyStr] = v
                }
            }
        } else if let arr = reply.arrayValue {
            var i = 0
            while i + 1 < arr.count {
                if let keyStr = arr[i].stringValue {
                    result[keyStr] = arr[i + 1]
                }
                i += 2
            }
        }
        return result
    }
    
    private func parseCommandDoc(_ cmd: String, from reply: RedisReply) -> CommandDoc? {
        let outer = replyToMap(reply)
        guard let docReply = outer[cmd] else { return nil }
        let docMap = replyToMap(docReply)
        guard !docMap.isEmpty else { return nil }
        
        let summary    = docMap["summary"]?.stringValue ?? ""
        let since      = docMap["since"]?.stringValue ?? ""
        let group      = docMap["group"]?.stringValue ?? ""
        let complexity = docMap["complexity"]?.stringValue ?? ""
        
        var arguments: [CommandArgDoc] = []
        if let argsReply = docMap["arguments"], let argsArr = argsReply.arrayValue {
            arguments = argsArr.compactMap { parseArgDoc($0) }
        }
        
        var docFlags: [String] = []
        if let flagsReply = docMap["doc_flags"], let flagsArr = flagsReply.arrayValue {
            docFlags = flagsArr.compactMap { $0.stringValue }
        }
        
        return CommandDoc(name: cmd, summary: summary, since: since,
                          group: group, complexity: complexity,
                          arguments: arguments, docFlags: docFlags)
    }
    
    private func parseArgDoc(_ reply: RedisReply) -> CommandArgDoc? {
        let map = replyToMap(reply)
        let name        = map["name"]?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        let displayText = map["display_text"]?.stringValue ?? name
        let type        = map["type"]?.stringValue ?? ""
        let argToken    = map["token"]?.stringValue
        
        var flags: [String] = []
        if let flagsReply = map["flags"], let flagsArr = flagsReply.arrayValue {
            flags = flagsArr.compactMap { $0.stringValue }
        }
        
        var nestedArgs: [CommandArgDoc] = []
        if let nestedReply = map["arguments"], let nestedArr = nestedReply.arrayValue {
            nestedArgs = nestedArr.compactMap { parseArgDoc($0) }
        }
        
        return CommandArgDoc(name: name, displayText: displayText, type: type,
                             flags: flags, token: argToken, arguments: nestedArgs)
    }
}

struct RedisCommandParser {
    static func parse(_ commandLine: String) -> (command: String, args: [String])? {
        let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        var args: [String] = []
        var currentToken = ""
        var inDoubleQuotes = false
        var inSingleQuotes = false
        var isEscaped = false
        
        for char in trimmed {
            if isEscaped {
                currentToken.append(char)
                isEscaped = false
                continue
            }
            
            if char == "\\" {
                isEscaped = true
                continue
            }
            
            if char == "\"" && !inSingleQuotes {
                inDoubleQuotes.toggle()
                continue
            }
            
            if char == "'" && !inDoubleQuotes {
                inSingleQuotes.toggle()
                continue
            }
            
            if char.isWhitespace && !inDoubleQuotes && !inSingleQuotes {
                if !currentToken.isEmpty {
                    args.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            args.append(currentToken)
        }
        
        guard !args.isEmpty else { return nil }
        let cmd = args.removeFirst()
        return (cmd, args)
    }
}

// MARK: - Command Doc Models

struct CommandDoc {
    let name: String
    let summary: String
    let since: String
    let group: String
    let complexity: String
    let arguments: [CommandArgDoc]
    let docFlags: [String]
}

struct CommandArgDoc: Identifiable {
    let id = UUID()
    let name: String
    let displayText: String
    let type: String
    let flags: [String]
    let token: String?
    let arguments: [CommandArgDoc]
}
