import StoreKit
import Observation

@Observable
class TipStore {
    static let shared = TipStore()

    var products: [Product] = []
    var isLoading = false
    var purchaseError: String? = nil
    var purchaseSuccess = false
    var lastError: String? = nil

    private let productIDs = [
        "com.TLJStudio.TourLeaderAssistant.tip.100",
        "com.TLJStudio.TourLeaderAssistant.tip.200",
        "com.TLJStudio.TourLeaderAssistant.tip.300"
    ]

    private init() {}

    // MARK: - 載入產品

    func loadProducts() async {
        isLoading = true
        lastError = nil
        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted { $0.price < $1.price }
            if fetched.isEmpty {
                lastError = "StoreKit 回傳空陣列，請確認 Product ID 是否正確"
            }
        } catch {
            purchaseError = "無法載入項目：\(error.localizedDescription)"
            lastError = "詳細錯誤：\(error)"
        }
        isLoading = false
    }

    // MARK: - 購買

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseSuccess = true
                case .unverified:
                    purchaseError = "購買驗證失敗，請稍後再試"
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "購買審核中，請稍候"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "購買失敗：\(error.localizedDescription)"
        }
    }
}
