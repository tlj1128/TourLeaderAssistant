import Foundation
import FoundationModels

// MARK: - FoundationModelManager
// 統一管理 Foundation Models 的呼叫
// 需要：iPhone 15 Pro / iPhone 16 以上 + iOS 26 + Apple Intelligence 已啟用
// 目前使用場景：飲食需求語意解析（DietaryParser）
// 未來場景：收據拍照解析、行程表 PDF 解析

@available(iOS 26, *)
final class FoundationModelManager {

    static let shared = FoundationModelManager()
    private init() {}

    // MARK: - 可用性

    var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return true
        case .unavailable: return false
        }
    }

    // MARK: - 結構化輸出（@Generable）

    /// 傳入 prompt 與系統指令，回傳指定型別的結構化輸出
    func generate<T: Generable>(
        prompt: String,
        instructions: String,
        as type: T.Type
    ) async throws -> T {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: type)
        return response.content
    }

    // MARK: - 純文字輸出

    /// 傳入 prompt 與系統指令，回傳純文字
    func analyze(prompt: String, instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
