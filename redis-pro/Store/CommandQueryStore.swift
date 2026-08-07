//
//  CommandQueryStore.swift
//  redis-pro
//
//  Created by Antigravity on 2026-06-02.
//

import Foundation
import Observation
import Logging
import Valkey

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
                let responseToken: RESPToken? = try await client.send(parsed.command, args: parsed.args)
                
                if let responseToken = responseToken {
                    let formatted = formatToken(responseToken)
                    self.outputText += "\n> \(trimmed)\n\(formatted)\n"
                } else {
                    self.outputText += "\n> \(trimmed)\n(nil)\n"
                }
            } catch {
                self.outputText += "\n> \(trimmed)\nError: \(error.localizedDescription)\n"
            }
            isExecuting = false
        }
    }
    
    func clearOutput() {
        self.outputText = ""
    }
    
    private func formatToken(_ token: RESPToken) -> String {
        switch token.value {
        case .simpleString(let buffer), .bulkString(let buffer):
            return String(buffer: buffer)
        case .number(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .boolean(let b):
            return b ? "true" : "false"
        case .null:
            return "(nil)"
        default:
            // Check for array response
            if let tokenArray = try? token.decode(as: RESPToken.Array.self) {
                let arr = Array(tokenArray)
                if arr.isEmpty {
                    return "(empty array)"
                }
                return arr.enumerated().map { index, item in
                    let formattedItem = formatToken(item)
                    let indented = formattedItem.components(separatedBy: .newlines).map { "  " + $0 }.joined(separator: "\n")
                    return "\(index + 1))\n\(indented)"
                }.joined(separator: "\n")
            }
            
            // Check for map response
            if let tokenMap = try? token.decode(as: RESPToken.Map.self) {
                let entries = Array(tokenMap)
                if entries.isEmpty {
                    return "(empty map)"
                }
                return entries.map { entry in
                    let keyStr = formatToken(entry.key)
                    let valStr = formatToken(entry.value)
                    return "\(keyStr) => \(valStr)"
                }.joined(separator: "\n")
            }
            
            return "\(token)"
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
            // Collect keyword tokens for autocomplete.
            // Rule: any arg that has a non-empty `token` field is a keyword the user types,
            // EXCEPT `oneof` which is just a grouping container with no own keyword.
            // This covers:
            //   pure-token      → NX, XX, GET, WITHCOORD, KEEPTTL …
            //   block + token   → FROMLONLAT, BYBOX, EX (as block), IFEQ …
            //   integer + token → EX seconds, RANK n, COUNT n, MAXLEN n …
            //   unix-time+token → EXAT, PXAT …
            //   string + token  → IFEQ ifeq-value …
            if arg.type != "oneof", let tok = arg.token, !tok.isEmpty {
                result.append(tok.uppercased())
            }
            // Always recurse into children (oneof / block contain their own keyword args)
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
                let response: RESPToken? = try await client.send("COMMAND", args: ["LIST"])
                if let response, let arr = try? response.decode(as: RESPToken.Array.self) {
                    let names = Array(arr)
                        .map { respTokenToString($0) }
                        .filter { !$0.isEmpty }
                        .sorted()
                    self.commandNames = names
                    logger.info("COMMAND LIST loaded \(names.count) commands")
                }
            } catch {
                logger.warning("COMMAND LIST failed: \(error) — falling back to built-in list")
                // commandNames stays empty; highlighter/autocomplete use static fallback
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
                let response: RESPToken? = try await client.send("COMMAND", args: ["DOCS", cmd])
                if let response, let doc = parseCommandDoc(cmd, from: response) {
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
    
    private func respTokenToString(_ token: RESPToken) -> String {
        switch token.value {
        case .simpleString(let buf), .bulkString(let buf): return String(buffer: buf)
        case .number(let i):  return String(i)
        case .double(let d):  return String(d)
        case .boolean(let b): return b ? "true" : "false"
        case .null:           return ""
        default:              return ""
        }
    }
    
    private func respTokenToMap(_ token: RESPToken) -> [String: RESPToken] {
        var result: [String: RESPToken] = [:]
        if let map = try? token.decode(as: RESPToken.Map.self) {
            for entry in map {
                result[respTokenToString(entry.key)] = entry.value
            }
        } else if let arr = try? token.decode(as: RESPToken.Array.self) {
            var items = Array(arr)
            while items.count >= 2 {
                result[respTokenToString(items[0])] = items[1]
                items.removeFirst(2)
            }
        }
        return result
    }
    
    private func parseCommandDoc(_ cmd: String, from token: RESPToken) -> CommandDoc? {
        let outer = respTokenToMap(token)
        guard let docToken = outer[cmd] else { return nil }
        let docMap = respTokenToMap(docToken)
        guard !docMap.isEmpty else { return nil }
        
        let summary    = docMap["summary"].map    { respTokenToString($0) } ?? ""
        let since      = docMap["since"].map      { respTokenToString($0) } ?? ""
        let group      = docMap["group"].map      { respTokenToString($0) } ?? ""
        let complexity = docMap["complexity"].map { respTokenToString($0) } ?? ""
        
        var arguments: [CommandArgDoc] = []
        if let argsToken = docMap["arguments"],
           let argsArr = try? argsToken.decode(as: RESPToken.Array.self) {
            arguments = Array(argsArr).compactMap { parseArgDoc($0) }
        }
        
        var docFlags: [String] = []
        if let flagsToken = docMap["doc_flags"],
           let flagsArr = try? flagsToken.decode(as: RESPToken.Array.self) {
            docFlags = Array(flagsArr).map { respTokenToString($0) }
        }
        
        return CommandDoc(name: cmd, summary: summary, since: since,
                         group: group, complexity: complexity,
                         arguments: arguments, docFlags: docFlags)
    }
    
    private func parseArgDoc(_ token: RESPToken) -> CommandArgDoc? {
        let map = respTokenToMap(token)
        let name        = map["name"].map        { respTokenToString($0) } ?? ""
        guard !name.isEmpty else { return nil }
        let displayText = map["display_text"].map { respTokenToString($0) } ?? name
        let type        = map["type"].map        { respTokenToString($0) } ?? ""
        let argToken    = map["token"].map       { respTokenToString($0) }
        
        var flags: [String] = []
        if let flagsToken = map["flags"],
           let flagsArr = try? flagsToken.decode(as: RESPToken.Array.self) {
            flags = Array(flagsArr).map { respTokenToString($0) }
        }
        
        var nestedArgs: [CommandArgDoc] = []
        if let nestedToken = map["arguments"],
           let nestedArr = try? nestedToken.decode(as: RESPToken.Array.self) {
            nestedArgs = Array(nestedArr).compactMap { parseArgDoc($0) }
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
