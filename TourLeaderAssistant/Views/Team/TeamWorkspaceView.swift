import SwiftUI
import SwiftData

struct TeamWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team
    
    @State private var showingEditTeam = false
    @State private var showingCloseConfirm = false
    @State private var showingAddFund = false

    @Query private var funds: [TourFund]
    @Query private var allExpenses: [Expense]

    var teamFunds: [TourFund] {
        funds.filter { $0.teamID == team.id }
    }

    var pettyCash: TourFund? {
        teamFunds.first { $0.fundType == .pettyCash }
    }

    var totalConverted: Decimal {
        allExpenses
            .filter { $0.teamID == team.id }
            .reduce(0) { $0 + $1.convertedAmount }
    }

    var pettyCashBalance: Decimal {
        (pettyCash?.initialAmount ?? 0) - totalConverted
    }

    var totalInitialAmount: Decimal {
        teamFunds.first?.initialAmount ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // 基本資訊卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.tourCode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(team.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        StatusBadge(status: team.status)
                    }

                    HStack(spacing: 16) {
                        Label(team.departureDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        Label("\(team.days)天", systemImage: "clock")
                        if let pax = team.paxCount {
                            Label("\(pax)人", systemImage: "person.2")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()
                    HStack {
                        Text("零用金餘額")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let fund = pettyCash {
                            // ✅ 顯示餘額而非初始金額
                            Text("\(fund.currency) \(pettyCashBalance.formatted(.number.precision(.fractionLength(2))))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Button(teamFunds.isEmpty ? "設定資金" : "管理") {
                            showingAddFund = true
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 功能區塊
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {

                    NavigationLink {
                        ExpenseListView(team: team)
                    } label: {
                        WorkspaceCard(
                            title: "帳務紀錄",
                            systemImage: "doc.text",
                            color: .orange
                        )
                    }

                    NavigationLink {
                        JournalListView(team: team)
                    } label: {
                        WorkspaceCard(
                            title: "每日日誌",
                            systemImage: "pencil",
                            color: .gray
                        )
                    }

                    NavigationLink {
                        DocumentListView(team: team)
                    } label: {
                        WorkspaceCard(
                            title: "資料中心",
                            systemImage: "folder",
                            color: .blue
                        )
                    }

                    if team.status == .pendingClose {
                        Button {
                            showingCloseConfirm = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                Text("待結團")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("點此手動結團")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        WorkspaceCard(
                            title: "輸出文件",
                            systemImage: "square.and.arrow.up",
                            color: .gray,
                            isLocked: team.status != .finished
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編輯") {
                    showingEditTeam = true
                }
            }
        }
        .sheet(isPresented: $showingEditTeam) {
            EditTeamView(team: team)
        }
        .sheet(isPresented: $showingAddFund) {
            AddTourFundView(team: team)
        }
        .confirmationDialog("確認結團？", isPresented: $showingCloseConfirm, titleVisibility: .visible) {
            Button("結團", role: .destructive) {
                team.status = .finished
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("結團後將開放輸出報告書和報帳單")
        }
    }
}

struct StatusBadge: View {
    let status: TeamStatus

    var color: Color {
        switch status {
        case .inProgress: return .green
        case .preparing: return .orange
        case .pendingClose: return .blue
        case .finished: return .gray
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct WorkspaceCard: View {
    let title: String
    let systemImage: String
    let color: Color
    var isLocked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: isLocked ? "lock" : systemImage)
                .font(.title2)
                .foregroundStyle(isLocked ? .gray : color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isLocked ? .secondary : .primary)
            if isLocked {
                Text("結團後開放")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isLocked ? 0.6 : 1)
    }
}
