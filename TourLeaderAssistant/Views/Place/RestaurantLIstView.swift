import SwiftUI
import SwiftData

struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceRestaurant.nameEN) private var restaurants: [PlaceRestaurant]
    @Query private var allPhotos: [PlacePhoto]

    let searchText: String

    var filtered: [PlaceRestaurant] {
        if searchText.isEmpty { return restaurants }
        return restaurants.filter {
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.city?.displayName.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    func hasBadge(_ restaurant: PlaceRestaurant) -> Bool {
        restaurant.needsSync ||
        allPhotos.contains { $0.placeID == restaurant.id && ($0.needsUpload || $0.needsDelete) }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "尚無餐廳資料" : "找不到符合的餐廳",
                    systemImage: "fork.knife",
                    description: Text(searchText.isEmpty ? "點右上角 ＋ 新增第一筆" : "試試其他關鍵字")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { restaurant in
                    NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                        RestaurantRowView(restaurant: restaurant, showBadge: hasBadge(restaurant))
                    }
                    .listRowBackground(Color("AppCard"))
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddRestaurantView()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}

struct RestaurantRowView: View {
    let restaurant: PlaceRestaurant
    var showBadge: Bool = false

    var phoneDisplay: String? {
        guard !restaurant.phone.isEmpty else { return nil }
        let code = restaurant.city?.country?.phoneCode ?? ""
        return code.isEmpty ? restaurant.phone : "\(code) \(restaurant.phone)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(restaurant.nameEN)
                    .font(.body).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if showBadge {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color("AppAccent"))
                }
            }

            if !restaurant.nameZH.isEmpty {
                Text(restaurant.nameZH)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let phone = phoneDisplay {
                Text(phone)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let city = restaurant.city {
                HStack(spacing: 4) {
                    if let code = city.country?.code {
                        Text(code.flag).font(.footnote)
                    }
                    let countryEN = city.country?.nameEN ?? ""
                    let cityEN = city.nameEN.isEmpty ? city.nameZH : city.nameEN
                    Text(countryEN.isEmpty ? cityEN : "\(countryEN) · \(cityEN)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !restaurant.cuisine.isEmpty {
                        Text("·").font(.footnote).foregroundStyle(.secondary)
                        Text(restaurant.cuisine).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
