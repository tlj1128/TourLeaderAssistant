import Foundation
import SwiftData

@Model
class Team {
    var id: UUID
    var tourCode: String
    var name: String
    var departureDate: Date
    var days: Int
    var returnDate: Date
    var paxCount: Int?
    var roomCount: String?
    var flightInfo: String?
    var status: TeamStatus
    var calendarEventID: String?
    var notes: String?
    var createdAt: Date

    init(
        tourCode: String,
        name: String,
        departureDate: Date,
        days: Int
    ) {
        self.id = UUID()
        self.tourCode = tourCode
        self.name = name
        self.departureDate = departureDate
        self.days = days
        self.returnDate = Calendar.current.date(
            byAdding: .day,
            value: days - 1,
            to: departureDate
        ) ?? departureDate
        self.status = .preparing
        self.createdAt = Date()
    }
}

enum TeamStatus: String, Codable {
    case preparing = "preparing"
    case inProgress = "inProgress"
    case pendingClose = "pendingClose"
    case finished = "finished"

    var displayName: String {
        switch self {
        case .preparing: return "準備中"
        case .inProgress: return "進行中"
        case .pendingClose: return "待結團"
        case .finished: return "已結團"
        }
    }
}
