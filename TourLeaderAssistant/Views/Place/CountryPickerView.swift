import SwiftUI
import SwiftData

struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Country.nameEN) private var countries: [Country]

    @Binding var selectedCountry: Country?
    @State private var searchText = ""

    var recentCountries: [Country] {
        countries
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var allCountries: [Country] {
        if searchText.isEmpty { return countries }
        return countries.filter {
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEN.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedCountry = nil
                    dismiss()
                } label: {
                    Text("不指定")
                        .foregroundStyle(.secondary)
                }

                if searchText.isEmpty && !recentCountries.isEmpty {
                    Section("最近使用") {
                        ForEach(recentCountries) { country in
                            Button {
                                select(country)
                            } label: {
                                CountryPickerRow(
                                    country: country,
                                    isSelected: selectedCountry?.id == country.id
                                )
                            }
                        }
                    }

                    Section("所有國家") {
                        ForEach(allCountries) { country in
                            Button {
                                select(country)
                            } label: {
                                CountryPickerRow(
                                    country: country,
                                    isSelected: selectedCountry?.id == country.id
                                )
                            }
                        }
                    }
                } else {
                    ForEach(allCountries) { country in
                        Button {
                            select(country)
                        } label: {
                            CountryPickerRow(
                                country: country,
                                isSelected: selectedCountry?.id == country.id
                            )
                        }
                    }
                }
            }
            .navigationTitle("選擇國家")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜尋國家名稱或代碼")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func select(_ country: Country) {
        country.lastUsedAt = Date()
        selectedCountry = country
        dismiss()
    }
}

private struct CountryPickerRow: View {
    let country: Country
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(country.nameZH)
                    .foregroundStyle(.primary)
                Text(country.nameEN)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
    }
}
