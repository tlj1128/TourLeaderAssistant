import SwiftUI
import SwiftData

struct AttractionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceAttraction.nameEN) private var attractions: [PlaceAttraction]

    let searchText: String

    var filtered: [PlaceAttraction] {
        if searchText.isEmpty { return attractions }
        return attractions.filter {
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.city?.displayName.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "尚無景點資料" : "找不到符合的景點",
                    systemImage: "camera",
                    description: Text(searchText.isEmpty ? "點右上角 ＋ 新增第一筆" : "試試其他關鍵字")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { attraction in
                    NavigationLink(destination: AttractionDetailView(attraction: attraction)) {
                        AttractionRowView(attraction: attraction)
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
                NavigationLink(destination: AddAttractionView()) {
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

struct AttractionRowView: View {
    let attraction: PlaceAttraction

    var phoneDisplay: String? {
        guard !attraction.phone.isEmpty else { return nil }
        let code = attraction.city?.country?.phoneCode ?? ""
        return code.isEmpty ? attraction.phone : "\(code) \(attraction.phone)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 英文名稱（主）
            Text(attraction.nameEN)
                .font(.body).fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 中文名稱（有才顯示）
            if !attraction.nameZH.isEmpty {
                Text(attraction.nameZH)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 電話（有才顯示）
            if let phone = phoneDisplay {
                Text(phone)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 國旗 + 國家（英文）+ 城市（英文）
            if let city = attraction.city {
                HStack(spacing: 4) {
                    if let code = city.country?.code {
                        Text(code.flag)
                            .font(.footnote)
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
