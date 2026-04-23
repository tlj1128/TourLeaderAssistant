import SwiftUI
import SwiftData

@main
struct TourLeaderAssistantApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Team.self,
                TourFund.self,
                Expense.self,
                Income.self,
                Journal.self,
                TourDocument.self,
                Country.self,
                City.self,
                PlaceHotel.self,
                PlaceRestaurant.self,
                PlaceAttraction.self,
                PlacePhoto.self,
                CustomFundType.self,
                CustomIncomeType.self,
                TourMember.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(for: schema, configurations: [config])
            SeedData.seedCountriesIfNeeded(modelContext: container.mainContext)
        } catch {
            fatalError("無法建立 ModelContainer：\(error)")
        }
        Task {
            let ok = await SupabaseManager.shared.testConnection()
                print("Supabase 連線：\(ok ? "成功" : "失敗")")
                await AppConfigManager.shared.fetchConfig()
                await ExchangeRateManager.shared.fetchIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
