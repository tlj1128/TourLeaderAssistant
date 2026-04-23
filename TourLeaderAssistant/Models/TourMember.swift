import Foundation
import SwiftData

@Model
class TourMember {
    var id: UUID
    var teamID: UUID

    // 基本資料
    var nameEN: String
    var nameZH: String?
    var gender: String?         // "M" / "F" / nil
    var birthday: Date?

    // 護照
    var passportNumber: String?
    var passportExpiry: Date?

    // 分房 / 分組
    var roomLabel: String?      // 同房者英文姓名，或房號標籤
    var groupLabel: String?     // 手動設定的組別名稱

    // 備註（原始 + 整合）
    var remark: String?         // 所有備註合併存放

    // 排序（保留原始順序）
    var sortOrder: Int

    var createdAt: Date

    init(
        teamID: UUID,
        nameEN: String,
        nameZH: String? = nil,
        gender: String? = nil,
        birthday: Date? = nil,
        passportNumber: String? = nil,
        passportExpiry: Date? = nil,
        roomLabel: String? = nil,
        groupLabel: String? = nil,
        remark: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.nameEN = nameEN
        self.nameZH = nameZH
        self.gender = gender
        self.birthday = birthday
        self.passportNumber = passportNumber
        self.passportExpiry = passportExpiry
        self.roomLabel = roomLabel
        self.groupLabel = groupLabel
        self.remark = remark
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    // MARK: - 計算屬性

    /// 護照效期不足：回國日後不足 6 個月
    func passportWarning(returnDate: Date) -> Bool {
        guard let expiry = passportExpiry else { return false }
        let sixMonthsAfterReturn = Calendar.current.date(
            byAdding: .month,
            value: 6,
            to: returnDate
        ) ?? returnDate
        return expiry < sixMonthsAfterReturn
    }

    /// 行程中有生日
    func hasBirthdayOnTrip(departureDate: Date, returnDate: Date) -> Bool {
        guard let bday = birthday else { return false }
        let calendar = Calendar.current
        let bdayComponents = calendar.dateComponents([.month, .day], from: bday)
        guard let month = bdayComponents.month, let day = bdayComponents.day else { return false }

        var current = departureDate
        while current <= returnDate {
            let c = calendar.dateComponents([.month, .day], from: current)
            if c.month == month && c.day == day { return true }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? returnDate.addingTimeInterval(86400)
        }
        return false
    }

    /// 役男判斷：性別 M，且出發日當下年齡介於 18–36 歲（含）
    func isDraftAge(departureDate: Date) -> Bool {
        guard gender?.uppercased() == "M", let bday = birthday else { return false }
        let age = Calendar.current.dateComponents([.year], from: bday, to: departureDate).year ?? 0
        return age >= 18 && age <= 36
    }

    /// 顯示用姓名（中文優先，無中文則英文）
    var displayName: String {
        if let zh = nameZH, !zh.isEmpty { return zh }
        return nameEN
    }

    /// 年齡（以出發日計算，無生日則 nil）
    func age(at date: Date) -> Int? {
        guard let bday = birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: bday, to: date).year
    }
}
