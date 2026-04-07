import SwiftUI
import SwiftData

struct PlaceLibraryView: View {
    @State private var selectedTab: PlaceType = .hotel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("地點類型", selection: $selectedTab) {
                        ForEach(PlaceType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    switch selectedTab {
                    case .hotel:
                        HotelListView(searchText: searchText)
                    case .restaurant:
                        RestaurantListView(searchText: searchText)
                    case .attraction:
                        AttractionListView(searchText: searchText)
                    }
                }
            }
            .navigationTitle("地點庫")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜尋地點名稱")
        }
    }
}

enum PlaceType: String, CaseIterable, Identifiable {
    case hotel, restaurant, attraction
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hotel: return "飯店"
        case .restaurant: return "餐廳"
        case .attraction: return "景點"
        }
    }

    var icon: String {
        switch self {
        case .hotel: return "bed.double"
        case .restaurant: return "fork.knife"
        case .attraction: return "camera"
        }
    }
}
