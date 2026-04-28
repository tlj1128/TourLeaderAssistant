import SwiftUI
import SwiftData

struct TourMemberPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team
    let parsedMembers: [ParsedMember]
    let onDismiss: () -> Void

    @State private var editableMembers: [ParsedMember]
    @State private var showingEditIndex: Int? = nil
    @State private var showingImportConfirm = false
    @State private var showingReplaceConfirm = false

    @Query private var allMembers: [TourMember]
    var existingMembers: [TourMember] {
        allMembers.filter { $0.teamID == team.id }
    }
    var hasExisting: Bool { !existingMembers.isEmpty }

    init(team: Team, parsedMembers: [ParsedMember], onDismiss: @escaping () -> Void) {
        self.team = team
        self.parsedMembers = parsedMembers
        self.onDismiss = onDismiss
        self._editableMembers = State(initialValue: parsedMembers)
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // 頂部摘要
                summaryBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // 列表
                List {
                    ForEach(Array(editableMembers.enumerated()), id: \.element.id) { index, member in
                        PreviewMemberRow(
                            member: member,
                            team: team
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { showingEditIndex = index }
                        .listRowBackground(Color("AppCard"))
                    }
                    .onDelete { indexSet in
                        editableMembers.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)

                // 底部確認按鈕
                importButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                    .background(Color("AppBackground"))
            }
        }
        .navigationTitle("預覽解析結果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .foregroundStyle(Color("AppAccent"))
            }
        }
        .sheet(isPresented: Binding(
                    get: { showingEditIndex != nil },
                    set: { if !$0 { showingEditIndex = nil } }
                )) {
                    if let index = showingEditIndex {
                        ParsedMemberEditView(member: $editableMembers[index])
                    }
                }
        .confirmationDialog(
            "已有 \(existingMembers.count) 筆團員資料",
            isPresented: $showingReplaceConfirm,
            titleVisibility: .visible
        ) {
            Button("覆蓋現有資料", role: .destructive) { importMembers(replace: true) }
            Button("新增到現有資料") { importMembers(replace: false) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("要覆蓋現有資料，還是新增到現有資料後面？")
        }
    }

    // MARK: - 頂部摘要

    private var summaryBanner: some View {
        HStack(spacing: 12) {
            Label("\(editableMembers.count) 位團員", systemImage: "person.2.fill")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color(hex: "A06CD5"))

            Spacer()

            let warnings = editableMembers.filter { hasWarning($0) }.count
            if warnings > 0 {
                Label("\(warnings) 項警示", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            Text("左滑可刪除")
                .font(.caption2)
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(12)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - 確認匯入按鈕

    private var importButton: some View {
        Button {
            if hasExisting {
                showingReplaceConfirm = true
            } else {
                importMembers(replace: false)
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("確認匯入 \(editableMembers.count) 位團員")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(editableMembers.isEmpty ? Color(.systemGray3) : Color(hex: "A06CD5"))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(editableMembers.isEmpty)
    }

    // MARK: - 匯入邏輯

    private func importMembers(replace: Bool) {
        if replace {
            existingMembers.forEach { modelContext.delete($0) }
        }

        for member in editableMembers {
            let newMember = TourMember(
                teamID: team.id,
                nameEN: member.nameEN,
                nameZH: member.nameZH,
                gender: member.gender,
                birthday: member.birthday,
                passportNumber: member.passportNumber,
                passportExpiry: member.passportExpiry,
                roomLabel: member.roomLabel,
                remark: member.remark,
                sortOrder: member.sortOrder
            )
            modelContext.insert(newMember)
        }

        onDismiss()
    }

    // MARK: - 警示判斷

    private func hasWarning(_ member: ParsedMember) -> Bool {
        if let expiry = member.passportExpiry {
            let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: team.returnDate) ?? team.returnDate
            if expiry < sixMonths { return true }
        }
        if let bday = member.birthday, let gender = member.gender, gender == "M" {
            let age = Calendar.current.dateComponents([.year], from: bday, to: team.departureDate).year ?? 0
            if age >= 18 && age <= 36 { return true }
        }
        return false
    }
}

// MARK: - PreviewMemberRow

struct PreviewMemberRow: View {
    let member: ParsedMember
    let team: Team

    var passportWarning: Bool {
        guard let expiry = member.passportExpiry else { return false }
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: team.returnDate) ?? team.returnDate
        return expiry < sixMonths
    }

    var isDraftAge: Bool {
        guard let bday = member.birthday, member.gender == "M" else { return false }
        let age = Calendar.current.dateComponents([.year], from: bday, to: team.departureDate).year ?? 0
        return age >= 18 && age <= 36
    }

    var hasBirthday: Bool {
        guard let bday = member.birthday else { return false }
        let cal = Calendar.current
        let components = cal.dateComponents([.month, .day], from: bday)
        guard let month = components.month, let day = components.day else { return false }
        var current = team.departureDate
        while current <= team.returnDate {
            let c = cal.dateComponents([.month, .day], from: current)
            if c.month == month && c.day == day { return true }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? team.returnDate.addingTimeInterval(86400)
        }
        return false
    }

    var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }

    var body: some View {
        HStack(spacing: 10) {
            // 警示指示
            VStack(spacing: 4) {
                if passportWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if isDraftAge {
                    Image(systemName: "figure.stand")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if hasBirthday {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "E8650A"))
                }
            }
            .frame(width: 16)

            // 主要資料
            VStack(alignment: .leading, spacing: 4) {
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
                }

                HStack(spacing: 8) {
                    if let passport = member.passportNumber {
                        Text(passport)
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    }
                    if let expiry = member.passportExpiry {
                        Text("效期 \(dateFormatter.string(from: expiry))")
                            .font(.caption)
                            .foregroundStyle(passportWarning ? .red : Color(.systemGray))
                    }
                }

                HStack(spacing: 8) {
                    if let bday = member.birthday {
                        Text(dateFormatter.string(from: bday))
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    }
                    if let room = member.roomLabel {
                        Text(room)
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    }
                    if let remark = member.remark, !remark.isEmpty {
                        Text(remark)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "E8650A"))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ParsedMemberEditView

struct ParsedMemberEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var member: ParsedMember

    @State private var nameEN: String = ""
    @State private var nameZH: String = ""
    @State private var gender: String = ""
    @State private var passportNumber: String = ""
    @State private var passportExpiry: Date = Date()
    @State private var hasExpiry: Bool = false
    @State private var birthday: Date = Date()
    @State private var hasBirthday: Bool = false
    @State private var roomLabel: String = ""
    @State private var remark: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("姓名") {
                    LabeledTextField(label: "英文", placeholder: "LASTNAME,FIRSTNAME", text: $nameEN)
                    LabeledTextField(label: "中文", placeholder: "選填", text: $nameZH)
                }

                Section("性別") {
                    Picker("性別", selection: $gender) {
                        Text("未知").tag("")
                        Text("男 M").tag("M")
                        Text("女 F").tag("F")
                    }
                    .pickerStyle(.segmented)
                }

                Section("護照") {
                    LabeledTextField(label: "護照號碼", placeholder: "選填", text: $passportNumber)
                    Toggle("有護照效期", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("效期", selection: $passportExpiry, displayedComponents: .date)
                    }
                }

                Section("生日") {
                    Toggle("有生日資料", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("生日", selection: $birthday, displayedComponents: .date)
                    }
                }

                Section("分房 / 分組") {
                    LabeledTextField(label: "房間", placeholder: "選填", text: $roomLabel)
                }

                Section("備註") {
                    TextField("備註", text: $remark, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("編輯團員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color(.systemGray))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        saveEdits()
                        dismiss()
                    }
                    .foregroundStyle(Color("AppAccent"))
                    .fontWeight(.semibold)
                }
            }
            .onAppear { loadFromMember() }
        }
    }

    private func loadFromMember() {
        nameEN = member.nameEN
        nameZH = member.nameZH ?? ""
        gender = member.gender ?? ""
        passportNumber = member.passportNumber ?? ""
        if let expiry = member.passportExpiry {
            hasExpiry = true
            passportExpiry = expiry
        }
        if let bday = member.birthday {
            hasBirthday = true
            birthday = bday
        }
        roomLabel = member.roomLabel ?? ""
        remark = member.remark ?? ""
    }

    private func saveEdits() {
        member.nameEN = nameEN
        member.nameZH = nameZH.isEmpty ? nil : nameZH
        member.gender = gender.isEmpty ? nil : gender
        member.passportNumber = passportNumber.isEmpty ? nil : passportNumber
        member.passportExpiry = hasExpiry ? passportExpiry : nil
        member.birthday = hasBirthday ? birthday : nil
        member.roomLabel = roomLabel.isEmpty ? nil : roomLabel
        member.remark = remark.isEmpty ? nil : remark
    }
}

// MARK: - IndexWrapper（sheet item 用）

struct IndexWrapper: Identifiable {
    let id = UUID()
    let index: Int
}
