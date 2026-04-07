import SwiftUI
import SwiftData

struct EditHotelView: View {
    @Environment(\.dismiss) private var dismiss

    let hotel: PlaceHotel

    @State private var nameEN = ""
    @State private var nameZH = ""
    @State private var selectedCountry: Country?
    @State private var selectedCity: City?
    @State private var address = ""
    @State private var phone = ""

    @State private var showingCountryPicker = false
    @State private var showingCityPicker = false
    @State private var isLoading = true

    @State private var lobbyFloor = ""
    @State private var poolFloor = ""
    @State private var gymFloor = ""
    @State private var breakfastRestaurantFloor = ""
    @State private var dinnerRestaurantFloor = ""
    @State private var breakfastHours = ""
    @State private var dinnerHours = ""
    @State private var poolHours = ""
    @State private var gymHours = ""

    @State private var wifiNetwork = ""
    @State private var wifiPassword = ""
    @State private var wifiLoginMethod = ""

    @State private var dialRoomToFront = ""
    @State private var dialRoomToRoom = ""
    @State private var dialOutside = ""
    @State private var dialNotes = ""

    @State private var selectedRoomAmenities: Set<String> = []
    @State private var selectedFacilities: Set<String> = []

    @State private var surroundingsAndNotes = ""
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

                    LabeledTextField(label: "地址", placeholder: "Ludwig von Estorff St", text: $address)
                }

                Section("聯絡") {
                    LabeledTextField(
                        label: phoneLabel,
                        placeholder: "不含國碼，例：03-1234-5678",
                        text: $phone
                    )
                    .keyboardType(.phonePad)
                }

                Section("樓層") {
                    LabeledTextField(label: "大廳", placeholder: "1F", text: $lobbyFloor)
                    LabeledTextField(label: "早餐餐廳", placeholder: "3F", text: $breakfastRestaurantFloor)
                    LabeledTextField(label: "晚餐餐廳", placeholder: "3F", text: $dinnerRestaurantFloor)
                    LabeledTextField(label: "游泳池", placeholder: "RF", text: $poolFloor)
                    LabeledTextField(label: "健身房", placeholder: "2F", text: $gymFloor)
                }

                Section("開放時間") {
                    LabeledTextField(label: "早餐", placeholder: "06:30–10:00", text: $breakfastHours)
                    LabeledTextField(label: "晚餐", placeholder: "18:00–21:00", text: $dinnerHours)
                    LabeledTextField(label: "游泳池", placeholder: "07:00–20:00", text: $poolHours)
                    LabeledTextField(label: "健身房", placeholder: "07:00–22:00", text: $gymHours)
                }

                Section("Wi-Fi") {
                    LabeledTextField(label: "網路名稱", placeholder: "Hotel_Guest", text: $wifiNetwork)
                        .autocorrectionDisabled()
                    LabeledTextField(label: "密碼", placeholder: "abc12345", text: $wifiPassword)
                        .autocorrectionDisabled()
                    LabeledTextField(label: "連線方式", placeholder: "直接連線 / 密碼在房卡套上", text: $wifiLoginMethod)
                }

                Section("撥號方式") {
                    LabeledTextField(label: "房間→櫃台", placeholder: "0", text: $dialRoomToFront)
                    LabeledTextField(label: "房間→房間", placeholder: "8+房號", text: $dialRoomToRoom)
                    LabeledTextField(label: "外線", placeholder: "9", text: $dialOutside)
                    LabeledTextField(label: "備註", placeholder: "", text: $dialNotes)
                }

                Section("房間備品") {
                    ForEach(RoomAmenity.allCases, id: \.rawValue) { item in
                        Toggle(item.rawValue, isOn: Binding(
                            get: { selectedRoomAmenities.contains(item.rawValue) },
                            set: {
                                if $0 { selectedRoomAmenities.insert(item.rawValue) }
                                else { selectedRoomAmenities.remove(item.rawValue) }
                            }
                        ))
                    }
                }

                Section("飯店設施") {
                    ForEach(HotelFacility.allCases, id: \.rawValue) { item in
                        Toggle(item.rawValue, isOn: Binding(
                            get: { selectedFacilities.contains(item.rawValue) },
                            set: {
                                if $0 { selectedFacilities.insert(item.rawValue) }
                                else { selectedFacilities.remove(item.rawValue) }
                            }
                        ))
                    }
                }

                Section("周邊資訊與備註") {
                    TextEditor(text: $surroundingsAndNotes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("編輯飯店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
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
        nameEN = hotel.nameEN
        nameZH = hotel.nameZH
        selectedCity = hotel.city
        selectedCountry = hotel.city?.country
        address = hotel.address
        phone = hotel.phone

        let fh = hotel.floorsAndHours
        lobbyFloor = fh.lobbyFloor
        poolFloor = fh.poolFloor
        gymFloor = fh.gymFloor
        breakfastRestaurantFloor = fh.breakfastRestaurantFloor
        dinnerRestaurantFloor = fh.dinnerRestaurantFloor
        breakfastHours = fh.breakfastHours
        dinnerHours = fh.dinnerHours
        poolHours = fh.poolHours
        gymHours = fh.gymHours

        let wifi = hotel.wifi
        wifiNetwork = wifi.network
        wifiPassword = wifi.password
        wifiLoginMethod = wifi.loginMethod

        let pd = hotel.phoneDialing
        dialRoomToFront = pd.roomToFront
        dialRoomToRoom = pd.roomToRoom
        dialOutside = pd.outsideLine
        dialNotes = pd.notes

        let amenities = hotel.amenities
        selectedRoomAmenities = Set(amenities.roomAmenities)
        selectedFacilities = Set(amenities.hotelFacilities)

        surroundingsAndNotes = hotel.surroundingsAndNotes

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLoading = false
        }
    }

    private func save() {
        hotel.nameEN = nameEN.trimmingCharacters(in: .whitespaces)
        hotel.nameZH = nameZH.trimmingCharacters(in: .whitespaces)
        hotel.city = selectedCity
        hotel.address = address.trimmingCharacters(in: .whitespaces)
        hotel.phone = phone.trimmingCharacters(in: .whitespaces)

        hotel.floorsAndHours = FloorsAndHours(
            lobbyFloor: lobbyFloor,
            poolFloor: poolFloor,
            gymFloor: gymFloor,
            breakfastRestaurantFloor: breakfastRestaurantFloor,
            dinnerRestaurantFloor: dinnerRestaurantFloor,
            breakfastHours: breakfastHours,
            dinnerHours: dinnerHours,
            poolHours: poolHours,
            gymHours: gymHours
        )
        hotel.wifi = HotelWifi(
            network: wifiNetwork,
            password: wifiPassword,
            loginMethod: wifiLoginMethod
        )
        hotel.phoneDialing = PhoneDialing(
            roomToFront: dialRoomToFront,
            roomToRoom: dialRoomToRoom,
            outsideLine: dialOutside,
            notes: dialNotes
        )
        hotel.amenities = HotelAmenities(
            roomAmenities: Array(selectedRoomAmenities),
            hotelFacilities: Array(selectedFacilities)
        )
        hotel.surroundingsAndNotes = surroundingsAndNotes
        hotel.updatedAt = Date()
        hotel.needsSync = true

        dismiss()
    }
}
