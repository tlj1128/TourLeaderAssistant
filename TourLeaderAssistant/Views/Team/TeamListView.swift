import SwiftUI
import SwiftData

struct TeamListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.departureDate) private var teams: [Team]
    @State private var showingAddTeam = false
    @State private var teamToDelete: Team? = nil
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var inProgressTeams: [Team] {
        teams.filter { $0.status == .inProgress }
    }

    var preparingTeams: [Team] {
        teams.filter { $0.status == .preparing }.sorted { $0.departureDate < $1.departureDate }
    }

    var pendingCloseTeams: [Team] {
        teams.filter { $0.status == .pendingClose }
    }

    var activeTeams: [Team] {
        inProgressTeams + pendingCloseTeams + preparingTeams
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()

                if activeTeams.isEmpty {
                    emptyStateView
                } else {
                    List {
                        if !inProgressTeams.isEmpty {
                            Section {
                                ForEach(inProgressTeams) { team in
                                    teamCard(team)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                sectionHeader("進行中", icon: "airplane.departure")
                            }
                        }

                        if !pendingCloseTeams.isEmpty {
                            Section {
                                ForEach(pendingCloseTeams) { team in
                                    teamCard(team)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                sectionHeader("待結團", icon: "checkmark.circle")
                            }
                        }

                        if !preparingTeams.isEmpty {
                            Section {
                                ForEach(preparingTeams) { team in
                                    teamCard(team)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                sectionHeader("準備中", icon: "clock")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("我的團體")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            }
            .sheet(isPresented: $showingAddTeam) {
                AddTeamView()
                    .appDynamicTypeSize(textSizePreference)
            }
            .onAppear {
                updateTeamStatuses()
            }
            .alert("確定要刪除這個團體？", isPresented: Binding(
                get: { teamToDelete != nil },
                set: { if !$0 { teamToDelete = nil } }
            )) {
                Button("取消", role: .cancel) { teamToDelete = nil }
                Button("刪除", role: .destructive) {
                    if let team = teamToDelete {
                        deleteTeam(team)
                        teamToDelete = nil
                    }
                }
            } message: {
                Text("所有帳務、日誌與文件將一併刪除，此動作無法復原。")
            }
        }
    }

    // MARK: - Components

    private func teamCard(_ team: Team) -> some View {
        NavigationLink {
            TeamWorkspaceView(team: team)
        } label: {
            TeamRowView(team: team)
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                teamToDelete = team
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(Color("AppAccent"))
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .padding(.horizontal, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle")
                .font(.title)
                .foregroundStyle(Color("AppAccent").opacity(0.4))
            Text("尚無團體")
                .font(.title3).fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text("點右上角 ＋ 新增第一個團體")
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
        }
    }

    // MARK: - Logic

    private func deleteTeam(_ team: Team) {
        CalendarManager.shared.removeEvent(for: team)

        let teamID = team.id

        let expenseDesc = FetchDescriptor<Expense>(predicate: #Predicate { $0.teamID == teamID })
        (try? modelContext.fetch(expenseDesc))?.forEach { modelContext.delete($0) }

        let incomeDesc = FetchDescriptor<Income>(predicate: #Predicate { $0.teamID == teamID })
        (try? modelContext.fetch(incomeDesc))?.forEach { modelContext.delete($0) }

        let fundDesc = FetchDescriptor<TourFund>(predicate: #Predicate { $0.teamID == teamID })
        (try? modelContext.fetch(fundDesc))?.forEach { modelContext.delete($0) }

        let journalDesc = FetchDescriptor<Journal>(predicate: #Predicate { $0.teamID == teamID })
        (try? modelContext.fetch(journalDesc))?.forEach { modelContext.delete($0) }

        let docDesc = FetchDescriptor<TourDocument>(predicate: #Predicate { $0.teamID == teamID })
        (try? modelContext.fetch(docDesc))?.forEach { modelContext.delete($0) }

        modelContext.delete(team)
    }

    private func updateTeamStatuses() {
        let today = Calendar.current.startOfDay(for: Date())
        for team in teams {
            let departure = Calendar.current.startOfDay(for: team.departureDate)
            let returnDay = Calendar.current.startOfDay(for: team.returnDate)
            if team.status != .finished {
                if today >= departure && today <= returnDay {
                    team.status = .inProgress
                } else if today < departure {
                    team.status = .preparing
                } else if today > returnDay {
                    team.status = .pendingClose
                }
            }
        }
    }
}
