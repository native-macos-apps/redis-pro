# Redis Pro

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-orange.svg?style=flat)
[![release](https://img.shields.io/github/v/release/native-macos-apps/redis-pro?include_prereleases)](https://github.com/native-macos-apps/redis-pro/releases)
![platforms](https://img.shields.io/badge/Platforms-macOS-orange.svg?style=flat)

## Intro
* **Redis Pro** is a modern, lightweight, and blazing-fast Redis management client designed natively for macOS.
* Crafted with a premium **Liquid Glass** aesthetic (glassmorphism), the user interface provides a visually stunning, responsive, and tactile experience.
* Powered by native **hiredis (C/C++)** for 100% Redis compatibility and high throughput, paired with a modern **Swift 6 / async-await architecture**.

## Features
- [x] **Liquid Glass UI**: Stunning glassmorphism design optimized for macOS, supporting dynamic light and dark modes with a curated, premium color palette.
- [x] **Redis Cluster & Sentinel Support**: Native support for Redis Cluster (slot routing, MOVED/ASK redirect handling) and Redis Sentinel (automatic master discovery and failover).
- [x] **Hierarchical Key Navigation**: Native virtualized tree view for lightning-fast key scanning, filtering, and navigation.
- [x] **Geospatial (GEOPOS) Mapping**: Dedicated CoordinateBox components and visual modal for viewing latitude/longitude coordinates of Sorted Set (ZSet) members, complete with one-click copying.
- [x] **Lua Script Evaluation**: Execute Lua scripts directly inside the application, inspect results, and manage script cache (Flush, Eval).
- [x] **Secure SSH Tunneling**: Full support for secure remote database connections via built-in high-performance SSH tunnels.
- [x] **Redis 3.x to 8.x Support**: Native protocol compatibility powered by official `hiredis` C engine.
- [x] **Real-time Diagnostics**: Slow log analysis, system config editor, and live server info metric visualization.
- [x] **Client Management**: Real-time listing, monitoring, and dynamic termination of active client connections.
- [x] **Batch Operations**: Perform high-speed bulk deletions of keys matching specific patterns.

## Installation
* **Direct Download**: Download the latest DMG release from the [releases page](https://github.com/native-macos-apps/redis-pro/releases).

## Platform
* Supports macOS 15.0+ (Universal binary for Intel and Apple Silicon).

## Roadmap
- [x] SSH key-based (private key) authentication
- [x] Cluster & Sentinel support

## Dependencies
* [hiredis](https://github.com/redis/hiredis): Official minimalistic C client library for the Redis database.
* [swift-nio](https://github.com/apple/swift-nio): Event-driven asynchronous network application framework.
* [swift-nio-ssh](https://github.com/apple/swift-nio-ssh): Native, performant Swift SSH implementation.
* [swift-log](https://github.com/apple/swift-log): Swift standard logging API.
* [swift-tree-sitter](https://github.com/tree-sitter/swift-tree-sitter): Swift bindings for the Tree-sitter parsing library.
* [tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json): JSON grammar for Tree-sitter enabling high-performance syntax highlighting.

## Snapshot
login
<img width="1124" alt="0" src="https://user-images.githubusercontent.com/2920167/125376590-ec6fb500-e3bd-11eb-8f6b-140c32578e8c.png">

home
<img width="1124" alt="1" src="https://user-images.githubusercontent.com/2920167/125376643-0e693780-e3be-11eb-92fa-9c13dcc26f78.png">

setting
<img width="1128" alt="2" src="https://user-images.githubusercontent.com/2920167/125376658-15904580-e3be-11eb-94cf-8590a550ea1a.png">

Info
<img width="1124" alt="3" src="https://user-images.githubusercontent.com/2920167/125376733-39538b80-e3be-11eb-896d-72cacb469540.png">

Clients
<img width="1124" alt="4" src="https://user-images.githubusercontent.com/2920167/125376767-4a9c9800-e3be-11eb-84b3-33c2c1c846fc.png">


dark mode
<img width="1124" alt="5" src="https://user-images.githubusercontent.com/2920167/125376789-538d6980-e3be-11eb-9267-6a451597f983.png">
<img width="1124" alt="5" src="https://user-images.githubusercontent.com/2920167/125376778-4f614c00-e3be-11eb-8c11-7195e4cdb665.png">
