# TourLeaderAssistant — 第 3 次深度 Code Review

> **審查日期**：2026-04-23  
> **審查範圍**：全專案原始碼深度逐檔審查  
> **審查者角色**：資深 iOS 工程師，熟悉 Swift 6 / SwiftUI / SwiftData  
> **目標**：獨立深度審查 → 與 CODE_REVIEW2.md 交叉比對 → 提出補充與修正建議

---

## 一、整體評價

### 👍 優點（值得肯定的部分）

| 面向 | 說明 |
|------|------|
| **功能完整度** | 團體管理、帳務、旅客名冊匯入（xlsx/docx/pdf/OCR）、地點庫雲端同步、iCloud 備份還原、行事曆整合、匯率查詢、飲食需求解析（含 iOS 26 Foundation Models AI 補充）、StoreKit 打賞——功能非常豐富 |
| **SwiftData 採用** | 正確使用 `@Model`、`@Query`、`FetchDescriptor`，Model 定義清晰 |
| **Country ↔ City 關係** | 正確使用 `@Relationship(deleteRule: .cascade)` 管理父子關聯 |
| **備份設計** | `BackupManager` 使用 `NSFileCoordinator` 確保 iCloud 安全讀寫，JSON 格式含 meta、自動清理舊備份，設計完善 |
| **安全意識** | `KeychainManager` 正確使用 Keychain 存設備 UUID；xcconfig 分離敏感設定且已加入 .gitignore |
| **DietaryParser** | Rule-based + AI 補充的混合策略設計精巧，對領隊場景有高度實用價值 |
| **TourMemberParser** | 自行實作 ZIP 解壓 + XML 解析，不依賴第三方套件處理 xlsx/docx，非常紮實 |
| **sanitizeQuery** | 已在 `SupabaseManager+Search.swift` 為雲端搜尋做了查詢轉義保護 |
| **.gitignore** | 已正確加入 `.DS_Store` 和 `*.xcconfig` |

### 🔻 整體風險摘要

| 嚴重度 | 數量 | 主要議題 |
|--------|------|----------|
| 🔴 P0 | 5 | App ID 佔位符未替換、CalendarManager 靜默失敗、TourMember 刪除遺漏、DietaryParser AI 無 timeout、TourDocument 絕對路徑 |
| 🟠 P1 | 5 | @Query 全表掃描、DateFormatter 頻繁建立、BackupManager 921 行巨型檔、三段式重複程式碼、`findOrCreateCity` 重複實作 |
| 🟡 P2 | 5 | PlacePhotoManager 錯置目錄、ExchangeRateManager 硬編碼 TWD、Concurrency 標註不完整、Backup Struct 過多、缺少 Unit Test |

---

## 二、逐項深度分析

### 🔴 P0：必須立即修復

#### P0-1：`SettingsView` 的 App ID 佔位符未替換（上線會出事）

**檔案**：`SettingsView.swift:164`

```swift
// ⚠️ YOUR_APP_ID 是佔位符，上架後評分連結完全無效
URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review")
```

**風險**：使用者點「為 App 評分」會跳到 404 頁面，影響使用者體驗與 App Store 評分獲取。  
**建議**：上架後立即替換為真實 App ID，或改用 `SKStoreReviewController.requestReview()` 由系統處理。

> ✅ **SettingsView 更新觀察**：已新增「智慧功能」Section，含 Apple Intelligence 開關 (`useLocalAI`) 與不支援裝置的降級顯示，設計合理。

---

#### P0-2：`CalendarManager.removeEvent` 靜默失敗會產生幽靈 ID

**檔案**：`CalendarManager.swift:51-56`

```swift
func removeEvent(for team: Team) {
    guard let eventID = team.calendarEventID,
          let event = store.event(withIdentifier: eventID) else { return }
    try? store.remove(event, span: .thisEvent)  // ← 失敗時仍然往下跑
    team.calendarEventID = nil                  // ← 清空了，但行事曆上還在
}
```

**風險**：`try?` 靜默吞掉錯誤後無條件清空 `calendarEventID`，導致：  
- 行事曆事件殘留（使用者看到幽靈行程）  
- 無法再透過 App 刪除該事件  

**建議**：
```swift
func removeEvent(for team: Team) {
    guard let eventID = team.calendarEventID,
          let event = store.event(withIdentifier: eventID) else { return }
    do {
        try store.remove(event, span: .thisEvent)
        team.calendarEventID = nil  // 成功才清
    } catch {
        print("行事曆刪除失敗，保留 eventID 以便重試：\(error)")
    }
}
```

---

