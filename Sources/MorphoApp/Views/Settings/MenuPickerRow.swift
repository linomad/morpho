import SwiftUI

struct MenuPickerRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            content()
                .frame(width: 240, alignment: .trailing)
        }
    }
}
