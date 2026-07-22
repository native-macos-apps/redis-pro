//
//  MTextEditor.swift
//  redis-pro
//
//  Migrated to LiquidGlass (Swift 6)
//

import SwiftUI

struct MTextEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .disableAutocorrection(true)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }
}