#### P0-3：刪除 Team 時漏刪 `TourMember`

**檔案**：`TeamListView.swift:169-190`

`deleteTeam` 方法清理了 Expense、Income、TourFund、Journal、TourDocument，**但完全遺漏了 `TourMember`**。刪除團體後，該團所有旅客資料會成為孤兒記錄永久殘留在資料庫中。

**建議**：在 `deleteTeam` 中補上：
```swift
let memberDesc = FetchDescriptor<TourMember>(predicate: #Predicate { $0.teamID == teamID })
(try? modelContext.fetch(memberDesc))?.forEach { modelContext.delete($0) }
```

> 🔑 **長期建議**：所有 Team 子模型都應該改用 `@Relationship(deleteRule: .cascade)`，從根源解決手動清理的遺漏風險。

---

#### P0-4：`DietaryParser` 的 AI 路徑沒有 timeout 保護

**檔案**：`DietaryParser.swift:60-68`

```swift
if useAI && FoundationModelManager.shared.isAvailable {
    do {
        needs = try await supplementWithAI(remark: remark, existing: needs)
    } catch {
        // AI 補充失敗，維持 rule-based 結果
    }
}
```

**風險**：Foundation Models 的推理速度取決於裝置負載。如果模型回應很慢（例如裝置過熱降頻），`TeamWorkspaceView` 的 `loadDietaryInfo()` 會對每位團員逐一 `await`，UI 會一直顯示轉圈，且沒有任何取消或超時機制。30 人的團可能要等數分鐘。

**建議**：加上 `withTaskGroup` + 超時保護：
```swift
func parse(remark: String) async -> [DietaryNeed] {
    var needs = parseWithRules(remark: remark)
    if #available(iOS 26, *) {
        let useAI = UserDefaults.standard.bool(forKey: "useLocalAI")
        if useAI && FoundationModelManager.shared.isAvailable {
            do {
                needs = try await withThrowingTaskGroup(of: [DietaryNeed].self) { group in
                    group.addTask {
                        try await supplementWithAI(remark: remark, existing: needs)
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(5))
                        throw CancellationError()
                    }
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
            } catch {
                // timeout 或 AI 失敗，回退至 rule-based
            }
        }
    }
    return needs
}
```

---

#### P0-5：`TourDocument.fileURL` 儲存絕對路徑——App 更新或重裝後失效

**檔案**：`TourDocument.swift:10`、`TourMemberSourceView.swift:428-433`

```swift
// TourDocument.swift — 存的是完整的絕對路徑
var fileURL: URL

// TourMemberSourceView.swift — 短期修法：動態重組路徑
private func resolveFileURL(_ doc: TourDocument) -> URL {
    let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let resolved = docsDir
        .appendingPathComponent(doc.teamID.uuidString)
        .appendingPathComponent(doc.fileName)
    return FileManager.default.fileExists(atPath: resolved.path) ? resolved : doc.fileURL
}
```

**問題**：iOS 每次安裝或更新 App 時，沙盒路徑的 UUID 段會改變（如 `/var/mobile/.../A1B2C3D4-XXXX/Documents/`），導致存入 SwiftData 的絕對 `fileURL` 失效。`TourMemberSourceView` 做了 `resolveFileURL` 短期修法，但 `DocumentListView` 和 `BackupManager` 的還原邏輯可能仍在使用原始的 `doc.fileURL`。

**長期建議**：
1. `TourDocument` 改存相對路徑（例如 `teamID/fileName`）
2. 新增 computed property 動態組合完整路徑
3. 寫一次性 migration 把現有資料的絕對路徑轉為相對路徑

```swift
@Model
class TourDocument {
    var relativePath: String  // e.g. "<teamID>/<fileName>"
    
    var resolvedURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(relativePath)
    }
}
```

---

### 🟠 P1：效能與架構問題

#### P1-1：`@Query` 全表載入後 in-memory filter（效能瓶頸）

**影響檔案**：`TeamWorkspaceView`、`ExpenseListView`、`StatsView`、`SettingsView`

```swift
// TeamWorkspaceView.swift:26-27
@Query private var allExpenses: [Expense]    // ← 載入所有團的所有支出
@Query private var allMembers: [TourMember]  // ← 載入所有團的所有成員

// 然後在 computed property 裡 filter
var teamFunds: [TourFund] { funds.filter { $0.teamID == team.id } }
```

**影響**：團體數量增加後（例如一年 30 團，每團 20 筆支出），每次畫面重繪都要掃描全表再過濾，造成 CPU 和記憶體浪費。

