# TourLeaderAssistant — 第 2 次 Code Review (比對追蹤)

> **前次審查日期**：2026-04-09  
> **本次複查日期**：2026-04-23  
> **審查目標**：比對上一次 `CODE_REVIEW.md` 提出的改善計畫清單，檢視修復進度，並結合最新觀察，歸納下一步必須優先執行的重構事項。

---

## 📈 修復進度總結

經過交叉比對，您已經針對前次的 Code Review 進行了多項核心邏輯的修復，特別是資料一致性與安全性部分。以下是各議題的追蹤狀態：

### ✅ 已修復 (Fixed)

1. **`deleteTeam` 孤兒資料問題**：
   * **狀態：已解決**。您在 `TeamListView.swift` 中的 `deleteTeam` 方法裡，正確加入了針對 `Expense`、`Income`、`TourFund`、`Journal`、`TourDocument` 各別 fetch 後並 `.delete()` 的補救代碼。雖然使用手動清除而非 `@Relationship`，但確實解決了孤兒資料殘留問題。
2. **照片刪除邏輯的 `file_name` 碰撞風險**：
   * **狀態：已解決**。在 `SupabaseManager+Photos.swift` 中，呼叫 `deleteRemotePhoto` 時已經確實加上了 `.eq("place_id", value: placeRemoteID.uuidString)`，雙重驗證不再會誤刪其他地標同名檔案。
3. **`HotelSupportingTypes` 誤用 `@unchecked Sendable`**：
   * **狀態：已解決**。您已經從 `FloorsAndHours`、`HotelWifi` 等 Struct 拿掉了不必要的 `@unchecked`，使其遵循自然的 `Sendable` 特性，符合 Swift 最佳實踐。

### ⚠️ 部分修復 (Partially Fixed)

1. **SQL Injection (搜尋查詢未轉義)**：
   * **狀態：部分解決**。在 `SupabaseManager+Search.swift` 中，您引入了 `sanitizeQuery` 方法將 `%` 與 `_` 安全轉義再執行 `.or(name_en.ilike.%\(q)%)`。**但是！** `SupabaseManager.swift` 裡面的 `searchRemoteHotels` 仍舊使用未轉義的 `query` 變數來執行 `.or` 查詢，漏洞仍存在一半的 API 中。

### ❌ 尚未修復 / 被繞過的議題 (Unresolved / Bypassed)

1. **本機效能殺手：`@Query` 全表掃描**：
   * **狀態：未解決**。`TeamWorkspaceView` 與 `ExpenseListView` 依舊先把所有帳務載入記憶體 (`@Query private var allExpenses: [Expense]`)，再利用 `.filter` 篩選出該團花費。
2. **本機搜尋效能低落**：
   * **狀態：未解決**。`SupabaseManager+Search.swift` 裡的 `localHotelPreviews` 同樣是無條件 Fetch 全部後，再在記憶體裡做 `.filter`。
3. **輔助方法 `findOrCreateCity` 重複實作**：
   * **狀態：被幽默地繞過了😅**。為了避開模組權限或是檔案拆分的問題，您在 `SupabaseManager+Search.swift` 裡面直接做了一個名稱叫 `findOrCreateCityInExtension` 的複製方法。這是不良的 Workaround。
4. **`DateFormatter` 頻繁建立耗損效能**：
   * **狀態：未解決**。依然在 `View` 渲染迴圈和 `infoItem` 閉包內每次動態宣告 `let f = DateFormatter()`。
5. **上帝物件 (God Object) 尚未拆分**：
   * **狀態：未解決**。`SupabaseManager.swift` 本題依然保有近千行程式碼。
6. **重複的三段式模式**：
   * **狀態：未解決**。旅館、餐廳、景點 的各種 CRUD (Upload、Refresh、Search) 依舊是大量複製貼上的程式碼。
7. **`PlacePhotoManager` 的存放位置**：
   * **狀態：未解決**。它還躺在 `Views/Place/` 目錄夾中，沒有被移到正確的 `Managers/`。
8. **缺漏行事曆刪除的邊界錯誤捕捉**：
   * **狀態：未解決**。`CalendarManager` 的 `try? store.remove(...)` 失敗時仍會把 `calendarEventID` 設空。

---

## 🎯 接下來的「黃金三大重構目標」

基於先前的追蹤以及今日的整體架構檢視，App 的**功能面**已經非常完整且實用，現在正是該來還「技術債」的時候，讓它成為一款能順暢上架商轉的優質產品。

以下是我整理出來，我們下一步應該**優先且直接動手**的 3 個最佳化專案：

### 第一優先任務：拯救記憶體與 CPU 效能 (Data Fetching Refactor)
這是最急迫的，因為會真實影響到使用者帶長天數團體時的流暢度與電量損耗。
* **行動 1**：將 `TeamWorkspaceView` 與 `ExpenseListView` 的 `@Query` 寫法，改由 `init(team:)` 傳入，並建立嚴謹的 `#Predicate` 在 SQLite 階段就把資料濾出。
* **行動 2**：在 `SupabaseManager+Search.swift` 中的本機搜尋方法加入帶有 `Predicate` 的 `FetchDescriptor`。
* **行動 3**：抽出一個 `static let sharedFormatter = DateFormatter()`，清除 View 中所有的臨時生成。

### 第二優先任務：補完安全性與錯誤邊界 (Security & Error Handling)
系統若要在邊緣情境（沒訊號、授權突關等）下依然堅固，必須修好：
* **行動 1**：將 `SupabaseManager.swift` 漏網的 `searchRemoteHotels` (及餐廳、景點) 全數補上 `sanitizeQuery`。
* **行動 2**：為 `CalendarManager` 的 `removeEvent` 升級嚴謹的 `do-catch` 保護，避免幽靈行程。
* **行動 3**：為 Model（如 Team, Expense）補齊 `@Attribute(.unique)`，並替換有除以 0 風險的防呆措施。

### 第三優先任務：上帝物件拆散與 DRY 重構 (Architecture & Clean Code)
程式碼大掃除，減少因為複製貼上而產生的未來維護成本。
* **行動 1**：正式引入 `PlaceSyncService` 等 Service 層，將 `SupabaseManager` 的職責俐落切開。
* **行動 2**：設計 `SyncablePlace` Protocol，使用泛型把（Hotel / Restaurant / Attraction）同步的千行程式碼極簡化成一兩百行。
* **行動 3**：用 `internal` 共用方法消滅 `findOrCreateCityInExtension` 這種搞笑的手法。把 `PlacePhotoManager` 整理回家(`Managers/`)。

---

> 👨‍💻 **Antigravity 結語：**
> 
> 這份報告已經被我儲存在同層級目錄下的 `CODE_REVIEW2.md` 中。  
> 很高興看到上一版的幾個嚴重雷區已經被您（或者 Claude）排除了！  
> 
> 您希望我們立刻著手進行 **[ 第一優先任務：拯救效能 ]** 嗎？我們可以先從修改 `@Query` 和 `DateFormatter` 開始，保證改完後畫面滑動的順暢度有明顯提升！如果您準備好了，請隨時下達指令。
