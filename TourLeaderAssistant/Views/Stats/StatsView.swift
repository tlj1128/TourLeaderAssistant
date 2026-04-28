import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allTeams: [Team]
    @Query private var allIncomes: [Income]

    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    var finishedTeams: [Team] {
        allTeams.filter { $0.status == .finished }
    }

    var years: [Int] {
        let teamYears = finishedTeams.map { Calendar.current.component(.year, from: $0.departureDate) }
        let incomeYears = allIncomes.map { Calendar.current.component(.year, from: $0.date) }
        let all = Array(Set(teamYears + incomeYears)).sorted(by: >)
        return all.isEmpty ? [currentYear] : all
    }

    var allTimeDays: Int { finishedTeams.reduce(0) { $0 + $1.days } }

    var allTimeIncomesByCurrency: [(currency: String, total: Decimal)] {
        Dictionary(grouping: allIncomes) { $0.currency }
            .map { currency, items in
                (currency: currency, total: items.reduce(Decimal(0)) { $0 + $1.amount })
            }
            .sorted { $0.currency < $1.currency }
    }

    var teamsForYear: [Team] {
        finishedTeams.filter {
            Calendar.current.component(.year, from: $0.departureDate) == selectedYear
        }
    }

    var incomesForYear: [Income] {
        allIncomes.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
    }

    var totalDaysForYear: Int { teamsForYear.reduce(0) { $0 + $1.days } }

    var incomesByCurrencyForYear: [(currency: String, byType: [(type: String, total: Decimal)], grandTotal: Decimal)] {
        Dictionary(grouping: incomesForYear) { $0.currency }
            .map { currency, items in
                let byType = Dictionary(grouping: items) { $0.typeName }
                    .map { name, rows in (type: name, total: rows.reduce(Decimal(0)) { $0 + $1.amount }) }
                    .sorted { $0.type < $1.type }
                let grandTotal = byType.reduce(Decimal(0)) { $0 + $1.total }
                return (currency: currency, byType: byType, grandTotal: grandTotal)
            }
            .sorted { $0.currency < $1.currency }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        allTimeSection

                        Divider()
                            .padding(.horizontal, 2)

                        yearSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if !years.contains(selectedYear) {
                    selectedYear = years.first ?? currentYear
                }
            }
        }
    }

    // MARK: - 累計統計

    private var allTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("累計至今")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray))
                .padding(.horizontal, 2)

            HStack(spacing: 12) {
                StatCard(icon: "flag.checkered", title: "完成團次", value: "\(finishedTeams.count)", unit: "團")
                StatCard(icon: "clock.fill", title: "總帶團天數", value: "\(allTimeDays)", unit: "天")
            }

            if !allTimeIncomesByCurrency.isEmpty {
                VStack(spacing: 8) {
                    ForEach(allTimeIncomesByCurrency, id: \.currency) { group in
                        HStack {
                            Text(group.currency)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color(.systemGray))
                            Spacer()
                            Text(group.total.formatted(.number.precision(.fractionLength(0))))
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color("AppCard"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }
                }
            }
        }
    }

    // MARK: - 年度統計

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("年度統計")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray))
                Spacer()
                Picker("年度", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(String(year)) 年").tag(year)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color("AppAccent"))
            }
            .padding(.horizontal, 2)

            HStack(spacing: 12) {
                StatCard(icon: "airplane.departure", title: "帶團次數", value: "\(teamsForYear.count)", unit: "團")
                StatCard(icon: "moon.stars", title: "帶團天數", value: "\(totalDaysForYear)", unit: "天")
            }

            if incomesForYear.isEmpty {
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
                    ForEach(incomesByCurrencyForYear, id: \.currency) { group in
                        CollapsibleIncomeCurrencyCard(
                            currency: group.currency,
                            byType: group.byType,
                            grandTotal: group.grandTotal
                        )
                    }
                }
            }
        }
    }
}

// MARK: - CollapsibleIncomeCurrencyCard

private struct CollapsibleIncomeCurrencyCard: View {
    let currency: String
    let byType: [(type: String, total: Decimal)]
    let grandTotal: Decimal

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .lastTextBaseline) {
                    Text(currency)
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundStyle(Color(.systemGray))
                    Spacer()
                    Text(grandTotal.formatted(.number.precision(.fractionLength(0))))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                        .padding(.leading, 6)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
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
            }
        }
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
