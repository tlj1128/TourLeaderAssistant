# TourLeaderAssistant — Code Review 彙整

> **初次審查**：2026-04-09　**第二次複查**：2026-04-23　**第三次深度審查**：2026-04-23　**彙整更新**：2026-04-24  
> **平台**：iOS 17+ / SwiftUI + SwiftData + Supabase

---

## 一、已修復項目

| 分類 | 問題 | 修復方式 | 完成日期 |
|------|------|----------|----------|
| 🔴 安全性 | SQL Injection：搜尋查詢未轉義 | 引入 `sanitizeQuery`，SupabaseManager+Search.swift 及主檔三個 searchRemote 方法全部套用 | 2026/04/23–24 |
| 🔴 資料 | `deleteTeam` 未清理 `Expense`、`Income`、`TourFund`、`Journal`、`TourDocument` | FetchDescriptor + forEach delete | 2026/04/23 以前 |
| 🔴 資料 | `deleteTeam` 遺漏清理 `TourMember` | 補上 TourMember FetchDescriptor delete | 2026/04/23 |
| 🔴 資料 | 照片刪除僅用 `file_name`，有碰撞風險 | 加上 `.eq("place_id")` 雙重條件 | 2026/04/23 以前 |
| 🔴 Bug | `CalendarManager.removeEvent` 失敗時仍清除 `calendarEventID` | 改為 `do-catch`，成功才清除 ID | 2026/04/23 |
| 🔴 Bug | `DietaryParser` AI 路徑無 timeout，30 人團可能等數分鐘 | `withThrowingTaskGroup` 5 秒超時保護 | 2026/04/23 |
| 🔴 Bug | `TourDocument.fileURL` 存絕對路徑，App 重裝後失效 | 新增 `resolvedURL` computed property（teamID + fileName 動態重組） | 2026/04/23 |
| 🔴 Bug | `DocumentListView`、`TourMemberSourceView` 使用失效路徑 | 全面替換為 `doc.resolvedURL`，移除舊 `resolveFileURL()` | 2026/04/23 |
| 🟠 品質 | `HotelSupportingTypes` 誤用 `@unchecked Sendable` | 改為正確的 `Sendable` | 2026/04/23 以前 |
| 🟠 品質 | `PlacePhotoManager` 放在 `Views/Place/` 目錄 | 移至 `Managers/` | 2026/04/23 |
| 🟠 品質 | `findOrCreateCity` 在 Extension 中重複實作為 `findOrCreateCityInExtension` | 主檔改為 `internal`，刪除重複版本 | 2026/04/23 |
| 🟠 效能 | `DateFormatter` 在渲染路徑和解析迴圈中頻繁建立 | 改為 `private static let`（TeamWorkspaceView、ExpenseListView、TourMemberMapper、BackupManager）| 2026/04/24 |
| 🟠 效能 | `TourMember.hasBirthdayOnTrip` 逐日迴圈（最多 30 次） | 改為 O(1) 演算法（最多 2 次 Calendar.date 建構） | 2026/04/23 |
| 🟡 修正 | `Expense.convertedAmount` 除以零無保護 | 加上 `exchangeRate == 0 ? 0 : ...` | 2026/04/23 以前 |
| 🟡 UI | Edit 地點頁面（飯店/餐廳/景點）缺少 `NavigationStack` | 三個 EditView 外層加上 `NavigationStack` | 2026/04/24 |
| 🟡 UI | `TeamWorkspaceView` 團員名單功能未開放 | 卡片改為 `isLocked: true`，subtitle 顯示「功能開發中」 | 2026/04/24 |
| 🟡 UI | `SettingsView` 智慧功能區塊（iOS 26 尚未正式發布）| 以 `if false {}` 暫時隱藏 | 2026/04/24 |
| 🟡 安全 | `.gitignore` 未排除 `.DS_Store` | 已加入 | 2026/04/23 以前 |

---

## 二、待處理項目

### 🔴 必做（上架前）

| 問題 | 說明 | 預估工時 |
|------|------|----------|
| `SettingsView` 中 `YOUR_APP_ID` 未替換 | App Store Connect 上架後取得 App ID 立即替換評分連結 | 5 分鐘 |

### 🟠 建議做（謹慎評估）

| 問題 | 說明 | 風險評估 |
|------|------|----------|
| `@Query` 全表掃描（TeamWorkspaceView、ExpenseListView、StatsView）| 目前 `@Query` 載入全部資料後 in-memory filter，資料量增加後有效能影響 | ⚠️ 曾改壞導致按鈕失效，需謹慎測試再重做 |
| 本機地點搜尋 `localHotelPreviews` 等三個方法無 predicate | SwiftData `#Predicate` 不支援 `localizedCaseInsensitiveContains`，只能加 `fetchLimit` | 低效益，地點庫小時影響不明顯 |

### 🟡 低優先（技術債，不急）

| 問題 | 說明 |
|------|------|
| `BackupManager.swift` 921 行過大 | 建議拆出 `Models/BackupModels.swift`，純可讀性問題 |
| `SupabaseManager.swift` 924 行過大 | Payload Structs + AnyCodable 可搬至 `Models/RemoteModels.swift` |
| 三段式重複程式碼（Hotel/Restaurant/Attraction）| 12 個幾乎相同的方法，建議引入 `SyncablePlace` Protocol，工程量大且有改壞風險 |
| `@MainActor` / `Sendable` 標註不完整 | `CalendarManager` 混用 Concurrency API；目前只有 warning，不影響執行 |
| `TourDocument` 長期改為相對路徑儲存 + migration | `resolvedURL` 短期方案已完整解決問題，migration 有資料風險，暫不建議 |
| `ExchangeRateManager` 基準幣種 TWD 硬編碼 | 純台灣版本無需修改 |
| `Expense.convertedAmount` Decimal 精度控制 | 使用者目前無感，低優先 |
| Unit Test（DietaryParser、TourMemberMapper）| 邏輯複雜適合補測試，但 solo 專案現階段效益有限 |

### ✖️ 可關閉（不值得做）

| 問題 | 原因 |
|------|------|
| `ContentView` 與 `View+DynamicTypeSize` switch 邏輯重複 | 不是 bug，兩者用途不同，忽略即可 |
| `TourLeaderAssistantApp` 啟動 `Task` 沒有 stored handle | 啟動初始化 fire-and-forget 是合理模式 |
| `SeedData` 使用 Tuple 而非 Struct | 只執行一次，使用者零感知 |
| `@Attribute(.unique)` 補上 Model id | UUID 碰撞機率極低，理論問題 |
| `Localizable.strings` | 純中文 App，無國際化計畫 |
