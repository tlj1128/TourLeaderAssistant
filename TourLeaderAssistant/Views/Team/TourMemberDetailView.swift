import SwiftUI
import SwiftData

struct TourMemberDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var member: TourMember
    let team: Team

    @State private var showingDeleteConfirm = false

    var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            Form {
                // ── 警示區（有警示才顯示）──
                let hasPassportWarning = member.passportWarning(returnDate: team.returnDate)
                let hasDraftWarning = member.isDraftAge(departureDate: team.departureDate)
                let hasBirthday = member.hasBirthdayOnTrip(
                    departureDate: team.departureDate,
                    returnDate: team.returnDate
                )

                if hasPassportWarning || hasDraftWarning || hasBirthday {
                    Section {
                        if hasPassportWarning {
                            Label("護照效期不足（回國後未滿6個月）",
                                  systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        }
                        if hasDraftWarning {
                            Label("役男（18–36歲男性，請確認出境許可）",
                                  systemImage: "figure.stand")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                        }
                        if hasBirthday {
                            Label("行程中有生日！",
                                  systemImage: "gift.fill")
                                .foregroundStyle(Color(hex: "E8650A"))
                                .font(.subheadline)
                        }
                    } header: {
                        Text("注意事項")
                    }
                    .listRowBackground(Color("AppCard"))
                }

                // ── 基本資料 ──
                Section("基本資料") {
                    LabeledTextField(label: "英文姓名", placeholder: "LASTNAME,FIRSTNAME", text: $member.nameEN)

                    HStack {
                        Text("中文姓名")
                            .frame(width: 100, alignment: .leading)
                        TextField("選填", text: Binding(
                            get: { member.nameZH ?? "" },
                            set: { member.nameZH = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }

                    Picker("性別", selection: Binding(
                        get: { member.gender ?? "" },
                        set: { member.gender = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未知").tag("")
                        Text("男 M").tag("M")
                        Text("女 F").tag("F")
                    }

                    if let bday = member.birthday {
                        HStack {
                            Text("生日")
                                .frame(width: 100, alignment: .leading)
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { bday },
                                    set: { member.birthday = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                    } else {
                        Button("新增生日") {
                            member.birthday = Calendar.current.date(
                                byAdding: .year, value: -30, to: Date()
                            )
                        }
                        .foregroundStyle(Color("AppAccent"))
                    }
                }
                .listRowBackground(Color("AppCard"))

                // ── 護照 ──
                Section("護照") {
                    HStack {
                        Text("護照號碼")
                            .frame(width: 100, alignment: .leading)
                        TextField("選填", text: Binding(
                            get: { member.passportNumber ?? "" },
                            set: { member.passportNumber = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                    }

                    if let expiry = member.passportExpiry {
                        HStack {
                            Text("效期")
                                .frame(width: 100, alignment: .leading)
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { expiry },
                                    set: { member.passportExpiry = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                        }
                    } else {
                        Button("新增護照效期") {
                            member.passportExpiry = Calendar.current.date(
                                byAdding: .year, value: 5, to: Date()
                            )
                        }
                        .foregroundStyle(Color("AppAccent"))
                    }
                }
                .listRowBackground(Color("AppCard"))

                // ── 分房 / 分組 ──
                Section("分房 / 分組") {
                    HStack {
                        Text("房間")
                            .frame(width: 100, alignment: .leading)
                        TextField("選填", text: Binding(
                            get: { member.roomLabel ?? "" },
                            set: { member.roomLabel = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("組別")
                            .frame(width: 100, alignment: .leading)
                        TextField("選填", text: Binding(
                            get: { member.groupLabel ?? "" },
                            set: { member.groupLabel = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                }
                .listRowBackground(Color("AppCard"))

                // ── 備註 ──
                Section("備註") {
                    TextField("備註", text: Binding(
                        get: { member.remark ?? "" },
                        set: { member.remark = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                }
                .listRowBackground(Color("AppCard"))

                // ── 刪除 ──
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("刪除此團員")
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color("AppCard"))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "刪除 \(member.displayName)？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive) {
                modelContext.delete(member)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }
}
