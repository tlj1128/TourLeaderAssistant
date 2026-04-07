import SwiftUI

struct ContentView: View {
    @AppStorage("appearance") private var appearance = "auto"
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch textSizePreference {
        case "large":    return .xLarge
        case "xlarge":   return .xxLarge
        case "xxlarge":  return .xxxLarge
        default:         return .large  // 標準
        }
    }

    var body: some View {
        TabView {
            TeamListView()
                .tabItem {
                    Label("團體", systemImage: "rectangle.grid.2x2.fill")
                }

            TeamArchiveView()
                .tabItem {
                    Label("紀錄", systemImage: "archivebox")
                }

            StatsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar.fill")
                }

            PlaceLibraryView()
                .tabItem {
                    Label("地點庫", systemImage: "mappin.and.ellipse")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .tint(Color("AppAccent"))
        .preferredColorScheme(colorScheme)
        .dynamicTypeSize(dynamicTypeSize)
    }
}
