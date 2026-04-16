import SwiftUI
import StoreKit

struct DonateView: View {
    @State private var store = TipStore.shared
    @State private var showThankYou = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    // emoji 對應每個產品
    private func emoji(for productID: String) -> String {
        if productID.contains("100") { return "🥤" }
        if productID.contains("200") { return "🍹" }
        if productID.contains("300") { return "☕" }
        return "☕"
    }

    var body: some View {
        List {
            // MARK: - 說明卡片
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("☕")
                            .font(.title2)
                        Text("請開發者喝一杯")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Text("這個 App 完全免費且無廣告。如果您覺得好用，歡迎小額贊助支持我持續改進！")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            // MARK: - 選擇金額
            Section("選擇金額") {
                if store.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if store.products.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("目前無法載入項目，請稍後再試")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        if let errorDetail = store.lastError {
                            Text(errorDetail)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task {
                                await store.purchase(product)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(emoji(for: product.id))
                                    .font(.title2)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(product.displayPrice)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color("AppAccent"))
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                }
            }
        }
        .navigationTitle("支持開發者")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
        }
        .alert("感謝您的支持！", isPresented: $showThankYou) {
            Button("太好了！", role: .cancel) {}
        } message: {
            Text("您的贊助是我持續改進領隊助手的最大動力，非常感謝 🙏")
        }
        .alert("購買失敗", isPresented: Binding(
            get: { store.purchaseError != nil },
            set: { if !$0 { store.purchaseError = nil } }
        )) {
            Button("確定", role: .cancel) {
                store.purchaseError = nil
            }
        } message: {
            Text(store.purchaseError ?? "")
        }
        .onChange(of: store.purchaseSuccess) {
            if store.purchaseSuccess {
                showThankYou = true
                store.purchaseSuccess = false
            }
        }
    }
}
