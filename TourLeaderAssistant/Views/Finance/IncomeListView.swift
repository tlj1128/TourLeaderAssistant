import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allIncomes: [Income]
    @State private var showingAdd = false
    @State private var selectedIncome: Income? = nil
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var incomes: [Income] {
        allIncomes
            .filter { $0.teamID == team.id }
            .sorted { $0.date > $1.date }
    }

    var groupedIncomes: [(Date, [Income])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: incomes) { income in
            calendar.startOfDay(for: income.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if incomes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.title)
                        .foregroundStyle(Color("AppAccent").opacity(0.4))
                    Text("尚無收入記錄")
                        .font(.title3).fontWeight(.semibold)
                    Text("點右上角 ＋ 新增第一筆收入")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                }
            } else {
                List {
                    ForEach(groupedIncomes, id: \.0) { date, dayIncomes in
                        Section {
                            ForEach(dayIncomes) { income in
                                IncomeRowView(income: income)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedIncome = income }
                                    .listRowBackground(Color("AppCard"))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(income)
                                        } label: {
                                            Label("刪除", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text(formattedDate(date))
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundStyle(Color("AppAccent"))
                                Spacer()
                                Text(dayTotal(for: dayIncomes))
                                    .font(.footnote)
                                    .foregroundStyle(Color(.systemGray))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddIncomeView(team: team)
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(item: $selectedIncome) { income in
            EditIncomeView(income: income)
                .appDynamicTypeSize(textSizePreference)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }

    private func dayTotal(for incomes: [Income]) -> String {
        // 同幣種合計，不同幣種分開顯示
        let byCurrency = Dictionary(grouping: incomes) { $0.currency }
        return byCurrency.map { currency, items in
            let total = items.reduce(Decimal(0)) { $0 + $1.amount }
            return "\(currency) \(total.formatted(.number.precision(.fractionLength(0))))"
        }.joined(separator: "　")
    }
}

// MARK: - IncomeRowView

struct IncomeRowView: View {
    let income: Income

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: DefaultIncomeType.iconName(for: income.typeName))
                .font(.callout)
                .foregroundStyle(Color("AppAccent"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(income.typeName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let notes = income.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(income.currency)
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray))
                Text(income.amount.formatted(.number.precision(.fractionLength(0))))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}
