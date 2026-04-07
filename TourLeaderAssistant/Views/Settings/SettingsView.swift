import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("個人") {
                    NavigationLink(destination: PersonalProfileView()) {
                        Label("個人基本資料", systemImage: "person.circle")
                    }
                }

                Section("地點庫") {
                    NavigationLink(destination: CountryManagementView()) {
                        Label("國家與城市管理", systemImage: "map")
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}
