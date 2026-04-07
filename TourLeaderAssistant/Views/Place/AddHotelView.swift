import SwiftUI
import SwiftData

struct AddHotelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var nameEN = ""
    @State private var nameZH = ""
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var address = ""
    @State private var phone = ""

    @State private var showingCountryPicker = false
    @State private var showingCityPicker = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var canSave: Bool { !nameEN.trimmingCharacters(in: .whitespaces).isEmpty }

    var phoneLabel: String {
        if let country = selectedCountry, !country.phoneCode.isEmpty {
            return "電話 \(country.code.flag) \(country.phoneCode)"
        }
        return "電話"
    }

    var body: some View {
        Form {
            Section("名稱（必填）") {
                LabeledTextField(label: "英文名稱", placeholder: "Windhoek Country Club", text: $nameEN)
                    .autocorrectionDisabled()
                LabeledTextField(label: "中文名稱", placeholder: "溫得和克鄉村俱樂部", text: $nameZH)
            }

            Section("位置") {
                Button {
                    showingCountryPicker = true
                } label: {
                    HStack {
                        Text("國家")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let country = selectedCountry {
                            Text(country.nameZH)
                                .foregroundStyle(.primary)
                        } else {
                            Text("請選擇")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if selectedCountry != nil {
                    Button {
                        showingCityPicker = true
                    } label: {
                        HStack {
                            Text("城市")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(selectedCity?.displayName ?? "請選擇")
                                .foregroundStyle(selectedCity == nil ? .secondary : .primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LabeledTextField(label: "地址", placeholder: "Ludwig von Estorff St, Windhoek", text: $address)
            }

            Section("聯絡") {
                LabeledTextField(
                    label: phoneLabel,
                    placeholder: "不含國碼，例：03-1234-5678",
                    text: $phone
                )
                .keyboardType(.phonePad)
            }

            Section {
                Text("樓層、Wi-Fi、撥號、備品等資料可進入飯店後編輯")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("新增飯店")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存") { save() }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: selectedCountry) { selectedCity = nil }
        .sheet(isPresented: $showingCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(isPresented: $showingCityPicker) {
            if let country = selectedCountry {
                CityPickerView(country: country, selectedCity: $selectedCity)
                    .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    private func save() {
        let hotel = PlaceHotel(
            nameEN: nameEN.trimmingCharacters(in: .whitespaces),
            city: selectedCity
        )
        hotel.nameZH = nameZH.trimmingCharacters(in: .whitespaces)
        hotel.address = address.trimmingCharacters(in: .whitespaces)
        hotel.phone = phone.trimmingCharacters(in: .whitespaces)
        modelContext.insert(hotel)
        dismiss()
    }
}
