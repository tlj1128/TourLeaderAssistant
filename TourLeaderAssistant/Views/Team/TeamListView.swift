import SwiftUI
import SwiftData

struct TeamListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.departureDate) private var teams: [Team]
    @State private var showingAddTeam = false

    var inProgressTeams: [Team] {
        teams.filter { $0.status == .inProgress }
    }

    var preparingTeams: [Team] {
        teams.filter { $0.status == .preparing }
    }

    var pendingCloseTeams: [Team] {
        teams.filter { $0.status == .pendingClose }
    }

    var finishedTeams: [Team] {
        teams.filter { $0.status == .finished }
    }

    var body: some View {
        NavigationStack {
            List {
                if !inProgressTeams.isEmpty {
                    Section("進行中") {
                        ForEach(inProgressTeams) { team in
                            NavigationLink {
                                TeamWorkspaceView(team: team)
                            } label: {
                                TeamRowView(team: team)
                            }
                        }
                        .onDelete { indexSet in
                            deleteTeams(from: inProgressTeams, at: indexSet)
                        }
                    }
                }
                
                if !pendingCloseTeams.isEmpty {
                    Section("待結團") {
                        ForEach(pendingCloseTeams) { team in
                            NavigationLink {
                                TeamWorkspaceView(team: team)
                            } label: {
                                TeamRowView(team: team)
                            }
                        }
                        .onDelete { indexSet in
                            deleteTeams(from: pendingCloseTeams, at: indexSet)
                        }
                    }
                }

                if !preparingTeams.isEmpty {
                    Section("準備中") {
                        ForEach(preparingTeams) { team in
                            NavigationLink {
                                TeamWorkspaceView(team: team)
                            } label: {
                                TeamRowView(team: team)
                            }
                        }
                        .onDelete { indexSet in
                            deleteTeams(from: preparingTeams, at: indexSet)
                        }
                    }
                }

                if !finishedTeams.isEmpty {
                    Section("已結團") {
                        ForEach(finishedTeams) { team in
                            NavigationLink {
                                TeamWorkspaceView(team: team)
                            } label: {
                                TeamRowView(team: team)
                                    .opacity(0.5)
                            }
                        }
                        .onDelete { indexSet in
                            deleteTeams(from: finishedTeams, at: indexSet)
                        }
                    }
                }

                if teams.isEmpty {
                    ContentUnavailableView(
                        "尚無團體",
                        systemImage: "rectangle.grid.2x2",
                        description: Text("點右上角 + 新增第一個團體")
                    )
                }
            }
            .navigationTitle("我的團體")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTeam) {
                AddTeamView()
            }
            .onAppear {
                updateTeamStatuses()
            }
        }
    }
    
    private func deleteTeams(from list: [Team], at indexSet: IndexSet) {
        for index in indexSet {
            let team = list[index]
            CalendarManager.shared.removeEvent(for: team) 
            modelContext.delete(team)
        }
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
