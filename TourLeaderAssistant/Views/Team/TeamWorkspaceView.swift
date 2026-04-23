import SwiftUI
import SwiftData

// MARK: - 分組用結構

struct MemberDietaryInfo {
    let member: TourMember
    let needs: [DietaryNeed]
}

// MARK: - TeamWorkspaceView

struct TeamWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @State private var showingEditTeam = false
    @State private var showingCloseConfirm = false
    @State private var showingReopenConfirm = false
    @State private var showingAddFund = false
    @State private var alertCardExpanded = true
    @State private var dietaryInfoList: [MemberDietaryInfo] = []
    @State private var isDietaryLoading = false

    @Query private var funds: [TourFund]
    @Query private var allExpenses: [Expense]
    @Query private var allMembers: [TourMember]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var teamFunds: [TourFund] { funds.filter { $0.teamID == team.id } }

    var pettyCash: TourFund? { teamFunds.first { $0.typeName == "零用金" } }

    var totalConverted: Decimal {
        allExpenses.filter { $0.teamID == team.id }.reduce(0) { $0 + $1.convertedAmount }
    }

    var pettyCashBalance: Decimal { (pettyCash?.initialAmount ?? 0) - totalConverted }

    var teamMembers: [TourMember] {
        allMembers.filter { $0.teamID == team.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var birthdayMembers: [TourMember] {
        teamMembers.filter {
            $0.hasBirthdayOnTrip(departureDate: team.departureDate, returnDate: team.returnDate)
        }
    }

    var dietaryByCategory: [(category: DietaryCategory, entries: [(seqNo: String, member: TourMember, labels: [String])])] {
        var dict: [DietaryCategory: [(seqNo: String, member: TourMember, labels: [String])]] = [:]
        for info in dietaryInfoList {
            let seqNo = String(format: "%02d", info.member.sortOrder + 1)
            let byCategory = Dictionary(grouping: info.needs, by: { $0.category })
            for (cat, needs) in byCategory {
                let labels = needs.sorted { $0.sortKey < $1.sortKey }.map { $0.label }
                dict[cat, default: []].append((seqNo, info.member, labels))
            }
        }
        return DietaryCategory.allCases.compactMap { cat in
            guard let entries = dict[cat], !entries.isEmpty else { return nil }
            return (cat, entries.sorted { $0.seqNo < $1.seqNo })
        }
    }

    var multiCategoryMemberIDs: Set<UUID> {
        var catCount: [UUID: Int] = [:]
        for group in dietaryByCategory {
            for entry in group.entries {
                catCount[entry.member.id, default: 0] += 1
            }
        }
        return Set(catCount.filter { $0.value >= 2 }.keys)
    }

    var shouldShowAlertCard: Bool { !birthdayMembers.isEmpty || !dietaryInfoList.isEmpty }

    var statusColor: Color {
        switch team.status {
        case .inProgress:   return Color(hex: "2DB8A8")
        case .preparing:    return Color(hex: "E8650A")
        case .pendingClose: return Color(hex: "5B8CDB")
        case .finished:     return Color(.systemGray3)
        }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    infoCard
                    fundCard
                    if shouldShowAlertCard { memberAlertCard }
                    workspaceGrid
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
            EditTeamView(team: team).appDynamicTypeSize(textSizePreference)
        }
        .sheet(isPresented: $showingAddFund) {
            AddTourFundView(team: team).appDynamicTypeSize(textSizePreference)
        }
        .confirmationDialog("確認結團？", isPresented: $showingCloseConfirm, titleVisibility: .visible) {
            Button("結團", role: .destructive) { team.status = .finished }
            Button("取消", role: .cancel) {}
        } message: { Text("結團後將開放匯出報帳單與帶團報告書") }
        .confirmationDialog("取消結團？", isPresented: $showingReopenConfirm, titleVisibility: .visible) {
            Button("取消結團", role: .destructive) { team.status = .pendingClose }
            Button("取消", role: .cancel) {}
        } message: { Text("團體將回到「待結團」狀態") }
        .task { await loadDietaryInfo() }
        .onChange(of: teamMembers) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await loadDietaryInfo()
            }
        }
    }

    // MARK: - 載入飲食資訊

    private func loadDietaryInfo() async {
        isDietaryLoading = true
        var result: [MemberDietaryInfo] = []
        for member in teamMembers {
            guard let remark = member.remark, !remark.isEmpty else { continue }
            let needs = await DietaryParser.parse(remark: remark)
            if !needs.isEmpty {
                result.append(MemberDietaryInfo(member: member, needs: needs))
            }
        }
        dietaryInfoList = result
        isDietaryLoading = false
    }

    // MARK: - 頂部資訊卡

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(statusColor).frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !team.tourCode.isEmpty {
                            Text(team.tourCode).font(.footnote).foregroundStyle(Color(.systemGray))
                        }
                        Text(team.name).font(.title2).fontWeight(.bold).foregroundStyle(.primary)
                    }
                    Spacer()
                    StatusBadge(status: team.status)
                }
                Divider()
                if let notes = team.notes, !notes.isEmpty {
                    Text(notes).font(.footnote).foregroundStyle(Color(.systemGray))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 0) {
                    infoItem(icon: "calendar", text: {
                        let f = DateFormatter(); f.dateFormat = "MM/dd"
                        return "\(f.string(from: team.departureDate)) – \(f.string(from: team.returnDate))"
                    }())
                    Spacer()
                    infoItem(icon: "moon.stars", text: "\(team.days) 天")
                    Spacer()
                    infoItem(icon: "person.2", text: team.paxCount.map { "\($0) 人" } ?? "—")
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
            Image(systemName: icon).font(.caption).foregroundStyle(Color(.systemGray))
            Text(text).font(.footnote).foregroundStyle(Color(.systemGray))
        }
    }

    // MARK: - 零用金卡

    private var fundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("零用金").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color(.systemGray))
                Spacer()
                Button(teamFunds.isEmpty ? "設定資金" : "管理") { showingAddFund = true }
                    .font(.footnote).foregroundStyle(Color("AppAccent"))
            }
            if let fund = pettyCash {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(fund.currency).font(.subheadline).foregroundStyle(Color(.systemGray))
                    Text(pettyCashBalance.formatted(.number.precision(.fractionLength(2))))
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(pettyCashBalance >= 0 ? Color.primary : Color.red)
                    Spacer()
                }
                HStack {
                    Text("初始 \(fund.currency) \(fund.initialAmount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption).foregroundStyle(Color(.systemGray))
                    Text("·").foregroundStyle(Color(.systemGray3))
                    Text("已支出 \(fund.currency) \(totalConverted.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption).foregroundStyle(Color(.systemGray))
                }
            } else {
                Text("尚未設定零用金").font(.subheadline).foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(16)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - 團員提醒事項卡

    private var memberAlertCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { alertCardExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill").font(.caption).foregroundStyle(Color(hex: "E8650A"))
                    Text("團員提醒事項").font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Spacer()
                    if isDietaryLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if !alertCardExpanded {
                        collapsedBadges
                    }
                    Image(systemName: alertCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(Color(.systemGray3))
                }
            }
            .buttonStyle(.plain)
            .padding(16)
            .contentShape(Rectangle())

            if alertCardExpanded {
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 16) {
                    if !birthdayMembers.isEmpty { birthdaySection }
                    dietarySection
                }
                .padding(16)
            }
        }
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var collapsedBadges: some View {
        HStack(spacing: 6) {
            if !birthdayMembers.isEmpty {
                Label("\(birthdayMembers.count)", systemImage: "gift.fill")
                    .font(.caption2).foregroundStyle(Color(hex: "E8650A"))
            }
            if !dietaryInfoList.isEmpty {
                Label("\(dietaryInfoList.count)", systemImage: "fork.knife")
                    .font(.caption2).foregroundStyle(Color(hex: "2DB8A8"))
            }
        }
    }

    private var birthdaySection: some View {
        alertSection(icon: "gift.fill", title: "行程中生日", color: Color(hex: "E8650A")) {
            ForEach(birthdayMembers) { member in
                birthdayRow(member: member)
            }
        }
    }

    private func birthdayRow(member: TourMember) -> some View {
        let seqNo = String(format: "%02d", member.sortOrder + 1)
        return HStack(spacing: 6) {
            Text(seqNo).font(.caption2).foregroundStyle(Color(.systemGray3))
                .frame(width: 20, alignment: .trailing)
            Text(member.displayName).font(.subheadline).foregroundStyle(.primary)
            if let bday = member.birthday {
                Text(birthdayString(bday)).font(.subheadline).foregroundStyle(Color(.systemGray))
            }
        }
    }

    @ViewBuilder
    private var dietarySection: some View {
        if isDietaryLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("解析飲食需求中…").font(.caption).foregroundStyle(Color(.systemGray))
            }
        } else if !dietaryByCategory.isEmpty {
            if !birthdayMembers.isEmpty { Divider() }
            dietaryCategoryList
            if !multiCategoryMemberIDs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "E8650A"))
                    Text("＊ 標注旅客同時有多項飲食需求，請留意")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "E8650A"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "E8650A").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
            }
        }
    }

    private var dietaryCategoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(dietaryByCategory.enumerated()), id: \.offset) { idx, group in
                if idx > 0 { Divider().padding(.leading, 28) }
                dietaryCategorySection(group: group)
            }
        }
    }

    private func dietaryCategorySection(
        group: (category: DietaryCategory, entries: [(seqNo: String, member: TourMember, labels: [String])])
    ) -> some View {
        alertSection(
            icon: group.category.icon,
            title: "\(group.category.rawValue)（\(group.entries.count) 人）",
            color: group.category.color
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(group.entries, id: \.member.id) { entry in
                    dietaryEntryRow(entry: entry)
                }
            }
        }
    }

    private func dietaryEntryRow(
        entry: (seqNo: String, member: TourMember, labels: [String])
    ) -> some View {
        let isMulti = multiCategoryMemberIDs.contains(entry.member.id)
        return HStack(alignment: .top, spacing: 6) {
            Text(entry.seqNo).font(.caption2).foregroundStyle(Color(.systemGray3))
                .frame(width: 20, alignment: .trailing)
            HStack(spacing: 2) {
                Text(entry.member.displayName)
                .font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                if isMulti {
                    Text("＊").font(.caption2).foregroundStyle(Color(hex: "E8650A"))
                }
            }
            .frame(minWidth: 52, alignment: .leading)
            Text(entry.labels.joined(separator: "、"))
                .font(.subheadline).foregroundStyle(Color(.systemGray))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func alertSection<Content: View>(
        icon: String, title: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).fontWeight(.semibold).foregroundStyle(color)
            content()
        }
    }

    private func birthdayString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }

    // MARK: - 功能卡片

    private var workspaceGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink { ExpenseListView(team: team) } label: {
                    WorkspaceCard(title: "帳務紀錄", systemImage: "dollarsign.circle", color: Color(hex: "E8650A"))
                }.buttonStyle(.plain)
                NavigationLink { JournalListView(team: team) } label: {
                    WorkspaceCard(title: "每日日誌", systemImage: "book.pages", color: Color(hex: "2DB8A8"))
                }.buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink { DocumentListView(team: team) } label: {
                    WorkspaceCard(title: "資料中心", systemImage: "folder.fill", color: Color(hex: "5B8CDB"))
                }.buttonStyle(.plain)
                NavigationLink { TourMemberListView(team: team) } label: {
                    WorkspaceCard(title: "團員名單", systemImage: "person.2.fill", color: Color(hex: "A06CD5"))
                }.buttonStyle(.plain)
            }
            outputCard
        }
    }

    // MARK: - 輸出卡片

    @ViewBuilder
    private var outputCard: some View {
        switch team.status {
        case .preparing, .inProgress:
            WorkspaceCard(title: "輸出文件", systemImage: "square.and.arrow.up",
                          color: Color(.systemGray2), isLocked: true, isFullWidth: true)
        case .pendingClose:
            Button { showingCloseConfirm = true } label: {
                WorkspaceCard(title: "待結團", systemImage: "checkmark.circle.fill",
                              color: Color(hex: "5B8CDB"), subtitle: "點此手動結團", isFullWidth: true)
            }.buttonStyle(.plain)
        case .finished:
            VStack(spacing: 12) {
                Button { showingReopenConfirm = true } label: {
                    WorkspaceCard(title: "已結團", systemImage: "checkmark.seal.fill",
                                  color: Color(.systemGray3), subtitle: "點此取消結團狀態", isFullWidth: true)
                }.buttonStyle(.plain)
                NavigationLink(destination: ExpenseExportView(team: team)) {
                    outputButton(icon: "tablecells", title: "匯出報帳單")
                }.buttonStyle(.plain)
                NavigationLink(destination: JournalExportView(team: team)) {
                    outputButton(icon: "doc.text", title: "匯出帶團報告書")
                }.buttonStyle(.plain)
            }
        }
    }

    private func outputButton(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).font(.body)
            Text(title).font(.subheadline).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color("AppCard")).foregroundStyle(Color("AppAccent"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: TeamStatus
    var color: Color {
        switch status {
        case .inProgress:   return Color(hex: "2DB8A8")
        case .preparing:    return Color(hex: "E8650A")
        case .pendingClose: return Color(hex: "5B8CDB")
        case .finished:     return Color(.systemGray3)
        }
    }
    var body: some View {
        Text(status.displayName).font(.caption)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.12)).foregroundStyle(color).clipShape(Capsule())
    }
}

