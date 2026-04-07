import SwiftUI

struct LabeledTextField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: $text)
                .font(.body)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}
