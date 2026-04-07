import SwiftUI

struct TeamRowView: View {
    let team: Team

    var statusColor: Color {
        switch team.status {
        case .inProgress: return .green
        case .preparing: return .orange
        case .pendingClose: return .blue
        case .finished: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(team.name)
                    .font(.headline)
                Spacer()
                Text(team.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            Text("\(team.tourCode)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(team.departureDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                Label("\(team.days)天", systemImage: "clock")
                if let pax = team.paxCount {
                    Label("\(pax)人", systemImage: "person.2")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
