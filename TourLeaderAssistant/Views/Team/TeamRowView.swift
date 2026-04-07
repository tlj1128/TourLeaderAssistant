import SwiftUI

struct TeamRowView: View {
    let team: Team

    var statusColor: Color {
        switch team.status {
        case .inProgress: return Color(hex: "2DB8A8")
        case .preparing: return Color(hex: "E8650A")
        case .pendingClose: return Color(hex: "5B8CDB")
        case .finished: return Color(.systemGray3)
        }
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: team.departureDate)) – \(formatter.string(from: team.returnDate))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部色條
            Rectangle()
                .fill(statusColor)
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 10) {
                // 團名 + 狀態標籤
                HStack(alignment: .top) {
                    Text(team.name)
                        .font(.body).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    Text(team.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }

                // 團號
                Text(team.tourCode)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemGray))

                Divider()

                // 底部資訊列
                HStack(spacing: 0) {
                    InfoChip(icon: "calendar", text: dateRangeText)
                    Spacer()
                    InfoChip(icon: "moon.stars", text: "\(team.days) 天")
                    Spacer()
                    if let pax = team.paxCount {
                        InfoChip(icon: "person.2", text: "\(pax) 人")
                    } else {
                        InfoChip(icon: "person.2", text: "—")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

private struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color(.systemGray))
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(.systemGray))
        }
    }
}
