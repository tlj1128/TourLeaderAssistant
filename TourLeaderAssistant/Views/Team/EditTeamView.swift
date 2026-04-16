import SwiftUI

struct EditTeamView: View {
    @Environment(\.dismiss) private var dismiss
    let team: Team

    @State private var tourCode: String
    @State private var name: String
    @State private var departureDate: Date
    @State private var days: Int
    @State private var paxCount: String
    @State private var roomCount: String
    @State private var notes: String
    @State private var selectedCountryCodes: [String]
    @State private var showingCountryPicker = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    init(team: Team) {
        self.team = team
        _tourCode = State(initialValue: team.tourCode)
        _name = State(initialValue: team.name)
        _departureDate = State(initialValue: team.departureDate)
        _days = State(initialValue: team.days)
        _paxCount = State(initialValue: team.paxCount.map { String($0) } ?? "")
        _roomCount = State(initialValue: team.roomCount ?? "")
        _notes = State(initialValue: team.notes ?? "")
        _selectedCountryCodes = State(initialValue: team.countryCodes)
    }

    var returnDate: Date {
        Calendar.current.date(byAdding: .day, value: days - 1, to: departureDate) ?? departureDate
    }

    var isFormValid: Bool {
        !name.isEmpty && days > 0
    }

    var selectedCountryFlags: String {
        selectedCountryCodes.map { $0.flag }.joined(separator: " ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    LabeledTextField(label: "團號", placeholder: "TC20260619TK1（選填）", text: $tourCode)
                        .autocorrectionDisabled()
                    LabeledTextField(label: "團名", placeholder: "納米比亞 16 天", text: $name)
                    DatePicker("出發日期", selection: $departureDate, displayedComponents: .date)
                    Stepper("天數：\(days) 天", value: $days, in: 1...60)
                }

                Section {
                    HStack {
                        Text("回國日期")
                        Spacer()
                        Text(returnDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingCountryPicker = true
                    } label: {
                        HStack {
                            Text("目的地國家")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCountryCodes.isEmpty {
                                Text("未設定")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(selectedCountryFlags)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("選填資料") {
                    LabeledTextField(label: "人數", placeholder: "10", text: $paxCount)
                        .keyboardType(.numberPad)
                    LabeledTextField(label: "房間數", placeholder: "5 DBL + 1 SGL", text: $roomCount)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    LabeledTextField(label: "備註", placeholder: "特殊需求、注意事項…", text: $notes)
                }
            }
            .navigationTitle("編輯團體")
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
            .sheet(isPresented: $showingCountryPicker) {
                TeamCountryPickerView(selectedCodes: $selectedCountryCodes)
                    .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    private func saveChanges() {
        team.tourCode = tourCode
        team.name = name
        team.departureDate = departureDate
        team.days = days
        team.returnDate = Calendar.current.date(
            byAdding: .day, value: days - 1, to: departureDate
        ) ?? departureDate
        team.paxCount = Int(paxCount)
        team.roomCount = roomCount.isEmpty ? nil : roomCount
        team.notes = notes.isEmpty ? nil : notes
        team.countryCodes = selectedCountryCodes

        // 儲存後即時更新狀態
        let today = Calendar.current.startOfDay(for: Date())
        let departure = Calendar.current.startOfDay(for: team.departureDate)
        let returnDay = Calendar.current.startOfDay(for: team.returnDate)
        let dayAfterReturn = Calendar.current.date(byAdding: .day, value: 1, to: returnDay) ?? returnDay

        if team.status != .finished {
            if today < departure {
                team.status = .preparing
            } else if today >= departure && today <= returnDay {
                team.status = .inProgress
            } else if today >= dayAfterReturn {
                team.status = .pendingClose
            }
        }

        dismiss()
    }
}
