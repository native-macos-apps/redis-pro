//
//  SettingsView.swift
//  redis-pro
//
//  Liquid Glass settings panel.
//  Migrated to MVVM (Swift 6)
//

import SwiftUI
import Logging

struct SettingsView: View {

    private static let logger = Logger(label: "settings-view")
    private let labelWidth: CGFloat = 160

    @State var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker(
                    selection: Binding(
                        get: { viewModel.defaultFavorite },
                        set: { viewModel.setDefaultFavorite($0) }
                    ),
                    label: Text("Default Favorite").frame(width: labelWidth, alignment: .trailing)
                ) {
                    Text("Last Used").tag("last")
                    ForEach(viewModel.redisModels, id: \.id) { Text($0.name).tag($0.id) }
                }

                Picker(
                    selection: Binding(
                        get: { viewModel.colorSchemeValue },
                        set: { viewModel.setColorScheme($0) }
                    ),
                    label: Text("Appearance").frame(width: labelWidth, alignment: .trailing)
                ) {
                    ForEach(ColorSchemeEnum.allCases.map(\.rawValue), id: \.self) {
                        Text(verbatim: $0)
                    }
                }
            }

            Section {
                FormItemInt(
                    label: "String Max Length",
                    labelWidth: labelWidth,
                    tips: "HELP_STRING_GET_RANGE_LENGTH",
                    value: Binding(
                        get: { viewModel.stringMaxLength },
                        set: { viewModel.setStringMaxLength($0) }
                    )
                )

                Toggle(isOn: Binding(
                    get: { viewModel.fastPage },
                    set: { viewModel.setFastPage($0) }
                )) {
                    Text("Fast Pagination")
                        .frame(width: labelWidth, alignment: .trailing)
                }
                .toggleStyle(.switch)
                .help("HELP_FAST_PAGE")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Preferences")
    }
}
