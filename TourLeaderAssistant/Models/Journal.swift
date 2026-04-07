import Foundation
import SwiftData

@Model
class Journal {
    var id: UUID
    var teamID: UUID
    var date: Date
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        teamID: UUID,
        date: Date = Date(),
        content: String = ""
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.date = date
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func dayNumber(from departureDate: Date) -> Int {
        let calendar = Calendar.current
        let departure = calendar.startOfDay(for: departureDate)
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: departure, to: day)
        return (components.day ?? 0) + 1
    }
}
