import SwiftUI
import SwiftData

struct TeamArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.departureDate, order: .reverse) private var allTeams: [Team]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDesc

    enum SortOrder: String, CaseIterable {
        case dateDesc = "出發日期（新→舊）"
        case dateAsc = "出發日期（舊→新）"
        case nameAsc = "團名（A→Z）"
    }

    var finishedTeams: [Team] {
        let filtered = allTeams.filter { $0.status == .finished }
        let searched = searchText.isEmpty ? filtered : filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tourCode.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOrder {
        case .dateDesc:
            return searched.sorted { $0.departureDate > $1.departureDate }
        case .dateAsc:
            return searched.sorted { $0.departureDate < $1.departureDate }
        case .nameAsc:
            return searched.sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if finishedTeams.isEmpty && searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.title)
                            .foregroundStyle(Color("AppAccent").opacity(0.4))
                        Text("尚無已結團紀錄")
                            .font(.title3).fontWeight(.semibold)
                        Text("結團後的行程會顯示在這裡")
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if finishedTeams.isEmpty {
                                ContentUnavailableView.search(text: searchText)
                                    .padding(.top, 60)
                            } else {
                                HStack {
                                    Text("共 \(finishedTeams.count) 筆")
                                        .font(.footnote)
                                        .foregroundStyle(Color(.systemGray))
                                    Spacer()
                                }
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                                .padding(.horizontal, 2)

                                ForEach(finishedTeams) { team in
                                    NavigationLink {
                                        TeamWorkspaceView(team: team)
                                    } label: {
                                        TeamRowView(team: team)
                                            .contentShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.bottom, 10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("紀錄")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜尋團名、團號")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            }
        }
    }
}
