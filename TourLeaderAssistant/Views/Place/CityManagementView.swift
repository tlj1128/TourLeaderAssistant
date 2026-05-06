import SwiftUI
import SwiftData

struct CityManagementView: View {
    @Environment(\.modelContext) private var modelContext
    let country: Country

    @State private var showingAdd = false
    @State private var newCityZH = ""
    @State private var newCityEN = ""
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var sortedCities: [City] {
        country.cities.sorted { $0.nameEN < $1.nameEN }
    }

    var body: some View {
        List {
            if sortedCities.isEmpty {
                ContentUnavailableView(
                    "尚無城市資料",
                    systemImage: "building.2",
                    description: Text("點右上角 ＋ 新增城市")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(sortedCities) { city in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(city.nameZH.isEmpty ? city.nameEN : city.nameZH)
                                .font(.headline)
                            if city.isPreset {
                                Text("預設")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color("AppSecondary").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(city.nameEN)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .deleteDisabled(city.isPreset)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle(country.nameZH)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            addCitySheet
                .appDynamicTypeSize(textSizePreference)
        }
    }

    private var addCitySheet: some View {
        NavigationStack {
            Form {
                Section("城市名稱") {
                    TextField("英文名稱（例：Tokyo）", text: $newCityEN)
                        .autocorrectionDisabled()
                    TextField("中文名稱（例：東京）", text: $newCityZH)
                }
                Section {
                    Text("中文名稱為選填，但建議填寫方便搜尋")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismissAdd()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveCity()
                    }
                    .disabled(newCityEN.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveCity() {
        let city = City(
            nameZH: newCityZH.trimmingCharacters(in: .whitespaces),
            nameEN: newCityEN.trimmingCharacters(in: .whitespaces),
            country: country,
            isPreset: false
        )
        modelContext.insert(city)
        try? modelContext.save()
        dismissAdd()
    }

    private func dismissAdd() {
        newCityZH = ""
        newCityEN = ""
        showingAdd = false
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let city = sortedCities[index]
            guard !city.isPreset else { continue }
            modelContext.delete(city)
        }
    }
}