// MARK: - WorkspaceCard

struct WorkspaceCard: View {
    let title: String
    let systemImage: String
    let color: Color
    var isLocked: Bool = false
    var subtitle: String? = nil
    var isFullWidth: Bool = false

    var body: some View {
        Group { if isFullWidth { fullWidthLayout } else { stackLayout } }
            .padding(14).background(Color("AppCard"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var fullWidthLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 3) { titleView; subtitleView }
            Spacer()
            if !isLocked {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color(.systemGray3))
            }
        }
    }

    private var stackLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            iconView
            VStack(alignment: .leading, spacing: 3) { titleView; subtitleView }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }

    private var iconView: some View {
        Image(systemName: isLocked ? "lock.fill" : systemImage).font(.title2)
            .foregroundStyle(isLocked ? Color(.systemGray3) : color)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isLocked ? Color(.systemGray5) : color.opacity(0.12)))
    }

    private var titleView: some View {
        Text(title).font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(isLocked ? Color(.systemGray3) : .primary)
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let subtitle = subtitle {
            Text(subtitle).font(.caption).foregroundStyle(Color(.systemGray))
        } else if isLocked {
            Text("結團後開放").font(.caption).foregroundStyle(Color(.systemGray3))
        }
    }
}

// MARK: - DietaryCategory + Color（View 層擴充）

extension DietaryCategory {
    var color: Color {
        switch self {
        case .allergy:     return Color(hex: "E8650A")
        case .vegetarian:  return Color(hex: "2DB8A8")
        case .avoidFood:   return Color(hex: "5B8CDB")
        case .airlineMeal: return Color(hex: "A06CD5")
        }
    }
}
