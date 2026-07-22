//
//  redis_proApp.swift
//  redis-pro
//
//  Created by chengpanwang on 2021/1/19.
//  Migrated to MVVM (Swift 6) — removed TCA Store/ComposableArchitecture
//

import Foundation
import SwiftUI
import Logging

@main
struct redis_proApp: App {
    private let logger = Logger(label: "app")
    @AppStorage(UserDefaultsKeysEnum.AppColorScheme.rawValue)
    private var colorSchemeValue: String = ColorSchemeEnum.SYSTEM.rawValue

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private var rootViewModel = AppRootViewModel()
    private var mainWindowId = UUID().uuidString

    // 应用启动只初始化一次
    init() {
        rootViewModel.addWindow(mainWindowId)
    }


    var body: some Scene {
        Window("Home", id: "login-window") {
            if let appVM = rootViewModel.windows.first {
                IndexView(viewModel: appVM)
                    .preferredColorScheme(preferredColorScheme)
            }
        }
        .defaultSize(width: 680, height: 460)
        .windowStyle(.hiddenTitleBar)

        WindowGroup("Workspace", id: "workspace-window", for: String.self) { $windowId in
            if let id = windowId, let appVM = rootViewModel.window(id: id) {
                HomeView(viewModel: appVM)
                    .preferredColorScheme(preferredColorScheme)
            }
        }
        .defaultSize(width: 1000, height: 650)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.toolbar) {
                Button(action: openNewWindow) {
                    Text("New Tab")
                }
                .keyboardShortcut("T", modifiers: [.command])
            }
        }
        .commands {
            RedisProCommands()
        }

        WindowGroup("AboutView") {
            AboutView()
                .preferredColorScheme(preferredColorScheme)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "AboutView"))
        .windowToolbarStyle(.unifiedCompact)

        Settings {
            SettingsView(viewModel: rootViewModel.windows.first?.settings ?? SettingsViewModel())
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeValue {
        case ColorSchemeEnum.DARK.rawValue:
            return .dark
        case ColorSchemeEnum.LIGHT.rawValue:
            return .light
        default:
            return nil
        }
    }

    func openNewWindow() {
        guard let currentWindow = NSApp.keyWindow else { return }

        // 创建新窗口
        currentWindow.windowController?.newWindowForTab(nil)

        // 获取新创建的窗口
        guard let newWindow = NSApp.windows.last,
              newWindow != currentWindow else { return }

        let windowId = UUID().uuidString
        rootViewModel.addWindow(windowId)

        guard let appVM = rootViewModel.window(id: windowId) else { return }
        let customView = IndexView(viewModel: appVM)
        newWindow.contentViewController = NSHostingController(rootView: customView)

        // 添加到标签页
        currentWindow.addTabbedWindow(newWindow, ordered: .above)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = Logger(label: "redis-app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("redis pro launch complete")
    }
}
