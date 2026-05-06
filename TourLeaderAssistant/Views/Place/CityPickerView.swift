import SwiftUI
import SwiftData

struct CityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let country: Country
    @Binding var selectedCity: City?
    @State private var searchText = ""
    @State private var showingAddCity = false
    @State private var newCityZH = ""
    @State private var newCityEN = ""

    @Query private var allCities: [City]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"
    
    init(country: Country, selectedCity: Binding<City?>) {
        self.country = country
        self._selectedCity = selectedCity
        let countryID = country.id
        self._allCities = Query(
            filter: #Predicate<City> { $0.country?.id == countryID },
            sort: \City.nameZH
        )
    }

    var filtered: [City] {
        if searchText.isEmpty { return allCities }
        return allCities.filter {
            $0.nameZH.localizedCaseInsensitiveContains(searchText) ||
            $0.nameEN.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedCity = nil
                    dismiss()
                } label: {
                    Text("不指定")
                        .foregroundStyle(.secondary)
                }

                if filtered.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "尚無城市資料" : "找不到符合的城市",
                        systemImage: "building.2",
                        description: Text(
                            searchText.isEmpty ? "點右上角 ＋ 新增城市" : "試試其他關鍵字"
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered) { city in
                        Button {
                            selectedCity = city
                            dismiss()
                        } label: {
                            CityPickerRow(
                                city: city,
                                isSelected: selectedCity?.id == city.id
                            )
                        }
                    }
                }
            }
            .navigationTitle(country.nameZH)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜尋城市")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCity = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            }
            .sheet(isPresented: $showingAddCity) {
                addCitySheet
                    .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    private var addCitySheet: some View {
        NavigationStack {
            Form {
                Section("城市名稱") {
                    LabeledTextField(label: "英文名稱", placeholder: "Tokyo", text: $newCityEN)
                        .autocorrectionDisabled()
                    LabeledTextField(label: "中文名稱", placeholder: "東京", text: $newCityZH)
                }
                Section {
                    Text("英文名稱為必填，中文名稱選填")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismissAdd() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { saveCity() }
                        .disabled(newCityEN.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveCity() {
        let city = City(
            nameZH: newCityZH.trimmingCharacters(in: .whitespaces),
            nameEN: newCityEN.trimmingCharacters(in: .whitespaces),
            country: country
        )
        modelContext.insert(city)
        try? modelContext.save()
        dismissAdd()
    }

    private func dismissAdd() {
        newCityZH = ""
        newCityEN = ""
        showingAddCity = false
    }
}

private struct CityPickerRow: View {
    let city: City
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.nameZH.isEmpty ? city.nameEN : city.nameZH)
                    .foregroundStyle(.primary)
                if !city.nameZH.isEmpty {
                    Text(city.nameEN)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
    }
}
