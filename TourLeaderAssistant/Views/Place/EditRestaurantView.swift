import SwiftUI
import SwiftData

struct EditRestaurantView: View {
    @Environment(\.dismiss) private var dismiss

    let restaurant: PlaceRestaurant

    @State private var nameEN = ""
    @State private var nameZH = ""
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var address = ""
    @State private var phone = ""
    @State private var cuisine = ""
    @State private var rating = ""
    @State private var specialty = ""
    @State private var notes = ""

    @State private var showingCountryPicker = false
    @State private var showingCityPicker = false
    @State private var isLoading = true
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var phoneLabel: String {
        if let country = selectedCountry, !country.phoneCode.isEmpty {
            return "電話 \(country.code.flag) \(country.phoneCode)"
        }
        return "電話"
    }

    var body: some View {
        Form {
            Section("名稱") {
                LabeledTextField(label: "英文名稱", placeholder: "Din Tai Fung", text: $nameEN)
                    .autocorrectionDisabled()
                LabeledTextField(label: "中文名稱", placeholder: "鼎泰豐", text: $nameZH)
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
                            Text("未選擇")
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
                            Text(selectedCity?.displayName ?? "未選擇")
                                .foregroundStyle(selectedCity == nil ? .secondary : .primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LabeledTextField(label: "地址", placeholder: "No. 194, Xinyi Rd, Taipei", text: $address)
            }

            Section("聯絡") {
                LabeledTextField(
                    label: phoneLabel,
                    placeholder: "不含國碼，例：02-8101-7799",
                    text: $phone
                )
                .keyboardType(.phonePad)
            }

            Section("餐廳資訊") {
                LabeledTextField(label: "菜系", placeholder: "台灣料理、日式", text: $cuisine)
                LabeledTextField(label: "評價", placeholder: "CP值高，份量大", text: $rating)
                LabeledTextField(label: "特色菜", placeholder: "小籠包、蛋炒飯", text: $specialty)
            }

            Section("注意事項") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("不能訂位")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .navigationTitle("編輯餐廳")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存") { save() }
                    .disabled(nameEN.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { loadData() }
        .onChange(of: selectedCountry) {
            if !isLoading { selectedCity = nil }
        }
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

    private func loadData() {
        isLoading = true
        nameEN = restaurant.nameEN
        nameZH = restaurant.nameZH
        selectedCity = restaurant.city
        selectedCountry = restaurant.city?.country
        address = restaurant.address
        phone = restaurant.phone
        cuisine = restaurant.cuisine
        rating = restaurant.rating
        specialty = restaurant.specialty
        notes = restaurant.notes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }

    private func save() {
        restaurant.nameEN = nameEN.trimmingCharacters(in: .whitespaces)
        restaurant.nameZH = nameZH.trimmingCharacters(in: .whitespaces)
        restaurant.city = selectedCity
        restaurant.address = address.trimmingCharacters(in: .whitespaces)
        restaurant.phone = phone.trimmingCharacters(in: .whitespaces)
        restaurant.cuisine = cuisine.trimmingCharacters(in: .whitespaces)
        restaurant.rating = rating.trimmingCharacters(in: .whitespaces)
        restaurant.specialty = specialty.trimmingCharacters(in: .whitespaces)
        restaurant.notes = notes.trimmingCharacters(in: .whitespaces)
        restaurant.updatedAt = Date()
        restaurant.needsSync = true
        dismiss()
    }
}
