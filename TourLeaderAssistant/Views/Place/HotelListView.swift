import SwiftUI
import SwiftData

struct HotelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceHotel.nameEN) private var hotels: [PlaceHotel]
    @Query private var allPhotos: [PlacePhoto]

    let searchText: String

    var filtered: [PlaceHotel] {
        if searchText.isEmpty { return hotels }
        return hotels.filter {
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.city?.displayName.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    func hasBadge(_ hotel: PlaceHotel) -> Bool {
        hotel.needsSync ||
        allPhotos.contains { $0.placeID == hotel.id && ($0.needsUpload || $0.needsDelete) }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "尚無飯店資料" : "找不到符合的飯店",
                    systemImage: "bed.double",
                    description: Text(searchText.isEmpty ? "點右上角 ＋ 新增第一筆" : "試試其他關鍵字")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { hotel in
                    NavigationLink(destination: HotelDetailView(hotel: hotel)) {
                        HotelRowView(hotel: hotel, showBadge: hasBadge(hotel))
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
                NavigationLink(destination: AddHotelView()) {
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

struct HotelRowView: View {
    let hotel: PlaceHotel
    var showBadge: Bool = false

    var phoneDisplay: String? {
        guard !hotel.phone.isEmpty else { return nil }
        let code = hotel.city?.country?.phoneCode ?? ""
        return code.isEmpty ? hotel.phone : "\(code) \(hotel.phone)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(hotel.nameEN)
                    .font(.body).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if showBadge {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color("AppAccent"))
                }
            }

            if !hotel.nameZH.isEmpty {
                Text(hotel.nameZH)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let phone = phoneDisplay {
                Text(phone)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let city = hotel.city {
                HStack(spacing: 4) {
                    if let code = city.country?.code {
                        Text(code.flag).font(.footnote)
                    }
                    let countryEN = city.country?.nameEN ?? ""
                    let cityEN = city.nameEN.isEmpty ? city.nameZH : city.nameEN
                    Text(countryEN.isEmpty ? cityEN : "\(countryEN) · \(cityEN)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
