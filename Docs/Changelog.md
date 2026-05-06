# TourLeaderAssistant Changelog

> 記錄每個重要 Build 的新增功能與修改內容
> Build 11 起（首次通過 External TestFlight 審查）

---

## Build 15 — 2026/05/03–06（TestFlight 測試說明）

新功能

【團員名單】正式開放測試
可以將旅行社的分房表 or 團體大表匯入 App，自動建立本團的完整成員資料。
支援的檔案格式：
Excel（.xlsx）、Word（.docx）— iOS 18 以上裝置即可使用
PDF、圖片（JPG、PNG、HEIC）— 需 iOS 26 以上裝置
匯入後系統會自動辨識姓名、護照號碼、效期、性別、飲食備註等欄位，可以在確認頁調整對應關係，再一鍵建立所有團員資料。

地點庫欄位新增
景點：新增「建議停留時間」與「廁所資訊」欄位
餐廳：新增「容客數」、「付款方式」、「團體優惠」欄位

功能調整
飲食需求解析為純規則辨識
資料讀取 & 操作效能提升

已知問題（團員名單匯入）
PDF / 圖片匯入時，中文姓名辨識偶有錯誤，可在預覽頁手動修正
少數情況下第一位團員資料可能被誤判為表頭而略過，可在預覽頁手動補入

---

## Build 15 — 2026/05/03–06

### 新增功能

**團員名單 OCR 升級到 iOS 26 `RecognizeDocumentsRequest`**

- 圖片 / PDF 解析改走 iOS 26 Vision 結構化辨識，直接拿到表格（rows × cells）；iOS 18–25 圖片 / PDF / 相機入口整個隱藏，只露 xlsx / docx
- 設計原則：1 Vision row = 1 RawTable row，cell 內 `\n` 保留不展開，由 mapper 用 field type 自行決定怎麼吃多行 cell
- 新 `TourMemberStructuredPreviewView`（iOS 26 cell 流程專屬 preview），cell 多行直接 `lineLimit(nil) + fixedSize` 撐高
- autodetect：`looksLikeHeaderRow`（每 cell 看第一行是否為 ≤ 8 字 label）+ `detectField`（內容驅動，偵測護照三合一、英中合一、單行身分證、序號等）
- 上傳檔案 picker（iOS 26+）多收 `pdf / jpg / png / heic`；新增「相機與相簿」section（iOS 26+）

**新欄位類型**

- `.passportFull`：護照號碼 + 發照日 + 效期 三合一單欄多行（從多行 cell 抽號碼 + 取最大日期當效期）
- `.nationalID`：台灣身分證；首位數字 1=M、2=F；只在 `.gender` 為 nil 時補
- `.remarkEssential`：備註（僅需求）— 過濾保留含關鍵字的行（機位 / 房 / 餐 / 飲食 / 過敏 / 輪椅…），地址電話自動丟掉
- `.passportExpiry` 升級支援多行 cell（取最大日期）
- 下拉選單順序重排：略過 → 姓名 → 個資 → 護照 → 房 / 備註，`.remarkEssential` 排 `.remark` 前

### 功能調整 / 修復

- **DocXMLParser bug 修**：同一 `<tc>` 內多個 `<p>` 改用 `\n` 串接（之前段落會黏在一起，跟 Vision / xlsx 多行 cell 處理不一致）
- 移除舊 `VNRecognizeTextRequest` 圖片 OCR 路徑（連同 `TourMemberOCRMappingView` 整支砍）
- 移除 `PDFParseSpike` 與 SettingsView 內對應的 Debug 入口
- **SwiftData 效能重構**：移除 `TeamWorkspaceView` 與 `ExpenseListView` 中導致全表掃描的 `@Query`，改用 `init(team:)` 配合 `#Predicate` 在 SQLite 層級精準過濾單團資料
- **NavigationLink 升級**：`TeamListView` 從舊版 `NavigationLink(destination:)` 改為 `NavigationLink(value:)` + `.navigationDestination`，解決急切初始化導致的點擊失效與不必要資源消耗
- **SwiftData 關聯更新延遲修復**：`CityPickerView` / `CityManagementView` 新增城市後補上 `try? modelContext.save()`，解決新增後列表不秒顯示的 Bug

