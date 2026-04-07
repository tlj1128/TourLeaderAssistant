import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allTeams: [Team]
    @Query private var allIncomes: [Income]

    var finishedTeams: [Team] {
        allTeams.filter { $0.status == .finished }
    }

    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var teamsThisYear: [Team] {
        finishedTeams.filter {
            Calendar.current.component(.year, from: $0.departureDate) == currentYear
        }
    }

    var totalDaysThisYear: Int {
        teamsThisYear.reduce(0) { $0 + $1.days }
    }

    var allTimeDays: Int {
        finishedTeams.reduce(0) { $0 + $1.days }
    }

    // 今年收入
    var incomesThisYear: [Income] {
        allIncomes.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }
    }

    // 今年收入依幣種分組，每組內再依類型分組
    var incomesByCurrency: [(currency: String, byType: [(type: String, total: Decimal)])] {
        let byCurrency = Dictionary(grouping: incomesThisYear) { $0.currency }
        return byCurrency
            .map { currency, incomes in
                let byType = Dictionary(grouping: incomes) { $0.typeName }
                let typeRows = byType
                    .map { name, items in
                        (type: name, total: items.reduce(Decimal(0)) { $0 + $1.amount })
                    }
                    .sorted { $0.type < $1.type }
                return (currency: currency, byType: typeRows)
            }
            .sorted { $0.currency < $1.currency }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // 年度統計
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(currentYear) 年度")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color(.systemGray))
                                .padding(.horizontal, 2)

                            HStack(spacing: 12) {
                                StatCard(
                                    icon: "airplane.departure",
                                    title: "帶團次數",
                                    value: "\(teamsThisYear.count)",
                                    unit: "團"
                                )
                                StatCard(
                                    icon: "moon.stars",
                                    title: "帶團天數",
                                    value: "\(totalDaysThisYear)",
                                    unit: "天"
                                )
                            }
                        }

                        // 累計統計
                        VStack(alignment: .leading, spacing: 12) {
                            Text("累計至今")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color(.systemGray))
                                .padding(.horizontal, 2)

                            HStack(spacing: 12) {
                                StatCard(
                                    icon: "flag.checkered",
                                    title: "完成團次",
                                    value: "\(finishedTeams.count)",
                                    unit: "團"
                                )
                                StatCard(
                                    icon: "clock.fill",
                                    title: "總帶團天數",
                                    value: "\(allTimeDays)",
                                    unit: "天"
                                )
                            }
                        }

                        // 收入統計
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(currentYear) 年度收入")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color(.systemGray))
                                .padding(.horizontal, 2)

                            if incomesThisYear.isEmpty {
                                HStack {
                                    Image(systemName: "banknote")
                                        .foregroundStyle(Color(.systemGray3))
                                    Text("尚無收入記錄")
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.systemGray3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("AppCard"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(incomesByCurrency, id: \.currency) { group in
                                        IncomeCurrencyCard(
                                            currency: group.currency,
                                            byType: group.byType
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - IncomeCurrencyCard

private struct IncomeCurrencyCard: View {
    let currency: String
    let byType: [(type: String, total: Decimal)]

    var grandTotal: Decimal {
        byType.reduce(Decimal(0)) { $0 + $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 幣種 + 合計
            HStack(alignment: .lastTextBaseline) {
                Text(currency)
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray))
                Spacer()
                Text(grandTotal.formatted(.number.precision(.fractionLength(0))))
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            Divider()

            // 各類型明細
            ForEach(byType, id: \.type) { row in
                HStack {
                    Text(row.type)
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                    Spacer()
                    Text(row.total.formatted(.number.precision(.fractionLength(0))))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color("AppAccent"))

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray))
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(Color(.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("AppCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
