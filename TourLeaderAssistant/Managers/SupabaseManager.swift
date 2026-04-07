import Foundation
import Supabase

@MainActor
class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://wsnqfyamuxalocwqccxn.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzbnFmeWFtdXhhbG9jd3FjY3huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NTIwOTUsImV4cCI6MjA5MTAyODA5NX0.xUgoORnWe44fLI53H5ix6Mfph6dfT2pcxViQf_IMQRM"
        )
    }

    // MARK: - 連線測試

    func testConnection() async -> Bool {
        do {
            let _: [AnyJSON] = try await client
                .from("countries")
                .select("id")
                .limit(1)
                .execute()
                .value
            return true
        } catch {
            print("Supabase 連線失敗：\(error)")
            return false
        }
    }
}