**建議**：利用 `init` 注入 `#Predicate` 讓 SwiftData 在 SQLite 層篩選：
```swift
struct ExpenseListView: View {
    @Query private var expenses: [Expense]
    let team: Team
    
    init(team: Team) {
        self.team = team
        let teamID = team.id
        _expenses = Query(
            filter: #Predicate<Expense> { $0.teamID == teamID },
            sort: [SortDescriptor(\.date, order: .reverse)]
        )
    }
}
```

> **CODE_REVIEW2 比對**：CODE_REVIEW2 已正確指出此問題（第一優先任務），我完全同意這是最急迫的優化。
> 
> **TeamWorkspaceView 重新審查**：確認修改後的版本（547 行）仍然使用 `@Query private var allExpenses: [Expense]` + `.filter { $0.teamID == team.id }`，此問題持續存在。

---

#### P1-2：`DateFormatter` 在 View 渲染迴圈中重複建立

**影響檔案**：`BackupFileInfo.formattedDate`（每次 `listBackups` 都建新 formatter）、`TourMemberMapper.parseDate`（每次解析日期建 6 個 formatter）

```swift
// BackupManager.swift:222-226
var formattedDate: String {
    let f = DateFormatter()        // ← 每次存取都新建
    f.dateFormat = "yyyy/MM/dd HH:mm"
    return f.string(from: createdAt)
}
```

```swift
// TourMemberMapper.swift:400-412  
static func parseDate(_ s: String?) -> Date? {
    let formats = ["yyyy/MM/dd", "yyyy-MM-dd", ...]
    for fmt in formats {
        let f = DateFormatter()    // ← 每個格式都新建
        ...
    }
}
```

```swift
// TeamWorkspaceView.swift:173, 389 — 仍在渲染路徑中建立 formatter
let f = DateFormatter(); f.dateFormat = "MM/dd"
let f = DateFormatter(); f.dateFormat = "M/d"
```

**建議**：建立集中式 formatter 快取：
```swift
enum DateFormatters {
    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
    
    static let parsers: [DateFormatter] = {
        ["yyyy/MM/dd", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyyMMdd", "dd.MM.yyyy"]
            .map { fmt in
                let f = DateFormatter()
                f.dateFormat = fmt
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
    }()
}
```

> 注意：`BackupManager.swift` 底部已有一個 `DateFormatter.backupFileName` 的 static 做法，但只用於備份檔名。其他地方都沒跟進。

---

#### P1-3：`BackupManager.swift` 921 行——單一檔案過大

這個檔案包含：14 個 Backup Struct + BackupManager class + RestoreResult + BackupPreview + BackupFileInfo。

**建議拆分方案**：

| 新檔案 | 內容 |
|--------|------|
| `Models/BackupModels.swift` | 所有 `XxxBackup` 結構 + `BackupData` + `BackupMeta` |
| `Models/BackupFileInfo.swift` | `BackupFileInfo` + `RestoreResult` + `BackupPreview` |
| `Managers/BackupManager.swift` | 只留 Manager 邏輯（約 300 行） |

---

#### P1-4：三段式重複程式碼（Hotel / Restaurant / Attraction）

`SupabaseManager+Search.swift` 中以下方法幾乎是完全複製貼上：

- `localHotelPreviews` / `localRestaurantPreviews` / `localAttractionPreviews`
- `fetchRemoteHotelPreviews` / `fetchRemoteRestaurantPreviews` / `fetchRemoteAttractionPreviews`
- `downloadHotel` / `downloadRestaurant` / `downloadAttraction`
- `refreshLocalHotel` / `refreshLocalRestaurant` / `refreshLocalAttraction`

共 **12 個方法**，合計約 450 行幾乎相同的程式碼。

**建議**：設計 `SyncablePlace` Protocol + 泛型方法：
```swift
protocol SyncablePlace: PersistentModel {
    var remoteID: UUID? { get set }
    var needsSync: Bool { get set }
    var nameEN: String { get }
    var nameZH: String { get }
    var city: City? { get }
    var updatedAt: Date { get set }
    static var tableName: String { get }
    static var placeType: PlaceCategoryType { get }
}
```

> **CODE_REVIEW2 比對**：CODE_REVIEW2 的第三優先任務提到這個，但我認為優先級應該更高（P1），因為每次修 bug 都要改三份相同的程式碼，出錯機率極高。

---

#### P1-5：`findOrCreateCity` 重複實作

**檔案**：`SupabaseManager.swift` 有一份，`SupabaseManager+Search.swift:638` 又有一份叫 `findOrCreateCityInExtension`。

