import SwiftUI
import SwiftData

struct TeamCountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Country.nameZH) private var allCountries: [Country]

    @Binding var selectedCodes: [String]

    @State private var searchText = ""

    var recentCountries: [Country] {
        allCountries
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var filteredCountries: [Country] {
        if searchText.isEmpty { return allCountries }
        return allCountries.filter {
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty && !recentCountries.isEmpty {
                    Section("最近使用") {
                        ForEach(recentCountries) { country in
                            CountryMultiSelectRow(
                                country: country,
                                isSelected: selectedCodes.contains(country.code),
                                onTap: { toggle(country) }
                            )
                        }
                    }
                }

                Section(searchText.isEmpty ? "所有國家" : "搜尋結果") {
                    ForEach(filteredCountries) { country in
                        CountryMultiSelectRow(
                            country: country,
                            isSelected: selectedCodes.contains(country.code),
                            onTap: { toggle(country) }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "搜尋國家")
            .navigationTitle("目的地國家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
    }

    private func toggle(_ country: Country) {
        if selectedCodes.contains(country.code) {
            selectedCodes.removeAll { $0 == country.code }
        } else {
            selectedCodes.append(country.code)
            country.lastUsedAt = Date()
        }
    }
}

struct CountryMultiSelectRow: View {
    let country: Country
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Text(country.code.flag)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(country.nameZH)
                        .foregroundStyle(.primary)
                    Text(country.nameEN)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("AppAccent"))
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Color(.systemGray3))
                        .font(.title3)
                }
            }
        }
    }
}
