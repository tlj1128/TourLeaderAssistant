import SwiftUI
import SwiftData

struct RestaurantDetailView: View {
    let restaurant: PlaceRestaurant
    @State private var showingEdit = false

    @Query private var allPhotos: [PlacePhoto]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == restaurant.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: PlacePhotoManageView(
                        placeID: restaurant.id,
                        maxPhotos: 8
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
                    Text("照片（\(photos.count)/8）")
                }

                Section("基本資訊") {
                    LabeledContent("英文名稱", value: restaurant.nameEN)
                        .listRowBackground(Color("AppCard"))
                    if !restaurant.nameZH.isEmpty {
                        LabeledContent("中文名稱", value: restaurant.nameZH)
                            .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.nameLocal.isEmpty {
                        LabeledContent("當地語言", value: restaurant.nameLocal)
                            .listRowBackground(Color("AppCard"))
                    }
                    if let city = restaurant.city {
                        LabeledContent("城市") {
                            HStack(spacing: 4) {
                                if let code = city.country?.code { Text(code.flag) }
                                Text(city.fullDisplayName)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.address.isEmpty {
                        HStack {
                            Text("地址").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                let encoded = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(restaurant.address)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.phone.isEmpty {
                        let phoneCode = restaurant.city?.country?.phoneCode ?? ""
                        let fullPhone = phoneCode.isEmpty ? restaurant.phone : "\(phoneCode) \(restaurant.phone)"
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

                if !restaurant.cuisine.isEmpty || !restaurant.rating.isEmpty || !restaurant.specialty.isEmpty {
                    Section("餐廳資訊") {
                        if !restaurant.cuisine.isEmpty { LabeledContent("菜系", value: restaurant.cuisine).listRowBackground(Color("AppCard")) }
                        if !restaurant.rating.isEmpty { LabeledContent("評價", value: restaurant.rating).listRowBackground(Color("AppCard")) }
                        if !restaurant.specialty.isEmpty { LabeledContent("特色菜", value: restaurant.specialty).listRowBackground(Color("AppCard")) }
                    }
                }

                if !restaurant.notes.isEmpty {
                    Section("注意事項") {
                        Text(restaurant.notes)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .listRowBackground(Color("AppCard"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(restaurant.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編輯") { showingEdit = true }
                    .foregroundStyle(Color("AppAccent"))
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditRestaurantView(restaurant: restaurant)
                .appDynamicTypeSize(textSizePreference)
        }
    }
}
