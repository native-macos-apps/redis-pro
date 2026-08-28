//
//  RedisConnectionType.swift
//  redis-pro
//
//  Created by chengpan on 2021/8/6.
//

import Foundation

enum RedisConnectionTypeEnum: String, CaseIterable, Identifiable {
    case TCP = "tcp"
    case SSH = "ssh"
    case SENTINEL = "sentinel"
    case CLUSTER = "cluster"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .TCP: return "Standalone"
        case .SSH: return "SSH Tunnel"
        case .SENTINEL: return "Sentinel"
        case .CLUSTER: return "Cluster"
        }
    }
}
