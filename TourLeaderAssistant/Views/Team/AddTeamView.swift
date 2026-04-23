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
    @State private var calendarAccessError: String? = nil
    @State private var showingCountryPicker = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

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

                    if addToCalendar {
                        if let errorMessage = calendarAccessError {
                            // 顯示錯誤原因（拒絕授權或系統錯誤）
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if calendarAccessGranted && !availableCalendars.isEmpty {
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
        CalendarManager.shared.requestAccess { granted, error in
            calendarAccessGranted = granted
            if granted {
                calendarAccessError = nil
                availableCalendars = CalendarManager.shared.availableCalendars()
                selectedCalendar = CalendarManager.shared.store.defaultCalendarForNewEvents
            } else if let error {
                // 系統錯誤（例如家長監護限制）
                calendarAccessError = "無法存取行事曆：\(error.localizedDescription)"
            } else {
                // 使用者拒絕授權
                calendarAccessError = "請至「設定 > 隱私權 > 行事曆」允許存取"
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

        let today = Calendar.current.startOfDay(for: Date())
        let departure = Calendar.current.startOfDay(for: departureDate)
        let returnDay = Calendar.current.startOfDay(for: team.returnDate)

        if today < departure {
            team.status = .preparing
        } else if today >= departure && today <= returnDay {
            team.status = .inProgress
        } else if today > returnDay {
            team.status = .pendingClose
        }

        modelContext.insert(team)

        if addToCalendar, let calendar = selectedCalendar {
            CalendarManager.shared.addEvent(for: team, to: calendar)
        }

        dismiss()
    }
}
