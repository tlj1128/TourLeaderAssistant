import SwiftUI
import SwiftData

struct CountryManagementView: View {
    @Query(sort: \Country.nameZH) private var countries: [Country]
    @State private var searchText = ""

    var filtered: [Country] {
        if searchText.isEmpty { return countries }
        return countries.filter {
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { country in
                NavigationLink(destination: CityManagementView(country: country)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.nameZH)
                            .font(.headline)
                        Text("\(country.nameEN) · \(country.code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("國家與城市管理")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "搜尋國家")
    }
}
