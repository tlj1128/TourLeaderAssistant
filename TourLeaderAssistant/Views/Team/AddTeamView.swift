import SwiftUI
import SwiftData
import EventKit

struct AddTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tourCode = ""
    @State private var name = ""
    @State private var departureDate = Date()
    @State private var days = 7
    @State private var addToCalendar = true
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendar: EKCalendar? = nil
    @State private var calendarAccessGranted = false

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

                Section {
                    Toggle("加入 Apple 行事曆", isOn: $addToCalendar)

                    if addToCalendar && calendarAccessGranted && !availableCalendars.isEmpty {
                        Picker("行事曆", selection: $selectedCalendar) {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(Color(cgColor: cal.cgColor))
                                    Text(cal.title)
                                }
                                .tag(Optional(cal))
                            }
                        }
                    }
                }
            }
            .navigationTitle("新增團體")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("建立") { addTeam() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCalendars()
            }
        }
    }

    private func loadCalendars() {
        CalendarManager.shared.requestAccess { granted in
            calendarAccessGranted = granted
            if granted {
                availableCalendars = CalendarManager.shared.availableCalendars()
                selectedCalendar = CalendarManager.shared.store.defaultCalendarForNewEvents
            }
        }
    }

    private func addTeam() {
        let team = Team(
            tourCode: tourCode,
            name: name,
            departureDate: departureDate,
            days: days
        )
        modelContext.insert(team)

        if addToCalendar, let calendar = selectedCalendar {
            CalendarManager.shared.addEvent(for: team, to: calendar)
        }

        dismiss()
    }
}
