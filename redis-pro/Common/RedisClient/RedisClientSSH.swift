//
//  RedisClientSSH.swift
//  redis-pro
//
//  Created by chengpan on 2022/8/6.
//

import Foundation
import NIO
import NIOSSH
import Logging

// MARK: - SSH Support
extension RedisClient {
    
    func initSSHClient() async throws -> HiredisStandaloneClient {
        let bindHost = "127.0.0.1"
        
        let sshTunnel = SSHTunnel(
            sshHost: self.redisModel.sshHost,
            sshPort: self.redisModel.sshPort,
            user: self.redisModel.sshUser,
            pass: self.redisModel.sshPass,
            targetHost: self.redisModel.host,
            targetPort: self.redisModel.port
        )
        let localChannel = try await sshTunnel.openSSHTunnel()
        
        let localBindPort: Int = localChannel.localAddress?.port ?? 0
        self.sshLocalChannel = localChannel
        self.sshTunnel = sshTunnel
        
        let client = HiredisStandaloneClient(
            host: bindHost,
            port: localBindPort,
            username: redisModel.username,
            password: redisModel.password,
            database: redisModel.database
        )
        
        self.hiredisClient = client
        return client
    }
    
    // Close SSH tunnel
    func closeSSH() {
        self.sshTunnel?.close()
        self.sshTunnel = nil
        self.sshLocalChannel?.close(mode: .all)
        self.sshChannel?.close(mode: .all)
        self.sshLocalChannel = nil
        self.sshChannel = nil
    }
}
