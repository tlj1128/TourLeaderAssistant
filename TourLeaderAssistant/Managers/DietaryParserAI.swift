import Foundation
import FoundationModels

// MARK: - AI 結構化輸出型別（iOS 26+）
// 這個檔案獨立存放，避免 import FoundationModels 影響低版本編譯

@available(iOS 26, *)
@Generable
struct AIAnalyzedNeeds {
    let needs: [AIAnalyzedNeed]
}

@available(iOS 26, *)
@Generable
struct AIAnalyzedNeed {
    /// 大類：過敏 / 素食 / 不吃特定食物 / 其他 / 機上特殊餐
    let category: String
    /// 顯示用標籤，例如「不吃牛肉」「MOML（清真餐）」
    let label: String
    /// 是否為機上限定
    let isAirborne: Bool
}