### 地點庫欄位擴充（2026/05/06）

**景點新欄位**
- 建議停留時間（例：30–45 分鐘），方便安排行程
- 廁所資訊：景點內廁所位置、附近免費公廁等，自由文字填寫；未來由進階會員 / VIP 限定查看（目前全開）

**餐廳新欄位**
- 容客數（確認能否接整個團體）
- 付款方式（現金 / 刷卡 / 行動支付等）
- 團體優惠

**權限系統基礎建設**
- 新增 `AccessControl.swift`（`AccessRequirement` / `UserPermissions` / `AccessGate`）
- 新增 Supabase app_config key `feature_premium_check`：false = 全開（目前），true = 執行進階 / VIP 資格檢查
- Phase 6 登入完成後接入真實 user tier，不需重新 build

### 飲食解析調整（2026/05/06）

- 移除 Apple Intelligence 飲食禁忌 AI 補充路徑（`DietaryParserAI.swift` 整支刪除）
- 飲食解析改為純 rule-based，結果更穩定、無超譯風險
- 設定頁 Apple Intelligence 開關保留（供未來其他功能使用）

### 規劃調整（2026/05/06）

- Phase 6 範圍擴充，提前納入：景點廁所及細節資料欄位擴充、UI/UX 調整、Vercel 基礎建設（API key proxy、app config 控制端、意見回饋後台、進階會員審核後台）、In-app Landing Page
- 新增待處理：AI 飲食禁忌超譯（Foundation Model 指令遵從不穩，飲食過敏有安全風險，考慮移除 AI 補充路徑）
- Phase 8 移除 Vercel 基礎建設條目；Phase 9 移除景點廁所欄位擴充條目

### 已知議題

- **中文姓名 OCR 準確度** — `0919團體總表.pdf` 實測 16 筆裡 6 筆中文名字有誤（preview 可手改）。可考慮：PDF render scale 從 2.0 拉到 3.0、相機路徑加 `VNDocumentCameraViewController` 透視校正、拍照前 UI 指引（光線 / 對齊）、`RecognizeDocumentsRequest` 是否有 language hint 待查
- **Member 1 被吃掉** — 當 Vision 把第二行 header 跟第一筆團員 cell 合併時，autodetect 會把整列判定為表頭跳過，造成 member 1 missing。已接受 workaround：在最終 `TourMemberPreviewView` 手動補，或把 dataStartRow 往前推一格容忍髒資料

---

## Build 14 — 2026/04/27–28

### 新增功能

**意見回饋改版**
- `FeedbackView` 改為兩步驟流程：Step 1 填寫內容（類型、標題、說明、附截圖最多3張）、Step 2 確認送出（預覽、系統資訊自動帶入、email 選填）
- 截圖上傳至 Supabase Storage `feedback-screenshots` bucket
- 系統資訊自動帶入：App 版本、iOS 版本、裝置型號
- 新增 `MyFeedbackView`：以 device_id 查詢歷史回饋，顯示 status / developer_reply
- `SettingsView` 【支持與回饋】區塊加入「我的回饋」入口
- Supabase `feedback` 表新增欄位：`email`、`screenshots`、`status`（pending/read/replied）、`developer_reply`、`ios_version`、`device_model`、`replied_at`
- `replied_at` 由 Postgres trigger 自動寫入（status 改為 replied 時）
- status 加入 check constraint 防止非法值

**收據拍照存檔**
- `Expense` 欄位 `receiptImagePath` 改為 `receiptImagePathsData`（JSON 陣列），支援多張收據照片
- 新增 `ReceiptPhotoManager`（存於 `Documents/ReceiptPhotos/`，長邊 1080px 壓縮）
- `AddExpenseView`、`EditExpenseView` 收據 Section 加入拍照（`CameraView`）與相簿選取（`PhotosPicker`）入口
- 拍照後依 `savePhotoToAlbum` 設定決定是否存入系統相簿

