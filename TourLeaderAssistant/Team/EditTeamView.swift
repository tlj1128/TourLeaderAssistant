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
    @State private var flightInfo: String
    @State private var notes: String

    init(team: Team) {
        self.team = team
        _tourCode = State(initialValue: team.tourCode)
        _name = State(initialValue: team.name)
        _departureDate = State(initialValue: team.departureDate)
        _days = State(initialValue: team.days)
        _paxCount = State(initialValue: team.paxCount.map { String($0) } ?? "")
        _roomCount = State(initialValue: team.roomCount ?? "")
        _flightInfo = State(initialValue: team.flightInfo ?? "")
        _notes = State(initialValue: team.notes ?? "")
    }

    var returnDate: Date {
        Calendar.current.date(byAdding: .day, value: days - 1, to: departureDate) ?? departureDate
    }

    var isFormValid: Bool {
        !tourCode.isEmpty && !name.isEmpty && days > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    TextField("團號", text: $tourCode)
                    TextField("團名／目的地", text: $name)
                    DatePicker(
                        "出發日期",
                        selection: $departureDate,
                        displayedComponents: .date
                    )
                    Stepper("天數：\(days)天", value: $days, in: 1...60)
                }

                Section {
                    HStack {
                        Text("回國日期")
                        Spacer()
                        Text(returnDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("選填資料") {
                    TextField("人數", text: $paxCount)
                        .keyboardType(.numberPad)
                    TextField("房間數", text: $roomCount)
                    TextField("航班號碼", text: $flightInfo)
                    TextField("備註", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("編輯團體")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        team.tourCode = tourCode
        team.name = name
        team.departureDate = departureDate
        team.days = days
        team.returnDate = Calendar.current.date(
            byAdding: .day,
            value: days - 1,
            to: departureDate
        ) ?? departureDate
        team.paxCount = Int(paxCount)
        team.roomCount = roomCount.isEmpty ? nil : roomCount
        team.flightInfo = flightInfo.isEmpty ? nil : flightInfo
        team.notes = notes.isEmpty ? nil : notes
        dismiss()
    }
}
