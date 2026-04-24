import SwiftUI
import SwiftData

struct EditAttractionView: View {
    @Environment(\.dismiss) private var dismiss

    let attraction: PlaceAttraction

    @State private var nameEN = ""
    @State private var nameZH = ""
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var address = ""
    @State private var phone = ""
    @State private var ticketPrice = ""
    @State private var openingHours = ""
    @State private var photographyRules = ""
    @State private var allowedItems = ""
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
        NavigationStack {
            Form {
                Section("名稱") {
                    LabeledTextField(label: "英文名稱", placeholder: "Eiffel Tower", text: $nameEN)
                        .autocorrectionDisabled()
                    LabeledTextField(label: "中文名稱", placeholder: "艾菲爾鐵塔", text: $nameZH)
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
                                Text("\(country.code.flag) \(country.nameZH)")
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
                    
                    LabeledTextField(label: "地址", placeholder: "Champ de Mars, 5 Av. Anatole France", text: $address)
                }
                
                Section("聯絡") {
                    LabeledTextField(
                        label: phoneLabel,
                        placeholder: "不含國碼",
                        text: $phone
                    )
                    .keyboardType(.phonePad)
                }
                
                Section("景點資訊") {
                    LabeledTextField(label: "票價", placeholder: "EUR 29.40（成人）", text: $ticketPrice)
                    LabeledTextField(label: "開放時間", placeholder: "09:00–23:00", text: $openingHours)
                }
                
                Section("注意事項") {
                    LabeledTextField(label: "攝影規定", placeholder: "可拍照，禁商業攝影", text: $photographyRules)
                    LabeledTextField(label: "物品規定", placeholder: "禁帶大型背包", text: $allowedItems)
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("其他注意事項")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("編輯景點")
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
    }

    private func loadData() {
        isLoading = true
        nameEN = attraction.nameEN
        nameZH = attraction.nameZH
        selectedCity = attraction.city
        selectedCountry = attraction.city?.country
        address = attraction.address
        phone = attraction.phone
        ticketPrice = attraction.ticketPrice
        openingHours = attraction.openingHours
        photographyRules = attraction.photographyRules
        allowedItems = attraction.allowedItems
        notes = attraction.notes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }

    private func save() {
        attraction.nameEN = nameEN.trimmingCharacters(in: .whitespaces)
        attraction.nameZH = nameZH.trimmingCharacters(in: .whitespaces)
        attraction.city = selectedCity
        attraction.address = address.trimmingCharacters(in: .whitespaces)
        attraction.phone = phone.trimmingCharacters(in: .whitespaces)
        attraction.ticketPrice = ticketPrice.trimmingCharacters(in: .whitespaces)
        attraction.openingHours = openingHours.trimmingCharacters(in: .whitespaces)
        attraction.photographyRules = photographyRules.trimmingCharacters(in: .whitespaces)
        attraction.allowedItems = allowedItems.trimmingCharacters(in: .whitespaces)
        attraction.notes = notes.trimmingCharacters(in: .whitespaces)
        attraction.updatedAt = Date()
        attraction.needsSync = true
        dismiss()
    }
}
