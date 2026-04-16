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

    // completion 改為回傳 (Bool, Error?)，讓 UI 層可區分拒絕與系統錯誤
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        store.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                completion(granted, error)
            }
        }
    }

    func addEvent(for team: Team, to calendar: EKCalendar) {
        let event = EKEvent(eventStore: store)
        event.title = "✈️ \(team.name)"
        event.notes = "團號：\(team.tourCode)"
        event.isAllDay = true
        event.startDate = team.departureDate

        // 修正強制解包：全天事件結束日加一天，失敗時 fallback 到 returnDate
        guard let endDate = Calendar.current.date(byAdding: .day, value: 1, to: team.returnDate) else {
            print("CalendarManager：無法計算結束日，fallback 到 returnDate")
            event.endDate = team.returnDate
            event.calendar = calendar
            try? store.save(event, span: .thisEvent)
            team.calendarEventID = event.eventIdentifier
            return
        }
        event.endDate = endDate
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
