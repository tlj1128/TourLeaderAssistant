import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allExpenses: [Expense]
    @Query private var allFunds: [TourFund]

    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense? = nil
    @State private var selectedTab: ExpenseTab = .expense
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    enum ExpenseTab {
        case expense, income
    }

    var teamFunds: [TourFund] {
        allFunds.filter { $0.teamID == team.id }
    }

    var pettyCash: TourFund? {
        teamFunds.first { $0.typeName == "零用金" }
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

    var currency: String { pettyCash?.currency ?? "" }
    
    var baseCurrency: String {
        if let pettyCash = teamFunds.first(where: { $0.typeName == "零用金" }) {
            return pettyCash.currency
        }
        return teamFunds.first { $0.isReimbursable }?.currency ?? "USD"
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // 分頁切換
                Picker("", selection: $selectedTab) {
                    Text("支出").tag(ExpenseTab.expense)
                    Text("收入").tag(ExpenseTab.income)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("AppBackground"))

                if selectedTab == .expense {
                    expenseContent
                } else {
                    IncomeListView(team: team)
                }
            }
        }
        .navigationTitle("帳務紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == .expense {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(team: team, lastExpense: expenses.first, baseCurrency: baseCurrency)
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(item: $selectedExpense) { expense in
            EditExpenseView(expense: expense)
                .appDynamicTypeSize(textSizePreference)
        }
    }

    // MARK: - 支出內容

    private var expenseContent: some View {
        Group {
            if expenses.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "dollarsign.circle")
                        .font(.title)
                        .foregroundStyle(Color("AppAccent").opacity(0.4))
                    Text("尚無帳務記錄")
                        .font(.title3).fontWeight(.semibold)
                    Text("點右上角 ＋ 新增第一筆支出")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                    Spacer()
                }
            } else {
                List {
                    Section {
                        summaryCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(groupedExpenses, id: \.0) { date, dayExpenses in
                        Section {
                            ForEach(dayExpenses) { expense in
                                ExpenseRowView(expense: expense, currency: currency)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedExpense = expense }
                                    .listRowBackground(Color("AppCard"))
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
                                Text(formattedDate(date))
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundStyle(Color("AppAccent"))
                                Spacer()
                                Text(dayTotal(for: dayExpenses))
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
    }

    // MARK: - 總覽卡

    private var summaryCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("已支出")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray))
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(currency)
                        .font(.footnote)
                        .foregroundStyle(Color(.systemGray))
                    Text(totalConverted.formatted(.number.precision(.fractionLength(2))))
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                Text("共 \(expenses.count) 筆")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color("AppCard"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("零用金餘額")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray))
                if let fund = pettyCash {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(fund.currency)
                            .font(.footnote)
                            .foregroundStyle(Color(.systemGray))
                        Text(balance.formatted(.number.precision(.fractionLength(2))))
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
                    }
                    Text("初始 \(fund.initialAmount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                } else {
                    Text("—")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(Color(.systemGray3))
                    Text("尚未設定")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color("AppCard"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Helpers

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd"; return f
    }()

    private func formattedDate(_ date: Date) -> String {
        ExpenseListView.dateFmt.string(from: date)
    }

    private func dayTotal(for expenses: [Expense]) -> String {
        let total = expenses.reduce(Decimal(0)) { $0 + $1.convertedAmount }
        return "\(currency) \(total.formatted(.number.precision(.fractionLength(2))))"
    }
}

// MARK: - ExpenseRowView

struct ExpenseRowView: View {
    let expense: Expense
    var currency: String = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.item)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let location = expense.location, !location.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundStyle(Color(.systemGray))
                    }
                    if let receipt = expense.receiptNumber, !receipt.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "doc")
                                .font(.system(size: 10))
                            Text("#\(receipt)")
                                .font(.caption)
                        }
                        .foregroundStyle(Color(.systemGray))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(expense.currency)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                    Text(expense.amount.formatted(.number.precision(.fractionLength(2))))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Text("≈ \(currency) \(expense.convertedAmount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray))
            }
        }
        .padding(.vertical, 4)
    }
}