**根本原因**：Extension 中的 `private` 方法無法存取主檔的 `private` 方法。  
**正確解法**：將原始方法改為 `internal`（預設存取層級），刪除重複版本。

---

### 🟡 P2：品質與規範問題

#### P2-1：`PlacePhotoManager` 存放在 `Views/Place/` 目錄

這是一個純業務邏輯的 Manager（檔案 I/O、圖片壓縮），不應放在 Views 目錄下。移至 `Managers/` 即可。

#### P2-2：`ExchangeRateManager` 硬編碼 TWD 為基準幣種

```swift
// ExchangeRateManager.swift:70
guard let url = URL(string: "https://api.frankfurter.dev/v2/rates?base=TWD") else { return }
```

目前邏輯把 TWD 寫死為匯率基準。如果未來要支援非台灣領隊，需要重構。建議至少抽成可配置常數。

#### P2-3：Swift Concurrency 標註不完整

| 問題 | 檔案 |
|------|------|
| `BackupManager` 未標 `@MainActor` 但 `createBackup` 操作 UI 相關的 `context` | `BackupManager.swift` |
| `PlacePhotoManager` 在多個 async 上下文中被呼叫，但本身不是 `Sendable` | `PlacePhotoManager.swift` |
| `CalendarManager` 在 `requestAccess` 中手動 `DispatchQueue.main.async`，與 Swift Concurrency 混用 | `CalendarManager.swift` |

**建議**：統一標註 `@MainActor`，或確認 `nonisolated` + `Sendable` 搭配正確。

#### P2-4：`TourMember.hasBirthdayOnTrip` 使用逐日迴圈

```swift
// TourMember.swift:79-85
var current = departureDate
while current <= returnDate {
    let c = calendar.dateComponents([.month, .day], from: current)
    if c.month == month && c.day == day { return true }
    current = calendar.date(byAdding: .day, value: 1, to: current) ?? ...
}
```

一個 30 天的行程會迴圈 30 次。可以直接比較生日的月日是否落在出發到回程的範圍內，O(1) 即可完成。

#### P2-5：`Expense` 的 `convertedAmount` 計算可能不精確

```swift
// Expense.swift:45
self.convertedAmount = exchangeRate == 0 ? 0 : (amount * quantity) / exchangeRate
```

`Decimal` 除法沒有指定精度，可能產生無限循環小數。建議使用 `NSDecimalNumberHandler` 控制四捨五入行為。

#### P2-6：專案完全沒有 Unit Test

`DietaryParser`、`TourMemberMapper`、`TourMemberParser` 這些有複雜規則邏輯的模組，非常適合寫 Unit Test。建議至少先為：
1. `DietaryParser.parseWithRules` — 各種備註格式的解析正確性
2. `TourMemberMapper.splitNameCell` — 中英文姓名分割
3. `TourMemberMapper.parseDate` — 多格式日期解析

---

## 三、與 CODE_REVIEW2.md 的交叉比對

### ✅ CODE_REVIEW2 正確指出且我完全同意的

| 項目 | 我的評估 |
|------|----------|
| `@Query` 全表掃描需改 `#Predicate` | ✅ 最高優先，完全同意 |
| `DateFormatter` 需改 `static` 快取 | ✅ 同意 |
| CalendarManager `removeEvent` 靜默失敗 | ✅ 同意，我提升為 P0 |
| `findOrCreateCityInExtension` 重複 | ✅ 同意，改 `internal` 即可 |
| SupabaseManager 上帝物件 | ✅ 同意需拆分 |
| PlacePhotoManager 錯置目錄 | ✅ 同意 |
| 三段式重複程式碼需 Protocol 泛型化 | ✅ 同意 |

### ⚠️ CODE_REVIEW2 遺漏或需要修正的

