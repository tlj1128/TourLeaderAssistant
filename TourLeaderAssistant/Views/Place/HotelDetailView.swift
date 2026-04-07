import SwiftUI
import SwiftData

struct HotelDetailView: View {
    let hotel: PlaceHotel
    @State private var showingEdit = false
    @State private var showingAnnouncement = false

    @Query private var allPhotos: [PlacePhoto]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == hotel.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: PlacePhotoManageView(
                        placeID: hotel.id,
                        maxPhotos: 10
                    )) {
                        if photos.isEmpty {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundStyle(Color("AppAccent"))
                                Text("新增照片")
                                    .foregroundStyle(Color("AppAccent"))
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photos.prefix(5)) { photo in
                                        if let img = PlacePhotoManager.shared.loadImage(fileName: photo.fileName) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    if photos.count > 5 {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 80, height: 80)
                                            Text("+\(photos.count - 5)")
                                                .font(.body).fontWeight(.semibold)
                                                .foregroundStyle(Color(.systemGray))
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listRowBackground(Color("AppCard"))
                } header: {
                    Text("照片（\(photos.count)/10）")
                }

                Section("基本資訊") {
                    // 英文名稱永遠顯示（主要識別）
                    LabeledContent("英文名稱", value: hotel.nameEN)
                        .listRowBackground(Color("AppCard"))
                    // 有中文名稱才顯示
                    if !hotel.nameZH.isEmpty {
                        LabeledContent("中文名稱", value: hotel.nameZH)
                            .listRowBackground(Color("AppCard"))
                    }
                    if let city = hotel.city {
                        LabeledContent("城市") {
                            HStack(spacing: 4) {
                                if let code = city.country?.code { Text(code.flag) }
                                Text(city.fullDisplayName)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !hotel.address.isEmpty {
                        HStack {
                            Text("地址").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                let encoded = hotel.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(hotel.address)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !hotel.phone.isEmpty {
                        let phoneCode = hotel.city?.country?.phoneCode ?? ""
                        let fullPhone = phoneCode.isEmpty ? hotel.phone : "\(phoneCode) \(hotel.phone)"
                        let dialNumber = fullPhone.filter { $0.isNumber || $0 == "+" }
                        HStack {
                            Text("電話").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                if let url = URL(string: "tel://\(dialNumber)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(fullPhone)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                }

                let fh = hotel.floorsAndHours
                if !fh.lobbyFloor.isEmpty || !fh.breakfastHours.isEmpty || !fh.dinnerHours.isEmpty
                    || !fh.poolFloor.isEmpty || !fh.gymFloor.isEmpty
                    || !fh.poolHours.isEmpty || !fh.gymHours.isEmpty {
                    Section("樓層與開放時間") {
                        if !fh.lobbyFloor.isEmpty {
                            LabeledContent("大廳", value: fh.lobbyFloor).listRowBackground(Color("AppCard"))
                        }
                        if !fh.breakfastRestaurantFloor.isEmpty {
                            LabeledContent("早餐餐廳", value: fh.breakfastRestaurantFloor).listRowBackground(Color("AppCard"))
                        }
                        if !fh.breakfastHours.isEmpty {
                            LabeledContent("早餐時間", value: fh.breakfastHours).listRowBackground(Color("AppCard"))
                        }
                        if !fh.dinnerRestaurantFloor.isEmpty {
                            LabeledContent("晚餐餐廳", value: fh.dinnerRestaurantFloor).listRowBackground(Color("AppCard"))
                        }
                        if !fh.dinnerHours.isEmpty {
                            LabeledContent("晚餐時間", value: fh.dinnerHours).listRowBackground(Color("AppCard"))
                        }
                        if !fh.poolFloor.isEmpty {
                            LabeledContent("游泳池", value: fh.poolFloor).listRowBackground(Color("AppCard"))
                        }
                        if !fh.poolHours.isEmpty {
                            LabeledContent("游泳池時間", value: fh.poolHours).listRowBackground(Color("AppCard"))
                        }
                        if !fh.gymFloor.isEmpty {
                            LabeledContent("健身房", value: fh.gymFloor).listRowBackground(Color("AppCard"))
                        }
                        if !fh.gymHours.isEmpty {
                            LabeledContent("健身房時間", value: fh.gymHours).listRowBackground(Color("AppCard"))
                        }
                    }
                }

                let wifi = hotel.wifi
                if !wifi.network.isEmpty || !wifi.password.isEmpty || !wifi.loginMethod.isEmpty {
                    Section("Wi-Fi") {
                        if !wifi.network.isEmpty {
                            LabeledContent("網路名稱", value: wifi.network).listRowBackground(Color("AppCard"))
                        }
                        if !wifi.password.isEmpty {
                            LabeledContent("密碼", value: wifi.password).listRowBackground(Color("AppCard"))
                        }
                        if !wifi.loginMethod.isEmpty {
                            LabeledContent("連線方式", value: wifi.loginMethod).listRowBackground(Color("AppCard"))
                        }
                    }
                }

                let pd = hotel.phoneDialing
                if !pd.roomToFront.isEmpty || !pd.roomToRoom.isEmpty || !pd.outsideLine.isEmpty {
                    Section("撥號方式") {
                        if !pd.roomToFront.isEmpty {
                            LabeledContent("房間→櫃台", value: pd.roomToFront).listRowBackground(Color("AppCard"))
                        }
                        if !pd.roomToRoom.isEmpty {
                            LabeledContent("房間→房間", value: pd.roomToRoom).listRowBackground(Color("AppCard"))
                        }
                        if !pd.outsideLine.isEmpty {
                            LabeledContent("外線", value: pd.outsideLine).listRowBackground(Color("AppCard"))
                        }
                        if !pd.notes.isEmpty {
                            LabeledContent("備註", value: pd.notes).listRowBackground(Color("AppCard"))
                        }
                    }
                }

                let amenities = hotel.amenities
                if !amenities.roomAmenities.isEmpty || !amenities.hotelFacilities.isEmpty {
                    Section("備品與設施") {
                        if !amenities.roomAmenities.isEmpty {
                            LabeledContent("房間備品", value: amenities.roomAmenities.joined(separator: "、"))
                                .listRowBackground(Color("AppCard"))
                        }
                        if !amenities.hotelFacilities.isEmpty {
                            LabeledContent("飯店設施", value: amenities.hotelFacilities.joined(separator: "、"))
                                .listRowBackground(Color("AppCard"))
                        }
                    }
                }

                if !hotel.surroundingsAndNotes.isEmpty {
                    Section("周邊資訊與備註") {
                        Text(hotel.surroundingsAndNotes)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .listRowBackground(Color("AppCard"))
                    }
                }

                // 產生公告按鈕
                Section {
                    Button {
                        showingAnnouncement = true
                    } label: {
                        Label("產生 LINE 公告訊息", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color("AppAccent"))
                    }
                    .listRowBackground(Color("AppCard"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        // 主標題用英文，有中文則在大標顯示（navigationSubtitle iOS 16+）
        .navigationTitle(hotel.nameEN)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編輯") { showingEdit = true }
                    .foregroundStyle(Color("AppAccent"))
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditHotelView(hotel: hotel)
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(isPresented: $showingAnnouncement) {
            HotelAnnouncementView(hotel: hotel)
                .appDynamicTypeSize(textSizePreference)
        }
    }
}
