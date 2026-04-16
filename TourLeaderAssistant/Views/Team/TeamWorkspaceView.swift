import SwiftUI
import SwiftData

struct TeamWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @State private var showingEditTeam = false
    @State private var showingCloseConfirm = false
    @State private var showingReopenConfirm = false
    @State private var showingAddFund = false

    @Query private var funds: [TourFund]
    @Query private var allExpenses: [Expense]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var teamFunds: [TourFund] {
        funds.filter { $0.teamID == team.id }
    }

    var pettyCash: TourFund? {
        teamFunds.first { $0.typeName == "零用金" }
    }

    var totalConverted: Decimal {
        allExpenses
            .filter { $0.teamID == team.id }
            .reduce(0) { $0 + $1.convertedAmount }
    }

    var pettyCashBalance: Decimal {
        (pettyCash?.initialAmount ?? 0) - totalConverted
    }

    var statusColor: Color {
        switch team.status {
        case .inProgress: return Color(hex: "2DB8A8")
        case .preparing: return Color(hex: "E8650A")
        case .pendingClose: return Color(hex: "5B8CDB")
        case .finished: return Color(.systemGray3)
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ── 頂部資訊卡 ──
                    infoCard

                    // ── 零用金卡 ──
                    fundCard

                    // ── 功能卡片 ──
                    workspaceGrid

                    // ── 輸出按鈕（已結團才顯示）──
                    if team.status == .finished {
                        outputButtons
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編輯") { showingEditTeam = true }
                    .foregroundStyle(Color("AppAccent"))
            }
        }
        .sheet(isPresented: $showingEditTeam) {
            EditTeamView(team: team)
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(isPresented: $showingAddFund) {
            AddTourFundView(team: team)
                .appDynamicTypeSize(textSizePreference)
        }
        .confirmationDialog("確認結團？", isPresented: $showingCloseConfirm, titleVisibility: .visible) {
            Button("結團", role: .destructive) {
                team.status = .finished
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("結團後將開放匯出報帳單與帶團報告書")
        }
        .confirmationDialog("取消結團？", isPresented: $showingReopenConfirm, titleVisibility: .visible) {
            Button("取消結團", role: .destructive) {
                team.status = .pendingClose
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("團體將回到「待結團」狀態")
        }
    }

    // MARK: - 頂部資訊卡

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(statusColor)
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !team.tourCode.isEmpty {
                            Text(team.tourCode)
                                .font(.footnote)
                                .foregroundStyle(Color(.systemGray))
                        }
                        Text(team.name)
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    StatusBadge(status: team.status)
                }

                Divider()
                
                if let notes = team.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(Color(.systemGray))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 0) {
                    infoItem(icon: "calendar", text: {
                        let f = DateFormatter()
                        f.dateFormat = "MM/dd"
                        return "\(f.string(from: team.departureDate)) – \(f.string(from: team.returnDate))"
                    }())
                    Spacer()
                    infoItem(icon: "moon.stars", text: "\(team.days) 天")
                    Spacer()
                    if let pax = team.paxCount {
                        infoItem(icon: "person.2", text: "\(pax) 人")
                    } else {
                        infoItem(icon: "person.2", text: "—")
                    }
                }
            }
            .padding(16)
        }
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func infoItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color(.systemGray))
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(.systemGray))
        }
    }

    // MARK: - 零用金卡

    private var fundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("零用金")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray))
                Spacer()
                Button(teamFunds.isEmpty ? "設定資金" : "管理") {
                    showingAddFund = true
                }
                .font(.footnote)
                .foregroundStyle(Color("AppAccent"))
            }

            if let fund = pettyCash {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(fund.currency)
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                    Text(pettyCashBalance.formatted(.number.precision(.fractionLength(2))))
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(pettyCashBalance >= 0 ? Color.primary : Color.red)
                    Spacer()
                }

                HStack {
                    Text("初始 \(fund.currency) \(fund.initialAmount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                    Text("·")
                        .foregroundStyle(Color(.systemGray3))
                    Text("已支出 \(fund.currency) \(totalConverted.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            } else {
                Text("尚未設定零用金")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(16)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - 功能卡片

    private var workspaceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {

            NavigationLink {
                ExpenseListView(team: team)
            } label: {
                WorkspaceCard(
                    title: "帳務紀錄",
                    systemImage: "dollarsign.circle",
                    color: Color(hex: "E8650A")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                JournalListView(team: team)
            } label: {
                WorkspaceCard(
                    title: "每日日誌",
                    systemImage: "book.pages",
                    color: Color(hex: "2DB8A8")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DocumentListView(team: team)
            } label: {
                WorkspaceCard(
                    title: "資料中心",
                    systemImage: "folder.fill",
                    color: Color(hex: "5B8CDB")
                )
            }
            .buttonStyle(.plain)

            // 第四格：依狀態變化
            switch team.status {
            case .preparing, .inProgress:
                // 鎖定
                WorkspaceCard(
                    title: "輸出文件",
                    systemImage: "square.and.arrow.up",
                    color: Color(.systemGray2),
                    isLocked: true
                )

            case .pendingClose:
                // 結團按鈕
                Button {
                    showingCloseConfirm = true
                } label: {
                    WorkspaceCard(
                        title: "待結團",
                        systemImage: "checkmark.circle.fill",
                        color: Color(hex: "5B8CDB"),
                        subtitle: "點此手動結團"
                    )
                }
                .buttonStyle(.plain)

            case .finished:
                // 取消結團
                Button {
                    showingReopenConfirm = true
                } label: {
                    WorkspaceCard(
                        title: "已結團",
                        systemImage: "checkmark.seal.fill",
                        color: Color(.systemGray3),
                        subtitle: "點此取消結團狀態"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 輸出按鈕（已結團才顯示）

    private var outputButtons: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: ExpenseExportView(team: team)) {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.body)
                    Text("匯出報帳單")
                        .font(.subheadline).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("AppCard"))
                .foregroundStyle(Color("AppAccent"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: JournalExportView(team: team)) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.body)
                    Text("匯出帶團報告書")
                        .font(.subheadline).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("AppCard"))
                .foregroundStyle(Color("AppAccent"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: TeamStatus

    var color: Color {
        switch status {
        case .inProgress: return Color(hex: "2DB8A8")
        case .preparing: return Color(hex: "E8650A")
        case .pendingClose: return Color(hex: "5B8CDB")
        case .finished: return Color(.systemGray3)
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - WorkspaceCard

struct WorkspaceCard: View {
    let title: String
    let systemImage: String
    let color: Color
    var isLocked: Bool = false
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: isLocked ? "lock.fill" : systemImage)
                .font(.title2)
                .foregroundStyle(isLocked ? Color(.systemGray3) : color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isLocked ? Color(.systemGray5) : color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(isLocked ? Color(.systemGray3) : .primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                } else if isLocked {
                    Text("結團後開放")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(14)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
