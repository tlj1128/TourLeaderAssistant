import Foundation
import EventKit

class CalendarManager {
    static let shared = CalendarManager()
    let store = EKEventStore()

    private init() {}

    // 取得所有可寫入的行事曆
    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func addEvent(for team: Team, to calendar: EKCalendar) {
        let event = EKEvent(eventStore: store)
        event.title = "✈️ \(team.name)"
        event.notes = "團號：\(team.tourCode)"
        event.isAllDay = true
        event.startDate = team.departureDate
        // 行事曆全天事件的結束日要加一天
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: team.returnDate)!
        event.calendar = calendar

        do {
            try store.save(event, span: .thisEvent)
            team.calendarEventID = event.eventIdentifier
        } catch {
            print("行事曆寫入錯誤：\(error)")
        }
    }

    func removeEvent(for team: Team) {
        guard let eventID = team.calendarEventID,
              let event = store.event(withIdentifier: eventID) else { return }
        try? store.remove(event, span: .thisEvent)
        team.calendarEventID = nil
    }
}
