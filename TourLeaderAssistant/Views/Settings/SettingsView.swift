import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "auto"
    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        NavigationStack {
            List {
                Section("個人") {
                    NavigationLink(destination: PersonalProfileView()) {
                        Label("個人基本資料", systemImage: "person.circle")
                    }
                }

                Section("自訂資料") {
                    NavigationLink(destination: CountryManagementView()) {
                        Label("國家與城市管理", systemImage: "map")
                    }
                    NavigationLink(destination: FundTypeManageView()) {
                        Label("零用金類型", systemImage: "bag")
                    }
                    NavigationLink(destination: IncomeTypeManageView()) {
                        Label("收入類型", systemImage: "banknote")
                    }
                }

                Section("偏好設定") {
                    // 外觀設定
                    VStack(alignment: .leading, spacing: 8) {
                        Text("外觀")
                            .font(.subheadline)
                        Picker("外觀", selection: $appearance) {
                            Text("自動").tag("auto")
                            Text("淺色").tag("light")
                            Text("深色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    // 字體大小
                    VStack(alignment: .leading, spacing: 8) {
                        Text("介面文字大小")
                            .font(.subheadline)
                        Picker("介面文字大小", selection: $textSizePreference) {
                            Text("標準").tag("standard")
                            Text("大").tag("large")
                            Text("特大").tag("xlarge")
                            Text("超大").tag("xxlarge")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    // 拍照存相簿
                    Toggle(isOn: $savePhotoToAlbum) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("拍照後儲存至相簿")
                            Text("關閉後拍照不會存入系統相簿")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("支持與回饋") {
                    Button {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("為 App 評分", systemImage: "star")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        if let url = URL(string: "mailto:your@email.com?subject=領隊助手意見回饋") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("意見回饋", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                }

                Section("關於") {
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("設定")
        }
    }
}
