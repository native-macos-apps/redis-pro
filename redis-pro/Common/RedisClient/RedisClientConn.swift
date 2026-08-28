//
//  RedisClientConn.swift
//  redis-pro
//
//  Created by chengpan on 2023/7/23.
//

import Foundation
import NIO

// MARK: - Connection Operations
extension RedisClient {
    
    /*
     * Initialize redis connection
     */
    func initConnection() async throws -> Bool {
        begin()
        defer {
            complete()
        }
        
        do {
            let _ = try await getClient()
            return true
        } catch {
            handleError(error)
        }
        
        return false
    }
    
    /// Test redis connection
    func testConn() async throws -> Bool {
        begin()
        defer {
            complete()
        }
        
        do {
            let client = try await initClient()
            let pong = try await client.ping()
            self.close()
            return pong
        } catch {
            Task { @MainActor in Messages.show(error) }
            return false
        }
    }
    
    func refreshConn() async {
        self.close()
        let _ = try? await self.getClient()
    }
    
    func getConn() async throws -> HiredisClientProtocol? {
        return try await getClient()
    }
}
