import SwiftUI

struct EditJournalView: View {
    @Environment(\.dismiss) private var dismiss

    var journal: Journal
    let team: Team

    @State private var date: Date
    @State private var content: String

    init(journal: Journal, team: Team) {
        self.journal = journal
        self.team = team
        _date = State(initialValue: journal.date)
        _content = State(initialValue: journal.content)
    }

    var isFormValid: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_TW"))
                }

                Section("內容") {
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("記錄今天發生的事…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                    }
                }
            }
            .navigationTitle("編輯日誌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { saveChanges() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        journal.date = date
        journal.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        journal.updatedAt = Date()
        dismiss()
    }
}
