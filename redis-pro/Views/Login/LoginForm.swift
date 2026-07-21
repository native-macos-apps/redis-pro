//
//  LoginForm.swift
//  redis-pro
//
//  Native macOS connection form.
//  Single-screen layout: Connection fields + SSH Tunnel toggle (no tabs).
//

import SwiftUI

struct LoginForm: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: LoginViewModel

    // MARK: - SSH binding

    private var sshEnabled: Binding<Bool> {
        Binding(
            get: { viewModel.connectionType == RedisConnectionTypeEnum.SSH.rawValue },
            set: { viewModel.connectionType = $0
                ? RedisConnectionTypeEnum.SSH.rawValue
                : RedisConnectionTypeEnum.TCP.rawValue
            }
        )
    }

    private var useSSH: Bool {
        viewModel.connectionType == RedisConnectionTypeEnum.SSH.rawValue
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer
        }
        .frame(width: 480, height: useSSH ? 560 : 400)
        .animation(.easeInOut(duration: 0.22), value: useSSH)
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            // ── Connection ───────────────────────────────────────────────
            Section("Connection") {
                TextField("Name", text: $viewModel.name)
                TextField("Host", text: $viewModel.host)
                TextField("Port", value: $viewModel.port, format: .number)
                TextField("Username", text: $viewModel.username)
                SecureField("Password", text: $viewModel.password)
                TextField("Database", value: $viewModel.database, format: .number)
            }

            // ── SSH Tunnel ───────────────────────────────────────────────
            Section {
                Toggle("SSH Tunnel", isOn: sshEnabled)
                    .toggleStyle(.switch)

                if useSSH {
                    TextField("SSH Host", text: $viewModel.sshHost)
                    TextField("SSH Port", value: $viewModel.sshPort, format: .number)
                    TextField("SSH Username", text: $viewModel.sshUser)
                    SecureField("SSH Password", text: $viewModel.sshPass)
                }
            } header: {
                Text("SSH Tunnel")
            } footer: {
                if !useSSH {
                    Text("Enable to route the connection through an SSH server.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.22), value: useSSH)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            // Status / loading (left side — always present via Spacer)
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

            Spacer() // always pushes buttons to the right

            // Actions — always pinned right
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
