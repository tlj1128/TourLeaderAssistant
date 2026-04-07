import SwiftUI
import SwiftData

struct AttractionDetailView: View {
    let attraction: PlaceAttraction
    @State private var showingEdit = false

    @Query private var allPhotos: [PlacePhoto]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == attraction.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: PlacePhotoManageView(
                        placeID: attraction.id,
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
                    LabeledContent("英文名稱", value: attraction.nameEN)
                        .listRowBackground(Color("AppCard"))
                    if !attraction.nameZH.isEmpty {
                        LabeledContent("中文名稱", value: attraction.nameZH)
                            .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.nameLocal.isEmpty {
                        LabeledContent("當地語言", value: attraction.nameLocal)
                            .listRowBackground(Color("AppCard"))
                    }
                    if let city = attraction.city {
                        LabeledContent("城市") {
                            HStack(spacing: 4) {
                                if let code = city.country?.code { Text(code.flag) }
                                Text(city.fullDisplayName)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.address.isEmpty {
                        HStack {
                            Text("地址").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                let encoded = attraction.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(attraction.address)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.phone.isEmpty {
                        let phoneCode = attraction.city?.country?.phoneCode ?? ""
                        let fullPhone = phoneCode.isEmpty ? attraction.phone : "\(phoneCode) \(attraction.phone)"
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

                if !attraction.ticketPrice.isEmpty || !attraction.openingHours.isEmpty {
                    Section("景點資訊") {
                        if !attraction.ticketPrice.isEmpty {
                            LabeledContent("票價", value: attraction.ticketPrice)
                                .listRowBackground(Color("AppCard"))
                        }
                        if !attraction.openingHours.isEmpty {
                            LabeledContent("開放時間", value: attraction.openingHours)
                                .listRowBackground(Color("AppCard"))
                        }
                    }
                }

                if !attraction.photographyRules.isEmpty || !attraction.allowedItems.isEmpty || !attraction.notes.isEmpty {
                    Section("注意事項") {
                        if !attraction.photographyRules.isEmpty {
                            LabeledContent("攝影規定", value: attraction.photographyRules)
                                .listRowBackground(Color("AppCard"))
                        }
                        if !attraction.allowedItems.isEmpty {
                            LabeledContent("物品規定", value: attraction.allowedItems)
                                .listRowBackground(Color("AppCard"))
                        }
                        if !attraction.notes.isEmpty {
                            Text(attraction.notes)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .listRowBackground(Color("AppCard"))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(attraction.nameEN)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編輯") { showingEdit = true }
                    .foregroundStyle(Color("AppAccent"))
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditAttractionView(attraction: attraction)
                .appDynamicTypeSize(textSizePreference)
        }
    }
}
