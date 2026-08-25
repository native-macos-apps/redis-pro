//
//  LoginForm.swift
//  redis-pro
//
//  Native macOS connection form supporting Standalone, SSH Tunnel, Sentinel, and Cluster.
//

import SwiftUI

struct LoginForm: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: LoginViewModel

    private var selectedConnectionType: Binding<RedisConnectionTypeEnum> {
        Binding(
            get: { RedisConnectionTypeEnum(rawValue: viewModel.connectionType) ?? .TCP },
            set: { viewModel.connectionType = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer
        }
        .frame(width: 500, height: formHeight)
        .animation(.easeInOut(duration: 0.22), value: viewModel.connectionType)
    }

    private var formHeight: CGFloat {
        switch viewModel.connectionType {
        case RedisConnectionTypeEnum.SSH.rawValue: return 580
        case RedisConnectionTypeEnum.SENTINEL.rawValue: return 520
        case RedisConnectionTypeEnum.CLUSTER.rawValue: return 450
        default: return 440
        }
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            // ── Connection Mode ───────────────────────────────────────────
            Section {
                Picker("Connection Mode", selection: selectedConnectionType) {
                    ForEach(RedisConnectionTypeEnum.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // ── Basic Info ────────────────────────────────────────────────
            Section("General") {
                TextField("Favorite Name", text: $viewModel.name)
            }

            // ── Connection-specific Fields ────────────────────────────────
            switch selectedConnectionType.wrappedValue {
            case .TCP:
                Section("Redis Server") {
                    TextField("Host", text: $viewModel.host)
                    TextField("Port", value: $viewModel.port, format: .number)
                    TextField("Username", text: $viewModel.username)
                    SecureField("Password", text: $viewModel.password)
                    TextField("Database", value: $viewModel.database, format: .number)
                }

            case .SSH:
                Section("Target Redis Server") {
                    TextField("Host", text: $viewModel.host)
                    TextField("Port", value: $viewModel.port, format: .number)
                    TextField("Username", text: $viewModel.username)
                    SecureField("Password", text: $viewModel.password)
                    TextField("Database", value: $viewModel.database, format: .number)
                }
                Section("SSH Tunnel") {
                    TextField("SSH Host", text: $viewModel.sshHost)
                    TextField("SSH Port", value: $viewModel.sshPort, format: .number)
                    TextField("SSH Username", text: $viewModel.sshUser)
                    SecureField("SSH Password", text: $viewModel.sshPass)
                }

            case .SENTINEL:
                Section("Sentinel Configuration") {
                    TextField("Master Name", text: $viewModel.sentinelMasterName)
                    TextField("Sentinel Nodes (comma separated)", text: $viewModel.sentinelNodes)
                    SecureField("Sentinel Password (optional)", text: $viewModel.sentinelPassword)
                }
                Section("Redis Master Authentication") {
                    TextField("Username", text: $viewModel.username)
                    SecureField("Password", text: $viewModel.password)
                    TextField("Database", value: $viewModel.database, format: .number)
                }

            case .CLUSTER:
                Section("Cluster Configuration") {
                    TextField("Cluster Seed Nodes (comma separated)", text: $viewModel.clusterNodes)
                    TextField("Username", text: $viewModel.username)
                    SecureField("Password", text: $viewModel.password)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            // Status / loading
            if viewModel.loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.75)
                        .frame(width: 14, height: 14)
                    Text("Connecting…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.pingR.isEmpty {
                Text(viewModel.pingR)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        viewModel.pingR.lowercased().contains("success")
                        ? AnyShapeStyle(Color.green)
                        : AnyShapeStyle(Color.secondary)
                    )
            }

            Spacer()

            // Actions
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Test") { viewModel.testConnect() }
                .disabled(viewModel.loading)

            Button("Save") {
                viewModel.save()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
