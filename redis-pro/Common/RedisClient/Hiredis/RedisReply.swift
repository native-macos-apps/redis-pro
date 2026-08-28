//
//  RedisReply.swift
//  redis-pro
//
//  Created for hiredis integration.
//

import Foundation
#if canImport(CHiredis)
import CHiredis
#endif

/// Complete representation of Redis RESP replies parsed by hiredis.
public enum RedisReply: Sendable, Equatable, Hashable, CustomStringConvertible {
    case string(String)
    case status(String)
    case integer(Int64)
    case double(Double)
    case boolean(Bool)
    case `nil`
    case array([RedisReply])
    case map([RedisReply: RedisReply])
    case set([RedisReply])
    case error(String)
    case push([RedisReply])
    case verbatim(String)

    public var description: String {
        switch self {
        case .string(let s): return s
        case .status(let s): return s
        case .integer(let i): return String(i)
        case .double(let d): return String(d)
        case .boolean(let b): return b ? "true" : "false"
        case .nil: return "(nil)"
        case .array(let arr): return "[\(arr.map { $0.description }.joined(separator: ", "))]"
        case .map(let dict): return "{\(dict.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
        case .set(let set): return "Set(\(set.map { $0.description }.joined(separator: ", ")))"
        case .error(let e): return "ERR \(e)"
        case .push(let arr): return "PUSH(\(arr.map { $0.description }.joined(separator: ", ")))"
        case .verbatim(let s): return s
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let s), .status(let s), .verbatim(let s):
            return s
        case .integer(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .boolean(let b):
            return b ? "true" : "false"
        default:
            return nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .integer(let i):
            return Int(i)
        case .string(let s), .status(let s):
            return Int(s)
        case .double(let d):
            return Int(d)
        case .boolean(let b):
            return b ? 1 : 0
        default:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let d):
            return d
        case .integer(let i):
            return Double(i)
        case .string(let s), .status(let s):
            return Double(s)
        default:
            return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .boolean(let b):
            return b
        case .integer(let i):
            return i != 0
        case .string(let s), .status(let s):
            return s.lowercased() == "true" || s == "1" || s.uppercased() == "OK"
        default:
            return nil
        }
    }

    public var isNil: Bool {
        if case .nil = self { return true }
        return false
    }

    public var isOK: Bool {
        switch self {
        case .status(let s):
            return s.uppercased() == "OK"
        case .string(let s):
            return s.uppercased() == "OK"
        default:
            return false
        }
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }

    public var arrayValue: [RedisReply]? {
        switch self {
        case .array(let arr), .set(let arr), .push(let arr):
            return arr
        default:
            return nil
        }
    }

    public var mapValue: [RedisReply: RedisReply]? {
        if case .map(let dict) = self { return dict }
        return nil
    }

    public var stringArray: [String] {
        guard let arr = arrayValue else { return [] }
        return arr.compactMap { $0.stringValue }
    }

    // MARK: - From hiredis C Struct
    public static func from(cReply: UnsafeMutablePointer<redisReply>?) -> RedisReply {
        guard let reply = cReply else { return .nil }
        let r = reply.pointee

        switch Int32(r.type) {
        case REDIS_REPLY_STRING:
            if let str = r.str {
                let data = Data(bytes: str, count: Int(r.len))
                let s = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                return .string(s)
            }
            return .string("")

        case REDIS_REPLY_STATUS:
            if let str = r.str {
                let s = String(cString: str)
                return .status(s)
            }
            return .status("")

        case REDIS_REPLY_INTEGER:
            return .integer(r.integer)

        case REDIS_REPLY_NIL:
            return .nil

        case REDIS_REPLY_ERROR:
            if let str = r.str {
                return .error(String(cString: str))
            }
            return .error("Unknown Redis Error")

        case REDIS_REPLY_ARRAY:
            var elements: [RedisReply] = []
            if let elemPtr = r.element, r.elements > 0 {
                for i in 0..<r.elements {
                    if let elem = elemPtr[i] {
                        elements.append(RedisReply.from(cReply: elem))
                    } else {
                        elements.append(.nil)
                    }
                }
            }
            return .array(elements)

        case REDIS_REPLY_MAP:
            var map: [RedisReply: RedisReply] = [:]
            if let elemPtr = r.element, r.elements > 0 {
                let count = Int(r.elements)
                var i = 0
                while i + 1 < count {
                    if let kPtr = elemPtr[i], let vPtr = elemPtr[i + 1] {
                        let k = RedisReply.from(cReply: kPtr)
                        let v = RedisReply.from(cReply: vPtr)
                        map[k] = v
                    }
                    i += 2
                }
            }
            return .map(map)

        case REDIS_REPLY_SET:
            var elements: [RedisReply] = []
            if let elemPtr = r.element, r.elements > 0 {
                for i in 0..<r.elements {
                    if let elem = elemPtr[i] {
                        elements.append(RedisReply.from(cReply: elem))
                    }
                }
            }
            return .set(elements)

        case REDIS_REPLY_DOUBLE:
            return .double(r.dval)

        case REDIS_REPLY_BOOL:
            return .boolean(r.integer != 0)

        case REDIS_REPLY_VERB:
            if let str = r.str {
                let data = Data(bytes: str, count: Int(r.len))
                let s = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                return .verbatim(s)
            }
            return .verbatim("")

        case REDIS_REPLY_BIGNUM:
            if let str = r.str {
                let data = Data(bytes: str, count: Int(r.len))
                let s = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                return .string(s)
            }
            return .string("")

        case REDIS_REPLY_PUSH:
            var elements: [RedisReply] = []
            if let elemPtr = r.element, r.elements > 0 {
                for i in 0..<r.elements {
                    if let elem = elemPtr[i] {
                        elements.append(RedisReply.from(cReply: elem))
                    }
                }
            }
            return .push(elements)

        default:
            return .nil
        }
    }
}

// MARK: - RedisValueConvertible
public protocol RedisValueConvertible {
    init(fromRedisReply reply: RedisReply)
}

extension String: RedisValueConvertible {
    public init(fromRedisReply reply: RedisReply) {
        self = reply.stringValue ?? ""
    }
}

extension Int: RedisValueConvertible {
    public init(fromRedisReply reply: RedisReply) {
        self = reply.intValue ?? 0
    }
}

extension Double: RedisValueConvertible {
    public init(fromRedisReply reply: RedisReply) {
        self = reply.doubleValue ?? 0.0
    }
}

extension Bool: RedisValueConvertible {
    public init(fromRedisReply reply: RedisReply) {
        self = reply.boolValue ?? false
    }
}

extension RedisReply: RedisValueConvertible {
    public init(fromRedisReply reply: RedisReply) {
        self = reply
    }
}
