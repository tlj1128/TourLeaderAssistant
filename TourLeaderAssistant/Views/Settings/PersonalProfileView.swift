import SwiftUI

struct PersonalProfileView: View {
    @AppStorage("profile_nameZH") private var nameZH = ""
    @AppStorage("profile_nameEN") private var nameEN = ""
    @AppStorage("profile_phone") private var phone = ""
    @AppStorage("profile_lineID") private var lineID = ""
    @AppStorage("profile_notes") private var notes = ""

    @State private var isEditing = false

    var isValid: Bool {
        !nameZH.trimmingCharacters(in: .whitespaces).isEmpty &&
        !nameEN.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            Section {
                if isEditing {
                    TextField("中文姓名", text: $nameZH)
                    TextField("英文姓名", text: $nameEN)
                        .autocorrectionDisabled()
                    TextField("手機號碼", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("LINE ID", text: $lineID)
                        .autocorrectionDisabled()
                } else {
                    LabeledContent("中文姓名", value: nameZH.isEmpty ? "未設定" : nameZH)
                    LabeledContent("英文姓名", value: nameEN.isEmpty ? "未設定" : nameEN)
                    LabeledContent("手機號碼", value: phone.isEmpty ? "未設定" : phone)
                    if !lineID.isEmpty {
                        LabeledContent("LINE ID", value: lineID)
                    }
                }
            }

            if isEditing || !notes.isEmpty {
                Section("備註") {
                    if isEditing {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    } else {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("個人基本資料")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("完成") {
                        isEditing = false
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                } else {
                    Button("編輯") {
                        isEditing = true
                    }
                }
            }
        }
    }
}