### 功能調整

**幣種選單擴充**（feature flag: `feature_currency_picker`）
- 新增 `CurrencyPicker` 元件（`Components/`），支援分區顯示、搜尋（幣種代碼 / 英文國名 / 中文國名）
- 五個幣種選單（AddExpenseView、EditExpenseView、AddIncomeView、EditIncomeView、AddTourFundView）改為 Menu 下拉 + 「更多幣種…」入口
- 優先顯示：目的地國家幣種 + 本團最近使用 + 常用幣種，去重排列

**統計頁改版**
- 累計統計（完成團次、總天數、各幣種收入總額）固定顯示於頂部
- 年度統計改為 Picker 選單切換，有資料的年份才顯示
- 各幣種收入改為可收合卡片，展開查看各類型明細

**DietaryParser 補充**
- rule-based 新增：不吃辣（不辣 / 怕辣 / 避辣）、糖尿病飲食（低糖 / 控糖）、低鈉飲食（少鹽 / 限鈉）
- AI 補充結果以紫色 AI badge 加注，不直接覆蓋 rule-based 結果
- 解析結果快取至 UserDefaults（key: `dietary_{teamID}_{memberID}`），避免重複解析
- AI 開關切換時自動清除所有飲食解析快取
- 【團員提醒事項】標題列加 AI badge（useLocalAI 開啟時顯示）

**架構整理**
- `CameraView` 從 `PlacePhotoView.swift` 抽出，移至 `Components/CameraView.swift`
- `LibraryPickerView` 移除（已由 `PhotosPicker` 取代，地點照片早已改用 `PhotosPicker`）
- `NSPhotoLibraryUsageDescription` 從 Info.plist 移除（`PhotosPicker` 不需要相簿讀取權限）

**Feature Flag 機制**
- 新增 `AppConfigManager` feature flag 支援，由 Supabase `app_config` 遠端控制
- 目前 flags：`feature_member_list`、`feature_local_ai`、`feature_currency_picker`
- 本機預設全部 `false`，連線後依 Supabase 值更新，UserDefaults 快取離線可用
- 【團員名單】卡片改由 `feature_member_list` 控制（取代原本的 `isLocked: true`）
- 【智慧功能】Section 改由 `feature_local_ai` 控制（取代原本的 `if false {}`）

**Debug 工具**（僅 Debug build 顯示）
- `SettingsView` 底部加入【開發者工具】Section
- `DebugDataGenerator`：產生完整測試資料（4個團、15名團員、支出/收入/日誌/地點）
- 測試資料以 `[TEST]` 前綴標記，清除時只移除標記資料

### 內部調整（2026/04/28）

**檔案結構整理**
- 拼字修正：`JournalDetailVIew` → `View`、`HotelSuporting` → `Supporting`
- 新增 `Views/Member/`，收 6 個 `TourMember*` 檔（自 `Views/Team/`）
- 新增 `Utilities/`、`Utilities/Debug/`，收 `SeedData`、`DebugDataGenerator`
- 新增 repo 根 `Docs/`，收 `Changelog` / 規格文件 / 開發進度紀錄（去掉版本與日期後綴）
- `PrivacyInfo.xcprivacy` 從 `Managers/` 搬到專案根
- `SupabaseManager+Photos` / `+Search` 從 `Extensions/` 搬到 `Managers/`（與 `SupabaseManager.swift` 並列）
- pbxproj `membershipExceptions` 移除已搬走的 markdown 條目

**Debug build 強制啟用 feature flag**
- `isMemberListEnabled` / `isLocalAIEnabled` / `isCurrencyPickerEnabled` 在 `#if DEBUG` 下直接回傳 true，方便本機測試開發中功能
- Release build 仍由 Supabase `app_config` 控制

