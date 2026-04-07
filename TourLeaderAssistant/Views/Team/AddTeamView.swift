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
    @State private var selectedCountryCodes: [String] = []
    @State private var addToCalendar = false
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendar: EKCalendar? = nil
    @State private var calendarAccessGranted = false
    @State private var showingCountryPicker = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var returnDate: Date {
        Calendar.current.date(byAdding: .day, value: days - 1, to: departureDate) ?? departureDate
    }

    var isFormValid: Bool {
        !tourCode.isEmpty && !name.isEmpty && days > 0
    }

    var selectedCountryFlags: String {
        selectedCountryCodes.map { $0.flag }.joined(separator: " ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    LabeledTextField(label: "團號", placeholder: "TC20260619TK1", text: $tourCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
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
                                Text("選填")
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

                Section("行事曆") {
                    Toggle("加入 Apple 行事曆", isOn: $addToCalendar)

                    if addToCalendar && calendarAccessGranted && !availableCalendars.isEmpty {
                        ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                            Button {
                                selectedCalendar = cal
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 12, height: 12)
                                    Text(cal.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCalendar?.calendarIdentifier == cal.calendarIdentifier {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color("AppAccent"))
                                    }
                                }
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
            .onAppear { loadCalendars() }
            .sheet(isPresented: $showingCountryPicker) {
                TeamCountryPickerView(selectedCodes: $selectedCountryCodes)
                    .appDynamicTypeSize(textSizePreference)
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
        team.countryCodes = selectedCountryCodes
        modelContext.insert(team)

        if addToCalendar, let calendar = selectedCalendar {
            CalendarManager.shared.addEvent(for: team, to: calendar)
        }

        dismiss()
    }
}