| 項目 | 說明 |
|------|------|
| **🔴 `deleteTeam` 遺漏 TourMember** | CODE_REVIEW2 說此問題「已解決」，但實際上只清了 5 種子模型，**遺漏了 TourMember**。這是新發現的 P0 問題。 |
| **🔴 SettingsView App ID 佔位符** | CODE_REVIEW2 僅提及「確保 Placeholder 已替換」，但實際上 `YOUR_APP_ID` 仍然在程式碼中，這是上架前必須修復的。 |
| **🔴 DietaryParser AI 無 timeout** | CODE_REVIEW2 完全沒提及。Foundation Models 回應慢時 UI 會無限轉圈，需加 5 秒超時保護。 |
| **🔴 TourDocument 絕對路徑問題** | CODE_REVIEW2 未提及。雖然 `TourMemberSourceView` 已做短期修法 (`resolveFileURL`)，但長期需改為相對路徑儲存 + migration。 |
| **設定頁 AI 開關** | CODE_REVIEW2 未提及。但重新審查後確認 SettingsView **已完成** Apple Intelligence Toggle 的實作，設計合理。 |
| **BackupManager 檔案過大** | CODE_REVIEW2 只提到 SupabaseManager 過大，沒注意到 BackupManager 也有 921 行。 |
| **缺少 Unit Test** | CODE_REVIEW2 完全沒提到測試。對於 Parser/Mapper 這類純邏輯模組，Unit Test 是品質保證的基礎。 |
| **Concurrency 標註** | CODE_REVIEW2 提到了 HotelSupportingTypes 的 Sendable 修正，但沒有審查其他 Manager 的 Concurrency 安全性。 |
| **`hasBirthdayOnTrip` 演算法效率** | CODE_REVIEW2 未提及。 |
| **`Decimal` 精度問題** | CODE_REVIEW2 未提及。 |

### 🔄 CODE_REVIEW2 需要修正的說法

| CODE_REVIEW2 原文 | 修正 |
|-------------------|------|
| 「SQL Injection 部分解決——SupabaseManager.swift 裡的 searchRemoteHotels 仍舊使用未轉義的 query」 | 經我檢查，`SupabaseManager+Search.swift` 中的 `fetchRemoteHotelPreviews`、`fetchRemoteRestaurantPreviews`、`fetchRemoteAttractionPreviews` **已全部使用 `sanitizeQuery`**。需要確認主檔 `SupabaseManager.swift` 是否還有其他搜尋入口。 |
| 「SupabaseManager 保有近千行」 | 實際是 924 行。主要原因是底部堆了大量的 Payload Struct 和 `AnyCodable`——這些應該搬到獨立的 `Models/RemoteModels.swift`。 |

---

## 四、優先修復路線圖

### 🚨 第零步：上架前必做（1 小時內可完成）

- [ ] 替換 `SettingsView.swift` 中的 `YOUR_APP_ID`
- [ ] `deleteTeam` 補上 TourMember 清理
- [ ] `CalendarManager.removeEvent` 改為 `do-catch`
- [ ] `DietaryParser` AI 路徑加上 5 秒 timeout 保護

### 📊 第一波：效能優化（預估 2-3 小時）

- [ ] `TeamWorkspaceView`、`ExpenseListView`、`StatsView` 的 `@Query` 改用 `init` 注入 `#Predicate`
- [ ] 建立 `DateFormatters` 工具類，消除所有臨時建立的 formatter（含 TeamWorkspaceView:173, 389）
- [ ] `TourMember.hasBirthdayOnTrip` 改為 O(1) 演算法

### 🏗️ 第二波：架構整理（預估 4-5 小時）

- [ ] 將 `findOrCreateCity` 改為 `internal`，刪除 `findOrCreateCityInExtension`
- [ ] 拆分 `BackupManager.swift`：Backup Structs → `Models/BackupModels.swift`
- [ ] 拆分 `SupabaseManager.swift`：Payload Structs + AnyCodable → `Models/RemoteModels.swift`
- [ ] 移動 `PlacePhotoManager.swift` → `Managers/`
- [ ] 為 Manager 補上正確的 `@MainActor` / `Sendable` 標註
- [ ] `TourDocument.fileURL` 改存相對路徑 + 寫 migration（長期修法，替代 `resolveFileURL` 短期方案）

### 🧪 第三波：品質提升（預估 2-3 小時）

- [ ] 設計 `SyncablePlace` Protocol，泛型化三段式重複程式碼
- [ ] 為 `DietaryParser`、`TourMemberMapper` 建立基本 Unit Test
- [ ] `ExchangeRateManager` 的基準幣種抽成可配置常數
- [ ] `Expense` 的 `Decimal` 除法加上精度控制

---

## 五、結語

這是一個功能豐富且實用的領隊專用 App，以 vibe coding 的方式能做到這樣的完成度令人印象深刻。程式碼的命名規範、MARK 標記、中文註解都維持得很好，可讀性高。

**最關鍵的三件事**：
1. 上架前務必修好 P0 的五個問題（App ID、TourMember 孤兒、CalendarManager 靜默失敗、DietaryParser AI timeout、TourDocument 絕對路徑）
2. `@Query` 全表掃描是目前最大的效能隱患，建議優先重構
3. 三段式重複程式碼是未來維護的最大風險，每修一個 bug 都要記得改三份

如果您準備好了，我可以立即從「第零步」開始動手幫您修正。
