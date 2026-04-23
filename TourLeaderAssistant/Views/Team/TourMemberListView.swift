import SwiftUI
import SwiftData

// MARK: - Main View

struct TourMemberListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allMembers: [TourMember]

    // 排序
    @State private var sortField: MemberSortField = .original
    @State private var sortAscending: Bool = true

    // 編輯模式（刪除）
    @State private var isEditing: Bool = false
    @State private var selectedForDelete: Set<UUID> = []
    @State private var showingDeleteConfirm = false

    // 選人模式（分房/分組）
    @State private var selectingMode: SelectingMode? = nil
    @State private var anchorMember: TourMember? = nil
    @State private var selectedPeople: Set<UUID> = []

    // 匯入導航
    @State private var showingImport = false

    var members: [TourMember] {
        allMembers.filter { $0.teamID == team.id }
    }

    var sortedMembers: [TourMember] {
        members.sorted { a, b in
            let result = sortField.compare(a, b, team: team)
            return sortAscending ? result : !result
        }
    }

    var isInSpecialMode: Bool { isEditing || selectingMode != nil }

    var allSelected: Bool {
        !members.isEmpty && selectedForDelete.count == members.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // 選人模式提示條
                if let mode = selectingMode {
                    selectionBanner(mode: mode)
                }

                // 編輯模式全選 bar
                if isEditing {
                    selectAllBar
                }

                List {
                    ForEach(sortedMembers) { member in
                        memberRow(member)
                            .listRowBackground(rowBackground(for: member))
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .animation(.default, value: sortedMembers.map(\.id))
            }

            // 編輯模式底部刪除按鈕
            if isEditing && !selectedForDelete.isEmpty {
                deleteBar
            }
        }
        .navigationTitle("團員名單（\(members.count) 人）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $showingImport) {
            TourMemberSourceView(team: team)
        }
        .confirmationDialog(
            "刪除所選 \(selectedForDelete.count) 位團員？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                members.filter { selectedForDelete.contains($0.id) }
                       .forEach { modelContext.delete($0) }
                selectedForDelete = []
                isEditing = false
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作無法復原")
        }
    }

    // MARK: - Row 背景色

    private func rowBackground(for member: TourMember) -> some View {
        Color("AppCard")
    }

    // MARK: - Row

    @ViewBuilder
    private func memberRow(_ member: TourMember) -> some View {
        let seqNo = String(format: "%02d", member.sortOrder + 1)

        if isEditing {
            Button {
                toggleDeleteSelection(member)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedForDelete.contains(member.id)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedForDelete.contains(member.id)
                                         ? Color("AppAccent") : Color(.systemGray3))
                        .font(.title3)
                    leftBadge(seqNo: seqNo, member: member)
                    MemberRowContent(member: member, team: team)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

        } else if let mode = selectingMode {
            let isAnchor = member.id == anchorMember?.id
            let isDisabled = !isAnchor && isAlreadyAssigned(member, mode: mode)
            let isSelected = isAnchor || selectedPeople.contains(member.id)

            Button {
                if !isAnchor && !isDisabled {
                    togglePeopleSelection(member)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(
                            isDisabled ? Color(.systemGray4) :
                            isSelected ? Color("AppAccent") : Color(.systemGray3)
                        )
                        .font(.title3)
                    leftBadge(seqNo: seqNo, member: member)
                    MemberRowContent(member: member, team: team)
                        .opacity(isDisabled ? 0.35 : 1)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(isAnchor)

        } else {
            NavigationLink {
                TourMemberDetailView(member: member, team: team)
            } label: {
                HStack(spacing: 10) {
                    leftBadge(seqNo: seqNo, member: member)
                    MemberRowContent(member: member, team: team)
                }
                .padding(.vertical, 6)
            }
            .contextMenu {
                contextMenuItems(for: member)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    modelContext.delete(member)
                } label: {
                    Label("刪除", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - 左側徽章（序號 + 警示 icon）

    private func leftBadge(seqNo: String, member: TourMember) -> some View {
        VStack(spacing: 3) {
            Text(seqNo)
                .font(.caption2)
                .foregroundStyle(Color(.systemGray))

            if member.passportWarning(returnDate: team.returnDate) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            if member.isDraftAge(departureDate: team.departureDate) {
                Image(systemName: "figure.stand")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if member.hasBirthdayOnTrip(departureDate: team.departureDate, returnDate: team.returnDate) {
                Image(systemName: "gift.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "E8650A"))
            }
        }
        .frame(width: 28)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for member: TourMember) -> some View {
        let hasRoom = member.roomLabel != nil
        let hasGroup = member.groupLabel != nil

        if hasRoom {
            Button {
                startSelecting(mode: .addRoommate, anchor: member)
            } label: {
                Label("增加室友", systemImage: "bed.double")
            }
            Button(role: .destructive) {
                member.roomLabel = nil
            } label: {
                Label("取消分房", systemImage: "xmark.circle")
            }
        } else {
            Button {
                startSelecting(mode: .setRoom, anchor: member)
            } label: {
                Label("設定分房", systemImage: "bed.double")
            }
            Button {
                assignSingleRoom(member)
            } label: {
                Label("單人房", systemImage: "person.crop.square")
            }
        }

        Divider()

        if hasGroup {
            Button {
                startSelecting(mode: .addGroupMember, anchor: member)
            } label: {
                Label("增加組員", systemImage: "person.2.circle")
            }
            Button(role: .destructive) {
                member.groupLabel = nil
            } label: {
                Label("取消分組", systemImage: "xmark.circle")
            }
        } else {
            Button {
                startSelecting(mode: .setGroup, anchor: member)
            } label: {
                Label("設定分組", systemImage: "person.2.circle")
            }
        }
    }

    // MARK: - 選人模式 Banner

    private func selectionBanner(mode: SelectingMode) -> some View {
        HStack {
            Image(systemName: mode.icon)
                .foregroundStyle(Color("AppAccent"))
            Text(mode.prompt)
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text("已選 \(selectedPeople.count + 1) 人")
                .font(.caption)
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color("AppCard"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - 全選 Bar

    private var selectAllBar: some View {
        Button {
            if allSelected {
                selectedForDelete = []
            } else {
                selectedForDelete = Set(members.map(\.id))
            }
        } label: {
            HStack {
                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(allSelected ? Color("AppAccent") : Color(.systemGray3))
                Text(allSelected ? "取消全選" : "全選")
                    .font(.subheadline)
                    .foregroundStyle(Color("AppAccent"))
                Spacer()
                if !selectedForDelete.isEmpty {
                    Text("已選 \(selectedForDelete.count) 人")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color("AppCard"))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - 底部刪除 Bar

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Text("刪除 \(selectedForDelete.count) 位團員")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(Color("AppCard"))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selectingMode != nil {
                HStack(spacing: 16) {
                    Button("取消") { cancelSelecting() }
                        .foregroundStyle(Color(.systemGray))
                    Button("確定") { confirmSelecting() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AppAccent"))
                }
            } else if isEditing {
                Button("完成") {
                    isEditing = false
                    selectedForDelete = []
                }
                .foregroundStyle(Color("AppAccent"))
            } else {
                Menu {
                    Section("排序") {
                        ForEach(MemberSortField.allCases, id: \.self) { field in
                            Button {
                                if sortField == field {
                                    sortAscending.toggle()
                                } else {
                                    sortField = field
                                    sortAscending = true
                                }
                            } label: {
                                if sortField == field {
                                    Label(
                                        field.displayName + (sortAscending ? "（升冪）" : "（降冪）"),
                                        systemImage: sortAscending ? "chevron.up" : "chevron.down"
                                    )
                                } else {
                                    Text(field.displayName)
                                }
                            }
                        }
                    }

                    Section("操作") {
                        Button {
                            showingImport = true
                        } label: {
                            Label("匯入名單", systemImage: "square.and.arrow.down")
                        }

                        if !members.isEmpty {
                            Button {
                                isEditing = true
                            } label: {
                                Label("編輯名單", systemImage: "pencil")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
    }

    // MARK: - 分房分組邏輯

    private func startSelecting(mode: SelectingMode, anchor: TourMember) {
        isEditing = false
        selectedForDelete = []
        selectingMode = mode
        anchorMember = anchor
        selectedPeople = []
    }

    private func cancelSelecting() {
        selectingMode = nil
        anchorMember = nil
        selectedPeople = []
    }

    private func togglePeopleSelection(_ member: TourMember) {
        if selectedPeople.contains(member.id) {
            selectedPeople.remove(member.id)
        } else {
            selectedPeople.insert(member.id)
        }
    }

    private func toggleDeleteSelection(_ member: TourMember) {
        if selectedForDelete.contains(member.id) {
            selectedForDelete.remove(member.id)
        } else {
            selectedForDelete.insert(member.id)
        }
    }

    private func isAlreadyAssigned(_ member: TourMember, mode: SelectingMode) -> Bool {
        switch mode {
        case .setRoom, .addRoommate:     return member.roomLabel != nil
        case .setGroup, .addGroupMember: return member.groupLabel != nil
        }
    }

    private func confirmSelecting() {
        guard let mode = selectingMode, let anchor = anchorMember else { return }
        let allSelected = members.filter { $0.id == anchor.id || selectedPeople.contains($0.id) }

        switch mode {
        case .setRoom:
            let label = nextRoomLabel()
            allSelected.forEach { $0.roomLabel = label }
        case .addRoommate:
            let label = anchor.roomLabel ?? nextRoomLabel()
            allSelected.forEach { $0.roomLabel = label }
        case .setGroup:
            let label = nextGroupLabel()
            allSelected.forEach { $0.groupLabel = label }
        case .addGroupMember:
            let label = anchor.groupLabel ?? nextGroupLabel()
            allSelected.forEach { $0.groupLabel = label }
        }

        cancelSelecting()
    }

    private func assignSingleRoom(_ member: TourMember) {
        member.roomLabel = nextRoomLabel()
    }

    private func nextRoomLabel() -> String {
        let used = Set(members.compactMap { $0.roomLabel })
        for i in 1...99 {
            let label = String(format: "%02d", i)
            if !used.contains(label) { return label }
        }
        return "??"
    }

    private func nextGroupLabel() -> String {
        let used = Set(members.compactMap { $0.groupLabel })
        for i in 0..<26 {
            let label = String(UnicodeScalar(65 + i)!)
            if !used.contains(label) { return label }
        }
        return "?"
    }
}

// MARK: - SelectingMode

enum SelectingMode {
    case setRoom, addRoommate, setGroup, addGroupMember

    var prompt: String {
        switch self {
        case .setRoom, .addRoommate:     return "請選擇同房旅客"
        case .setGroup, .addGroupMember: return "請選擇同組旅客"
        }
    }

    var icon: String {
        switch self {
        case .setRoom, .addRoommate:     return "bed.double"
        case .setGroup, .addGroupMember: return "person.2.circle"
        }
    }
}

// MARK: - MemberSortField

enum MemberSortField: String, CaseIterable {
    case original, room, group, birthday

    var displayName: String {
        switch self {
        case .original: return "原始"
        case .room:     return "分房"
        case .group:    return "組別"
        case .birthday: return "年齡"
        }
    }

    func compare(_ a: TourMember, _ b: TourMember, team: Team) -> Bool {
        switch self {
        case .original:
            return a.sortOrder < b.sortOrder
        case .room:
            let r0 = a.roomLabel ?? "zzz"
            let r1 = b.roomLabel ?? "zzz"
            return r0 == r1 ? a.sortOrder < b.sortOrder : r0 < r1
        case .group:
            let g0 = a.groupLabel ?? "zzz"
            let g1 = b.groupLabel ?? "zzz"
            return g0 == g1 ? a.sortOrder < b.sortOrder : g0 < g1
        case .birthday:
            switch (a.birthday, b.birthday) {
            case (nil, nil): return a.sortOrder < b.sortOrder
            case (nil, _):   return false
            case (_, nil):   return true
            case let (da?, db?): return da < db
            }
        }
    }
}

// MARK: - MemberRowContent

struct MemberRowContent: View {
    let member: TourMember
    let team: Team

    var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一列：姓名 + 性別 + 年齡
            HStack(spacing: 6) {
                if let zh = member.nameZH, !zh.isEmpty {
                    Text(zh)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(member.nameEN)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                } else {
                    Text(member.nameEN)
                        .font(.subheadline).fontWeight(.semibold)
                }
                if let gender = member.gender {
                    Text(gender)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(gender == "M" ? Color.blue.opacity(0.1) : Color.pink.opacity(0.1))
                        .foregroundStyle(gender == "M" ? Color.blue : Color.pink)
                        .clipShape(Capsule())
                }
                if let age = member.age(at: team.departureDate) {
                    Text("\(age)歲")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .foregroundStyle(Color(.systemGray))
                        .clipShape(Capsule())
                }
            }

            // 第二列：護照號碼 + 效期
            HStack(spacing: 8) {
                if let no = member.passportNumber {
                    Text(no)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
                if let expiry = member.passportExpiry {
                    Text("效期 \(dateFormatter.string(from: expiry))")
                        .font(.caption)
                        .foregroundStyle(
                            member.passportWarning(returnDate: team.returnDate)
                            ? .red : Color(.systemGray)
                        )
                }
            }

            // 第三列：房號 + 分組
            let hasRoom = member.roomLabel != nil && !(member.roomLabel!.isEmpty)
            let hasGroup = member.groupLabel != nil && !(member.groupLabel!.isEmpty)
            if hasRoom || hasGroup {
                HStack(spacing: 8) {
                    if let room = member.roomLabel, !room.isEmpty {
                        Label(room, systemImage: "bed.double")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    }
                    if let group = member.groupLabel, !group.isEmpty {
                        Label(group, systemImage: "person.2.circle")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "A06CD5"))
                    }
                }
            }

            // 第四列：備註（完整顯示）
            if let remark = member.remark, !remark.isEmpty {
                Text(remark)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "E8650A"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
