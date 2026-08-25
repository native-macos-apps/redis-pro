//
//  RedisModel.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/1/29.
//

import Foundation
import SwiftUI

struct RedisModel: Identifiable, Sendable, Hashable {
    var id: String = UUID().uuidString
    var name: String = "New Favorite"
    var host: String = "127.0.0.1"
    var port: Int = 6379
    var database: Int = 0
    var username: String = ""
    var password: String = ""
    var isFavorite: Bool = false
    var ping: Bool = false
    var connectionType: String = "tcp"
    
    // SSH
    var sshHost: String = ""
    var sshPort: Int = 22
    var sshUser: String = ""
    var sshPass: String = ""

    // Sentinel
    var sentinelMasterName: String = "mymaster"
    var sentinelNodes: String = "127.0.0.1:26379"
    var sentinelPassword: String = ""

    // Cluster
    var clusterNodes: String = "127.0.0.1:6379"
    
    var image: Image = Image("icon-redis")
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "host": host,
            "port": port,
            "database": database,
            "username": username,
            "password": password,
            "connectionType": connectionType,
            "sshHost": sshHost,
            "sshPort": sshPort,
            "sshUser": sshUser,
            "sshPass": sshPass,
            "sentinelMasterName": sentinelMasterName,
            "sentinelNodes": sentinelNodes,
            "sentinelPassword": sentinelPassword,
            "clusterNodes": clusterNodes,
        ]
    }
    
    // MARK: - Initializers
    
    init() {}
    
    init(name: String) {
        self.init()
        self.name = name
    }
    
    init(password: String) {
        self.init()
        self.password = password
    }
    
    init(host: String = "localhost", port: Int = 6379, username: String? = nil, password: String? = nil) {
        self.init()
        self.host = host
        self.port = port
        self.username = username ?? ""
        self.password = password ?? ""
    }
    
    init(dictionary: [String: Any]) {
        self.init()
        
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.name = dictionary["name"] as? String ?? "New Favorite"
        self.host = dictionary["host"] as? String ?? "127.0.0.1"
        self.port = dictionary["port"] as? Int ?? 6379
        self.database = dictionary["database"] as? Int ?? 0
        self.username = dictionary["username"] as? String ?? ""
        self.password = dictionary["password"] as? String ?? ""
        
        let connectionType: String = dictionary["connectionType"] as? String ?? RedisConnectionTypeEnum.TCP.rawValue
        self.connectionType = connectionType
        
        if connectionType == RedisConnectionTypeEnum.SSH.rawValue {
            self.sshHost = dictionary["sshHost"] as? String ?? ""
            self.sshPort = dictionary["sshPort"] as? Int ?? 22
            self.sshUser = dictionary["sshUser"] as? String ?? ""
            self.sshPass = dictionary["sshPass"] as? String ?? ""
        }

        self.sentinelMasterName = dictionary["sentinelMasterName"] as? String ?? "mymaster"
        self.sentinelNodes = dictionary["sentinelNodes"] as? String ?? "127.0.0.1:26379"
        self.sentinelPassword = dictionary["sentinelPassword"] as? String ?? ""
        self.clusterNodes = dictionary["clusterNodes"] as? String ?? "127.0.0.1:6379"
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RedisModel, rhs: RedisModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(database)
        hasher.combine(username)
        hasher.combine(password)
        hasher.combine(isFavorite)
        hasher.combine(ping)
        hasher.combine(connectionType)
        hasher.combine(sshHost)
        hasher.combine(sshPort)
        hasher.combine(sshUser)
        hasher.combine(sshPass)
        hasher.combine(sentinelMasterName)
        hasher.combine(sentinelNodes)
        hasher.combine(sentinelPassword)
        hasher.combine(clusterNodes)
    }
}
