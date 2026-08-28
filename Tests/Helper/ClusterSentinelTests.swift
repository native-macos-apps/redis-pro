//
//  ClusterSentinelTests.swift
//  Tests
//
//  Created for testing Redis Cluster CRC16 slot hashing and RedisReply.
//

@testable import redis_pro
import XCTest

final class ClusterSentinelTests: XCTestCase {
    
    func testCRC16SlotCalculations() {
        // Standard Redis Cluster test cases
        let slot1 = CRC16.slot(for: "123456789")
        XCTAssertEqual(slot1, 0x31C3 & 16383)
        
        // Hash tag extraction
        XCTAssertEqual(CRC16.extractHashTag(from: "user{1000}:profile"), "1000")
        XCTAssertEqual(CRC16.extractHashTag(from: "user{1000}:orders"), "1000")
        
        // Keys with same hash tag must map to the same slot
        let slotUser1 = CRC16.slot(for: "user{1000}:profile")
        let slotUser2 = CRC16.slot(for: "user{1000}:orders")
        XCTAssertEqual(slotUser1, slotUser2)
        
        // Empty hash tag "{}" hashes full key
        XCTAssertEqual(CRC16.extractHashTag(from: "user{}:profile"), "user{}:profile")
        
        // Slot must always be in 0...16383 range
        for key in ["alpha", "beta", "gamma", "foo", "bar", "{tag}123", "a{b}c"] {
            let slot = CRC16.slot(for: key)
            XCTAssertTrue(slot >= 0 && slot < 16384, "Slot \(slot) out of range for key \(key)")
        }
    }
    
    func testRedisReplyConversions() {
        let stringReply = RedisReply.string("Hello Redis")
        XCTAssertEqual(stringReply.stringValue, "Hello Redis")
        XCTAssertEqual(String(fromRedisReply: stringReply), "Hello Redis")
        
        let statusReply = RedisReply.status("OK")
        XCTAssertTrue(statusReply.isOK)
        XCTAssertEqual(statusReply.stringValue, "OK")
        
        let intReply = RedisReply.integer(42)
        XCTAssertEqual(intReply.intValue, 42)
        XCTAssertEqual(Int(fromRedisReply: intReply), 42)
        XCTAssertEqual(Double(fromRedisReply: intReply), 42.0)
        
        let doubleReply = RedisReply.double(3.14159)
        XCTAssertEqual(doubleReply.doubleValue, 3.14159)
        
        let boolReply = RedisReply.boolean(true)
        XCTAssertEqual(boolReply.boolValue, true)
        
        let nilReply = RedisReply.nil
        XCTAssertTrue(nilReply.isNil)
        
        let arrayReply = RedisReply.array([.string("a"), .string("b"), .string("c")])
        XCTAssertEqual(arrayReply.stringArray, ["a", "b", "c"])
        
        let errorReply = RedisReply.error("MOVED 123 127.0.0.1:7001")
        XCTAssertTrue(errorReply.isError)
        XCTAssertEqual(errorReply.errorMessage, "MOVED 123 127.0.0.1:7001")
    }
    
    func testSentinelClientNodeParsing() {
        let sentinelClient = HiredisSentinelClient(
            masterName: "mymaster",
            sentinelNodes: "127.0.0.1:26379, 127.0.0.1:26380; 10.0.0.1:26381"
        )
        
        XCTAssertEqual(sentinelClient.masterName, "mymaster")
        XCTAssertEqual(sentinelClient.sentinelAddresses.count, 3)
        XCTAssertEqual(sentinelClient.sentinelAddresses[0].host, "127.0.0.1")
        XCTAssertEqual(sentinelClient.sentinelAddresses[0].port, 26379)
        XCTAssertEqual(sentinelClient.sentinelAddresses[1].host, "127.0.0.1")
        XCTAssertEqual(sentinelClient.sentinelAddresses[1].port, 26380)
        XCTAssertEqual(sentinelClient.sentinelAddresses[2].host, "10.0.0.1")
        XCTAssertEqual(sentinelClient.sentinelAddresses[2].port, 26381)
    }
    
    func testClusterClientSeedParsing() {
        let clusterClient = HiredisClusterClient(
            clusterNodes: "127.0.0.1:7000, 127.0.0.1:7001, 127.0.0.1:7002"
        )
        
        XCTAssertEqual(clusterClient.seedAddresses.count, 3)
        XCTAssertEqual(clusterClient.seedAddresses[0].port, 7000)
        XCTAssertEqual(clusterClient.seedAddresses[1].port, 7001)
        XCTAssertEqual(clusterClient.seedAddresses[2].port, 7002)
    }
}