**DebugDataGenerator 修復**
- `generate` / `clear` 用 `context.transaction` 包整批變動，修復 SwiftUI `@Query` 看到中間狀態而 fatal 在 `Team.status.getter` 的 crash
- 移除無作用的 `Task.detached + MainActor.run` wrapping
- 飯店與餐廳電話前綴依實際城市對應（Tokyo +81-3、Osaka +81-6、Seoul +82-2）
- `testMemberCount` 常數化，`paxCount` / `roomCount` / member prefix 數量同步，避免顯示「20 人」但實際 15 員的不一致
- `groupLabel` 索引加 cap，避免改動 prefix 數量時 array out of bounds

**死碼清除**
- 移除完全未被使用的 `CurrencyPicker.CurrencyInfo` struct（原本宣告後改用 tuple 但忘了刪）

---

## Build 13 — 2026/04/23–24

### Code Review 修復

**資料安全**
- `deleteTeam` 補上 TourMember 清理，刪除團體時不再留下孤兒資料
- 照片刪除從單一 `file_name` 條件改為 `place_id + file_name` 雙重條件，避免跨地點碰撞

**Bug 修復**
- `CalendarManager.removeEvent` 改為 do-catch，刪除行事曆事件失敗時保留 `calendarEventID`，不再誤清空
- `TourDocument` 新增 `resolvedURL` computed property，以 `teamID + fileName` 動態重組沙盒路徑，解決 App 更新後文件路徑失效問題；`DocumentListView`、`TourMemberSourceView` 全面改用 `resolvedURL`
- `EditHotelView`、`EditRestaurantView`、`EditAttractionView` 外層加回 `NavigationStack`，修復儲存按鈕消失問題
- `DietaryParser` AI 路徑加上 5 秒 timeout（`withThrowingTaskGroup`），避免 30 人團解析時無限等待

**效能優化**
- `TourMember.hasBirthdayOnTrip` 從逐日迴圈改為 O(1) 演算法（最多 2 次 Calendar 計算）
- `DateFormatter` 在 `TeamWorkspaceView`、`ExpenseListView`、`TourMemberMapper`、`BackupManager` 改為 `static let`，避免在渲染路徑重複建立

**架構整理**
- `PlacePhotoManager` 從 `Views/Place/` 移至 `Managers/`
- `SupabaseManager.findOrCreateCity` 從 `private` 改為 `internal`，移除 Extension 中的重複實作 `findOrCreateCityInExtension`
- `SupabaseManager` 三個 `searchRemote` 方法套用 `sanitizeQuery`（原已有，補齊漏網之魚）

**UI 調整**
- 【團員名單】卡片暫時設為鎖定狀態（`isLocked: true`），subtitle 顯示「功能開發中」
- 【智慧功能】Section 暫時隱藏，尚未開放給使用者

---

## Build 12 — 2026/04/22–23

### 新增：團員名單（暫時隱藏）

**資料模型**
- 新增 `TourMember` SwiftData Model（nameEN、nameZH、gender、birthday、passportNumber、passportExpiry、roomLabel、groupLabel、remark、sortOrder）
- 新增 `ParsedMember` 解析預覽用暫存結構
- `TourDocument` 新增 `roomingList` category；`guestList` displayName 改為「團體大表」

**名單匯入**
- `TourMemberParser`：自寫 ZIP 解壓 + XMLParser，支援 xlsx/docx；修正 inflate() bug（移除錯誤的 zlib header prepend）；移除 CoreXLSX 依賴
- `TourMemberMapper`：欄位對應邏輯，含 autoDetect 表頭偵測、splitNameCell 英中分割、日期解析；房號有指定欄位時空白繼承前一筆，未指定時預設兩兩一間；房號 filter 只保留數字字元
- `TourMemberRawPreviewView`：xlsx/docx 表格預覽 + 欄位對應 UI
- `TourMemberOCRMappingView`：圖片 OCR 專用欄位對應頁（Vision，zh-Hant + zh-Hans + en-US）
- `TourMemberPreviewView`：解析結果預覽確認頁
- `TourMemberSourceView`：來源選擇（xlsx/docx/圖片/截圖），PDF 引導截圖

