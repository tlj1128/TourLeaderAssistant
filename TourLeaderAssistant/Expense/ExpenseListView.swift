import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allExpenses: [Expense]
    @Query private var allFunds: [TourFund]

    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense? = nil

    var teamFunds: [TourFund] {
        allFunds.filter { $0.teamID == team.id }
    }

    var pettyCash: TourFund? {
        teamFunds.first { $0.fundType == .pettyCash }
    }

    var expenses: [Expense] {
        allExpenses
            .filter { $0.teamID == team.id }
            .sorted { $0.date > $1.date }
    }

    var totalConverted: Decimal {
        expenses.reduce(0) { $0 + $1.convertedAmount }
    }

    var balance: Decimal {
        (pettyCash?.initialAmount ?? 0) - totalConverted
    }

    var groupedExpenses: [(Date, [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            // 總覽
            Section {
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "已支出",
                        value: "\(pettyCash?.currency ?? "") \(totalConverted.formatted(.number.precision(.fractionLength(2))))",
                        subtitle: "共 \(expenses.count) 筆"
                    )
                    if let fund = pettyCash {
                        SummaryCard(
                            title: "零用金餘額",
                            value: "\(fund.currency) \(balance.formatted(.number.precision(.fractionLength(2))))",
                            subtitle: "初始 \(fund.initialAmount.formatted(.number.precision(.fractionLength(2))))"
                        )
                    } else {
                        SummaryCard(
                            title: "零用金餘額",
                            value: "-",
                            subtitle: "尚未設定"
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if expenses.isEmpty {
                ContentUnavailableView(
                    "尚無帳務記錄",
                    systemImage: "doc.text",
                    description: Text("點右上角 + 新增第一筆支出")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedExpenses, id: \.0) { date, dayExpenses in
                    Section {
                        ForEach(dayExpenses) { expense in
                            ExpenseRowView(expense: expense)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExpense = expense
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(expense)
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                            Text("第\(dayNumber(for: date))天")
                            Spacer()
                            Text(dayTotal(for: dayExpenses))
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("帳務紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(team: team)
        }
        .sheet(item: $selectedExpense) { expense in
            EditExpenseView(expense: expense)
        }
    }

    private func dayNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let departure = calendar.startOfDay(for: team.departureDate)
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: departure, to: day)
        return (components.day ?? 0) + 1
    }

    private func dayTotal(for expenses: [Expense]) -> String {
        let total = expenses.reduce(Decimal(0)) { $0 + $1.convertedAmount }
        let currency = pettyCash?.currency ?? expenses.first?.currency ?? ""
        return "\(currency) \(total.formatted(.number.precision(.fractionLength(2))))"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ExpenseRowView: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.item)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let location = expense.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let receipt = expense.receiptNumber {
                        Text("收據 #\(receipt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(expense.currency) \(expense.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("×\(expense.quantity.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
