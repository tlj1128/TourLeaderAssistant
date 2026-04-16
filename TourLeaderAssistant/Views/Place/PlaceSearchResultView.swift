import SwiftUI
import SwiftData

struct PlaceSearchResultView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var previews: PlaceSearchPreviews
    var isSearching: Bool
    /// 只顯示特定類別（nil = 全部顯示）
    var filterType: PlaceCategoryType? = nil
    /// 是否顯示 Section 標題
    var showSectionHeaders: Bool = true

    private var visibleHotels: [PlaceSearchPreview] {
        guard filterType == nil || filterType == .hotel else { return [] }
        return previews.hotels
    }
    private var visibleRestaurants: [PlaceSearchPreview] {
        guard filterType == nil || filterType == .restaurant else { return [] }
        return previews.restaurants
    }
    private var visibleAttractions: [PlaceSearchPreview] {
        guard filterType == nil || filterType == .attraction else { return [] }
        return previews.attractions
    }

    private var hasAny: Bool {
        !visibleHotels.isEmpty || !visibleRestaurants.isEmpty || !visibleAttractions.isEmpty
    }

    var body: some View {
        List {
            if !hasAny && !isSearching {
                ContentUnavailableView(
                    "沒有搜尋結果",
                    systemImage: "magnifyingglass",
                    description: Text("試試其他關鍵字")
                )
            } else {
                if !visibleHotels.isEmpty {
                    if showSectionHeaders {
                        Section(header: Label("飯店", systemImage: "bed.double")) {
                            ForEach(visibleHotels) { preview in
                                hotelRow(preview)
                            }
                        }
                    } else {
                        Section {
                            ForEach(visibleHotels) { preview in
                                hotelRow(preview)
                            }
                        }
                    }
                }

                if !visibleRestaurants.isEmpty {
                    if showSectionHeaders {
                        Section(header: Label("餐廳", systemImage: "fork.knife")) {
                            ForEach(visibleRestaurants) { preview in
                                restaurantRow(preview)
                            }
                        }
                    } else {
                        Section {
                            ForEach(visibleRestaurants) { preview in
                                restaurantRow(preview)
                            }
                        }
                    }
                }

                if !visibleAttractions.isEmpty {
                    if showSectionHeaders {
                        Section(header: Label("景點", systemImage: "camera")) {
                            ForEach(visibleAttractions) { preview in
                                attractionRow(preview)
                            }
                        }
                    } else {
                        Section {
                            ForEach(visibleAttractions) { preview in
                                attractionRow(preview)
                            }
                        }
                    }
                }

                if isSearching {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text("搜尋雲端資料中…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
    }

    // MARK: - Row

    @ViewBuilder
    private func hotelRow(_ preview: PlaceSearchPreview) -> some View {
        if preview.isLocal {
            NavigationLink {
                localHotelDetail(preview: preview)
            } label: {
                PlaceSearchRowView(preview: preview, isNavigable: true) { id in
                    markDownloaded(id: id, in: \.hotels)
                }
            }
        } else {
            PlaceSearchRowView(preview: preview, isNavigable: false) { id in
                markDownloaded(id: id, in: \.hotels)
            }
        }
    }

    @ViewBuilder
    private func restaurantRow(_ preview: PlaceSearchPreview) -> some View {
        if preview.isLocal {
            NavigationLink {
                localRestaurantDetail(preview: preview)
            } label: {
                PlaceSearchRowView(preview: preview, isNavigable: true) { id in
                    markDownloaded(id: id, in: \.restaurants)
                }
            }
        } else {
            PlaceSearchRowView(preview: preview, isNavigable: false) { id in
                markDownloaded(id: id, in: \.restaurants)
            }
        }
    }

    @ViewBuilder
    private func attractionRow(_ preview: PlaceSearchPreview) -> some View {
        if preview.isLocal {
            NavigationLink {
                localAttractionDetail(preview: preview)
            } label: {
                PlaceSearchRowView(preview: preview, isNavigable: true) { id in
                    markDownloaded(id: id, in: \.attractions)
                }
            }
        } else {
            PlaceSearchRowView(preview: preview, isNavigable: false) { id in
                markDownloaded(id: id, in: \.attractions)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func localHotelDetail(preview: PlaceSearchPreview) -> some View {
        let localID = preview.localID
        let localDescriptor = FetchDescriptor<PlaceHotel>(predicate: #Predicate { $0.id == localID })
        if let hotel = try? modelContext.fetch(localDescriptor).first {
            HotelDetailView(hotel: hotel)
        } else if let remoteID = preview.remoteID {
            let remoteDescriptor = FetchDescriptor<PlaceHotel>(predicate: #Predicate { $0.remoteID == remoteID })
            if let hotel = try? modelContext.fetch(remoteDescriptor).first {
                HotelDetailView(hotel: hotel)
            } else {
                ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
            }
        } else {
            ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func localRestaurantDetail(preview: PlaceSearchPreview) -> some View {
        let localID = preview.localID
        let localDescriptor = FetchDescriptor<PlaceRestaurant>(predicate: #Predicate { $0.id == localID })
        if let restaurant = try? modelContext.fetch(localDescriptor).first {
            RestaurantDetailView(restaurant: restaurant)
        } else if let remoteID = preview.remoteID {
            let remoteDescriptor = FetchDescriptor<PlaceRestaurant>(predicate: #Predicate { $0.remoteID == remoteID })
            if let restaurant = try? modelContext.fetch(remoteDescriptor).first {
                RestaurantDetailView(restaurant: restaurant)
            } else {
                ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
            }
        } else {
            ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func localAttractionDetail(preview: PlaceSearchPreview) -> some View {
        let localID = preview.localID
        let localDescriptor = FetchDescriptor<PlaceAttraction>(predicate: #Predicate { $0.id == localID })
        if let attraction = try? modelContext.fetch(localDescriptor).first {
            AttractionDetailView(attraction: attraction)
        } else if let remoteID = preview.remoteID {
            let remoteDescriptor = FetchDescriptor<PlaceAttraction>(predicate: #Predicate { $0.remoteID == remoteID })
            if let attraction = try? modelContext.fetch(remoteDescriptor).first {
                AttractionDetailView(attraction: attraction)
            } else {
                ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
            }
        } else {
            ContentUnavailableView("資料不存在", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - 下載完成後更新 searchPreviews（直接回寫到 binding）

    private func markDownloaded(id: UUID, in keyPath: WritableKeyPath<PlaceSearchPreviews, [PlaceSearchPreview]>) {
        if let idx = previews[keyPath: keyPath].firstIndex(where: { $0.id == id }) {
            previews[keyPath: keyPath][idx].isLocal = true
            previews[keyPath: keyPath][idx].localNeedsSync = false
        }
    }
}