**名單管理**
- `TourMemberListView`：toolbar ellipsis.circle Menu（排序、匯入、編輯）、編輯模式多選刪除（含全選）、Context Menu 分房分組、排序四維度（原始／分房／組別／年齡）、分房序號 01/02/03、分組代號 A/B/C
- `TourMemberDetailView`：單筆團員詳細／編輯

**飲食需求解析**
- `DietaryParser`：rule-based 解析器，機上段提取 + 行程中分類（過敏→素食→不吃特定食物）
- `DietaryParserAI`：`@available(iOS 26, *)` AI 輸出型別，使用 `@Generable`，獨立成檔
- `FoundationModelManager`：`@available(iOS 26, *)` Foundation Models 統一呼叫介面

**工作空間**
- `TeamWorkspaceView` 新增【團員名單】卡片（第四格）、輸出文件改為全寬（第五格）
- 新增【團員提醒事項】卡片：行程中生日提醒 + 飲食需求分組顯示（機上／行程中），摺疊／展開
- `SettingsView` 新增【智慧功能】Section（含 useLocalAI 開關）

**`TourLeaderAssistantApp`**：schema 加入 `TourMember.self`

---

## Build 11 — 2026/04/19（首次通過 External TestFlight 審查）

### 新增功能

**網路偵測**
- `NetworkMonitor`：NWPathMonitor 偵測 Wi-Fi / 行動數據
- 上傳前若為行動數據，alert 顯示預估上傳大小（不強制擋住）
- 套用範圍：`PlaceLibraryView`、`HotelDetailView`、`RestaurantDetailView`、`AttractionDetailView`、`PlacePhotoManageView`

### Bug 修復 / 調整
- `EditHotelView` 移除 NavigationStack wrapper 和取消按鈕（注意：Build 13 已加回）
- `SettingsView` 支持與回饋按鈕樣式修正

---

## Build 10 — 2026/04/16–17

### 新增功能

**PrivacyInfo**
- 新增 `PrivacyInfo.xcprivacy`：UserDefaults（CA92.1）、File Timestamp（C617.1）、Disk Space（E174.1）

**In-App Purchase**
- `TipStore`：StoreKit 2 消耗性 IAP，三個選項（NT$190 / NT$290 / NT$390）
- `DonateView`：購買成功顯示感謝 Alert；emoji 更新（🥤／🍹／☕）
- `SettingsView` 加入抖內入口；NavigationLink foregroundStyle 修正

### 確認事項
- App Store Connect：三個 IAP 產品 Ready to Submit；付費 App 協議、銀行帳戶、稅務表格均到位
- 沙盒測試（build 9）：可正常載入產品並發起購買

---

## Build 9 — 2026/04/15

### 新增功能

**iCloud 備份**
- `BackupManager`：備份內容含 Team、Expense、Income、TourFund、Journal、CustomType、City、本機地點、地點照片、個人基本資料（ProfileBackup）
- Decimal 序列化為 String；City 逐筆刪除；自動保留最近 5 個版本
- 備份存於 iCloud ubiquity container 根目錄 Backups/（iCloud.com.TLJStudio.TLABackup）
- `iCloudBackupView`：完整備份／還原 UI 流程

**城市資料擴充**
- cities 表新增 is_preset 欄位，258 筆預設城市不可刪除
- `CityManagementView` 加入 isPreset 標籤顯示、預設城市 deleteDisabled

**國家資料擴充**
- SeedData 擴充至 188 國（新增西非 11 國、東非島嶼、蒲隆地、馬拉威、安哥拉、阿富汗、海地）

**其他**
- 團號改為非必填（`AddTeamView`、`EditTeamView`）
- `EditRestaurantView`、`EditAttractionView` 移除 NavigationStack wrapper 和取消按鈕
