//
//  LoginStore.swift
//  redis-pro
//
//  Created by chengpan on 2022/5/1.
//  Migrated to MVVM (Swift 6)
//

import Logging
import Foundation
import Observation

private let logger = Logger(label: "login-store")

@MainActor
@Observable
final class LoginViewModel {
    var id: String = ""
    var name: String = ""
    var host: String = "127.0.0.1"
    var port: Int = 6379
    var database: Int = 0
    var username: String = ""
    var password: String = ""
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

    var pingR: String = ""
    var loading: Bool = false

    var height: CGFloat {
        switch connectionType {
        case RedisConnectionTypeEnum.SSH.rawValue: return 560
        case RedisConnectionTypeEnum.SENTINEL.rawValue: return 500
        case RedisConnectionTypeEnum.CLUSTER.rawValue: return 450
        default: return 420
        }
    }

    // Callbacks replacing TCA action propagation
    var onConnect: (() -> Void)?
    var onSave: (() -> Void)?

    var redisModel: RedisModel {
        get {
            var m = RedisModel(name: name)
            m.id = id
            m.host = host
            m.port = port
            m.database = database
            m.username = username
            m.password = password
            m.connectionType = connectionType
            m.sshHost = sshHost
            m.sshPort = sshPort
            m.sshUser = sshUser
            m.sshPass = sshPass
            m.sentinelMasterName = sentinelMasterName
            m.sentinelNodes = sentinelNodes
            m.sentinelPassword = sentinelPassword
            m.clusterNodes = clusterNodes
            return m
        }
        set(n) {
            id = n.id
            name = n.name
            host = n.host
            port = n.port
            database = n.database
            username = n.username
            password = n.password
            connectionType = n.connectionType
            sshHost = n.sshHost
            sshPort = n.sshPort
            sshUser = n.sshUser
            sshPass = n.sshPass
            sentinelMasterName = n.sentinelMasterName
            sentinelNodes = n.sentinelNodes
            sentinelPassword = n.sentinelPassword
            clusterNodes = n.clusterNodes
        }
    }

    private let redisInstance: RedisInstanceModel

    init(redisInstance: RedisInstanceModel) {
        self.redisInstance = redisInstance
        logger.info("LoginViewModel init ...")
    }

    func add() {
        id = UUID().uuidString
        save()
    }

    func save() {
        onSave?()
    }

    func testConnect() {
        logger.info("test connect to redis server, name: \(name), type: \(connectionType)")
        loading = true
        let model = redisModel
        Task {
            let r = await redisInstance.testConnect(model)
            pingR = r ? "Connect succeeded!" : "Connect failed! "
            loading = false
        }
    }

    func connect() {
        onConnect?()
    }
}
