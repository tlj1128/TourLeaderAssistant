#if DEBUG
import Foundation
import SwiftData

// MARK: - DebugDataGenerator

@MainActor
struct DebugDataGenerator {

    static let testPrefix = "[TEST]"
    private static let testMemberCount = 15

    // MARK: - 隨機國家池（選幾個常見帶團目的地）

    private static let countryPool: [(nameZH: String, code: String, currency: String)] = [
        ("日本", "JP", "JPY"),
        ("韓國", "KR", "KRW"),
        ("泰國", "TH", "THB"),
        ("越南", "VN", "VND"),
        ("新加坡", "SG", "SGD"),
        ("馬來西亞", "MY", "MYR"),
        ("英國", "GB", "GBP"),
        ("法國", "FR", "EUR"),
        ("德國", "DE", "EUR"),
        ("義大利", "IT", "EUR"),
        ("西班牙", "ES", "EUR"),
        ("瑞士", "CH", "CHF"),
        ("澳洲", "AU", "AUD"),
        ("紐西蘭", "NZ", "NZD"),
        ("美國", "US", "USD"),
        ("加拿大", "CA", "CAD"),
        ("土耳其", "TR", "TRY"),
        ("埃及", "EG", "EGP"),
        ("南非", "ZA", "ZAR"),
        ("阿拉伯聯合大公國", "AE", "AED"),
    ]

    // MARK: - 隨機幾個國家（1–3個）

    private static func randomCountries() -> [(nameZH: String, code: String, currency: String)] {
        let count = Int.random(in: 1...3)
        return Array(countryPool.shuffled().prefix(count))
    }

    // MARK: - 產生所有測試資料

    static func generate(context: ModelContext) async {
        await MainActor.run {
            do {
                try context.transaction {
                    generatePlaces(context: context)
                    generateHistoricalTeams(context: context)
                    generateCurrentTeam(context: context)
                }
            } catch {
                print("[DebugDataGenerator] generate error: \(error)")
            }
        }
    }

    // MARK: - 清除所有測試資料

    static func clear(context: ModelContext) async {
        await MainActor.run {
            do {
                try context.transaction {
                    let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
                    let testTeams = teams.filter { $0.name.hasPrefix(testPrefix) }
                    let testTeamIDs = Set(testTeams.map { $0.id })

                    if let expenses = try? context.fetch(FetchDescriptor<Expense>()) {
                        expenses.filter { testTeamIDs.contains($0.teamID) }.forEach { context.delete($0) }
                    }
                    if let incomes = try? context.fetch(FetchDescriptor<Income>()) {
                        incomes.filter { testTeamIDs.contains($0.teamID) }.forEach { context.delete($0) }
                    }
                    if let journals = try? context.fetch(FetchDescriptor<Journal>()) {
                        journals.filter { testTeamIDs.contains($0.teamID) }.forEach { context.delete($0) }
                    }
                    if let funds = try? context.fetch(FetchDescriptor<TourFund>()) {
                        funds.filter { testTeamIDs.contains($0.teamID) }.forEach { context.delete($0) }
                    }
                    if let members = try? context.fetch(FetchDescriptor<TourMember>()) {
                        members.filter { testTeamIDs.contains($0.teamID) }.forEach { context.delete($0) }
                    }
                    testTeams.forEach { context.delete($0) }

                    if let hotels = try? context.fetch(FetchDescriptor<PlaceHotel>()) {
                        hotels.filter { $0.nameEN.hasPrefix(testPrefix) }.forEach { context.delete($0) }
                    }
                    if let restaurants = try? context.fetch(FetchDescriptor<PlaceRestaurant>()) {
                        restaurants.filter { $0.nameEN.hasPrefix(testPrefix) }.forEach { context.delete($0) }
                    }
                    if let attractions = try? context.fetch(FetchDescriptor<PlaceAttraction>()) {
                        attractions.filter { $0.nameEN.hasPrefix(testPrefix) }.forEach { context.delete($0) }
                    }
                }
            } catch {
                print("[DebugDataGenerator] clear error: \(error)")
            }
        }
    }

    // MARK: - 地點資料

    private static func generatePlaces(context: ModelContext) {
        // 飯店
        let hotelData: [(en: String, zh: String, city: String, phonePrefix: String)] = [
            ("[TEST] Grand Hyatt Tokyo", "東京君悅大酒店", "Tokyo", "+81-3"),
            ("[TEST] The Ritz-Carlton Osaka", "大阪麗思卡爾頓酒店", "Osaka", "+81-6"),
            ("[TEST] Park Hyatt Seoul", "首爾柏悅酒店", "Seoul", "+82-2"),
        ]

        for data in hotelData {
            let hotel = PlaceHotel(nameEN: data.en)
            hotel.nameZH = data.zh
            hotel.address = "123 \(data.city) Main Street"
            hotel.phone = "\(data.phonePrefix)-\(Int.random(in: 1000...9999))-\(Int.random(in: 1000...9999))"

            var fah = FloorsAndHours()
            fah.lobbyFloor = "1F"
            fah.breakfastRestaurantFloor = "2F"
            fah.dinnerRestaurantFloor = "2F"
            fah.poolFloor = "\(Int.random(in: 5...10))F"
            fah.gymFloor = "\(Int.random(in: 4...8))F"
            fah.breakfastHours = "07:00 – 10:00"
            fah.dinnerHours = "18:00 – 22:00"
            fah.poolHours = "09:00 – 21:00"
            fah.gymHours = "06:00 – 23:00"
            hotel.floorsAndHours = fah

            var wifi = HotelWifi()
            wifi.network = "\(data.city)_Hotel_Guest"
            wifi.password = "welcome\(Int.random(in: 1000...9999))"
            wifi.loginMethod = "連接後開啟瀏覽器，輸入房號與姓氏登入"
            hotel.wifi = wifi

            var dialing = PhoneDialing()
            dialing.roomToFront = "0"
            dialing.roomToRoom = "直撥房號"
            dialing.outsideLine = "9 + 號碼"
            dialing.notes = "國際電話：00 + 國碼 + 號碼"
            hotel.phoneDialing = dialing

            var amenities = HotelAmenities()
            amenities.roomAmenities = [
                RoomAmenity.bathtub.rawValue,
                RoomAmenity.hairDryer.rawValue,
                RoomAmenity.slippers.rawValue,
                RoomAmenity.safe.rawValue,
                RoomAmenity.kettle.rawValue,
                RoomAmenity.toothbrush.rawValue,
            ]
            amenities.hotelFacilities = [
                HotelFacility.pool.rawValue,
                HotelFacility.gym.rawValue,
                HotelFacility.restaurant.rawValue,
                HotelFacility.laundry.rawValue,
            ]
            hotel.amenities = amenities
            hotel.surroundingsAndNotes = "飯店周邊步行5分鐘內有便利商店、藥妝店與地鐵站。"
            hotel.needsSync = false
            context.insert(hotel)
        }

        // 餐廳
        let restaurantData: [(en: String, zh: String, cuisine: String, specialty: String, notes: String, phonePrefix: String)] = [
            ("[TEST] Sukiyabashi Jiro Honten", "數寄屋橋次郎本店", "日本料理", "主廚精選壽司", "需提前數月預約，午餐約30道，晚餐約20道", "+81-3"),
            ("[TEST] Din Tai Fung Shinjuku", "鼎泰豐新宿店", "台灣料理", "小籠包、蝦仁炒飯", "午餐等位約30分鐘，建議早到取號", "+81-3"),
            ("[TEST] Namdaemun Gukbap", "南大門國飯", "韓國料理", "牛骨湯飯", "24小時營業，價格實惠，觀光客必訪", "+82-2"),
        ]

        for data in restaurantData {
            let r = PlaceRestaurant(nameEN: data.en)
            r.nameZH = data.zh
            r.cuisine = data.cuisine
            r.specialty = data.specialty
            r.notes = data.notes
            r.rating = ["★★★★★", "★★★★☆", "★★★☆☆"].randomElement()!
            r.phone = "\(data.phonePrefix)-\(Int.random(in: 100...999))-\(Int.random(in: 1000...9999))"
            r.needsSync = false
            context.insert(r)
        }

        // 景點
        let attractionData: [(en: String, zh: String, ticket: String, hours: String, photo: String, notes: String)] = [
            ("[TEST] Senso-ji Temple", "淺草寺", "免費", "24小時（仲見世通09:00–19:00）", "室外可自由拍攝，本堂內禁止", "建議早上8點前抵達避開人潮"),
            ("[TEST] Gyeongbokgung Palace", "景福宮", "成人 3,000韓元，韓服免費", "09:00–18:00（週二休）", "宮殿內可拍攝，守衛交接09:00/14:00", "換穿韓服可免費入場，租借攤位在正門附近"),
            ("[TEST] Dotonbori", "道頓堀", "免費", "24小時", "全區可拍攝，格力高廣告牌是必拍地標", "晚上霓虹燈更漂亮，建議傍晚後前往"),
        ]

        for data in attractionData {
            let a = PlaceAttraction(nameEN: data.en)
            a.nameZH = data.zh
            a.ticketPrice = data.ticket
            a.openingHours = data.hours
            a.photographyRules = data.photo
            a.notes = data.notes
            a.needsSync = false
            context.insert(a)
        }
    }

    // MARK: - 歷史團

    private static func generateHistoricalTeams(context: ModelContext) {
        let cal = Calendar.current
        let now = Date()

        let configs: [(daysOffset: Int, days: Int, year: String, code: String)] = [
            (-730, 9, "2024", "A"),
            (-365, 7, "2025", "B"),
            (-180, 10, "2025", "C"),
        ]

        for config in configs {
            guard let departure = cal.date(byAdding: .day, value: config.daysOffset, to: now) else { continue }

            let countries = randomCountries()
            let mainCurrency = countries.first?.currency ?? "USD"
            let countryNames = countries.map { $0.nameZH }.joined(separator: "、")
            let name = "\(testPrefix) \(config.year) \(countryNames)\(config.days)日"
            let code = "TEST\(config.year)\(config.code)"

            let team = Team(tourCode: code, name: name, departureDate: departure, days: config.days)
            team.countryCodes = countries.map { $0.code }
            team.paxCount = testMemberCount
            team.roomCount = "\((testMemberCount + 1) / 2)"
            context.insert(team)

            generateFunds(for: team, mainCurrency: mainCurrency, context: context)
            generateExpenses(for: team, mainCurrency: mainCurrency, context: context)
            generateIncomes(for: team, context: context)
            generateJournals(for: team, context: context)
            generateMembers(for: team, context: context)
        }
    }

    // MARK: - 目前進行中的團（12天）

    private static func generateCurrentTeam(context: ModelContext) {
        let cal = Calendar.current
        guard let departure = cal.date(byAdding: .day, value: -3, to: Date()) else { return }

        let countries = randomCountries()
        let mainCurrency = countries.first?.currency ?? "USD"
        let countryNames = countries.map { $0.nameZH }.joined(separator: "、")
        let name = "\(testPrefix) 2026 \(countryNames)12日"

        let team = Team(tourCode: "TEST2026A", name: name, departureDate: departure, days: 12)
        team.countryCodes = countries.map { $0.code }
        team.paxCount = testMemberCount
        team.roomCount = "\((testMemberCount + 1) / 2)"
        team.notes = "這是測試用的進行中團體。"
        context.insert(team)

        generateFunds(for: team, mainCurrency: mainCurrency, context: context)
        generateExpenses(for: team, mainCurrency: mainCurrency, context: context)
        generateIncomes(for: team, context: context)
        generateJournals(for: team, context: context)
        generateMembers(for: team, context: context)
    }

    // MARK: - 資金

    private static func generateFunds(for team: Team, mainCurrency: String, context: ModelContext) {
        let pax = Decimal(team.paxCount ?? 20)
        let days = Decimal(team.days)

        let pettyCash = TourFund(
            teamID: team.id,
            typeName: "零用金",
            currency: mainCurrency == "TWD" ? "USD" : mainCurrency,
            initialAmount: 10 * days * pax,
            isReimbursable: true
        )
        context.insert(pettyCash)

        let mealAllowance = TourFund(
            teamID: team.id,
            typeName: "誤餐費",
            currency: "TWD",
            initialAmount: Decimal(Int.random(in: 2000...5000)),
            isReimbursable: true
        )
        context.insert(mealAllowance)
    }

    // MARK: - 支出

    private static func generateExpenses(for team: Team, mainCurrency: String, context: ModelContext) {
        let cal = Calendar.current

        // 依幣種設定常見匯率和支出項目
        let currencyConfig: [String: (rate: Decimal, items: [(String, String, Decimal, Decimal)])] = [
            "JPY": (220, [
                ("午餐費用", "餐廳", 1, Decimal(Int.random(in: 2000...6000))),
                ("晚餐費用", "餐廳", 1, Decimal(Int.random(in: 3000...8000))),
                ("景點門票", "觀光區", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 300...1500))),
                ("巴士費用", "交通", 1, Decimal(Int.random(in: 10000...25000))),
                ("伴手禮採購", "商店", 1, Decimal(Int.random(in: 3000...15000))),
                ("飲料點心", "便利商店", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 100...300))),
                ("溫泉入場費", "溫泉館", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 500...1200))),
                ("行李寄存", "車站", 1, Decimal(Int.random(in: 500...1000))),
            ]),
            "KRW": (27, [
                ("午餐費用", "餐廳", 1, Decimal(Int.random(in: 30000...80000))),
                ("景點門票", "觀光區", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 3000...15000))),
                ("巴士費用", "交通", 1, Decimal(Int.random(in: 100000...300000))),
                ("伴手禮採購", "免稅店", 1, Decimal(Int.random(in: 50000...200000))),
            ]),
            "THB": (11, [
                ("午餐費用", "餐廳", 1, Decimal(Int.random(in: 500...2000))),
                ("景點門票", "觀光區", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 100...500))),
                ("巴士費用", "交通", 1, Decimal(Int.random(in: 2000...8000))),
                ("按摩費用", "按摩店", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 300...800))),
            ]),
            "EUR": (35, [
                ("午餐費用", "餐廳", 1, Decimal(Int.random(in: 100...400))),
                ("景點門票", "博物館", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 10...25))),
                ("巴士費用", "交通", 1, Decimal(Int.random(in: 200...600))),
                ("伴手禮採購", "商店", 1, Decimal(Int.random(in: 50...300))),
            ]),
            "USD": (32, [
                ("午餐費用", "餐廳", 1, Decimal(Int.random(in: 100...400))),
                ("景點門票", "觀光區", Decimal(team.paxCount ?? 20), Decimal(Int.random(in: 10...50))),
                ("巴士費用", "交通", 1, Decimal(Int.random(in: 200...600))),
                ("導遊小費", "飯店大廳", 1, Decimal(Int.random(in: 100...300))),
            ]),
        ]

        let config = currencyConfig[mainCurrency] ?? currencyConfig["USD"]!
        let rate = config.rate
        let items = config.items

        for dayOffset in 1...(team.days - 2) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: team.departureDate) else { continue }
            let count = Int.random(in: 1...max(1, min(items.count, 10)))
            let shuffled = items.shuffled().prefix(count)

            for (item, location, qty, amount) in shuffled {
                let expense = Expense(
                    teamID: team.id,
                    item: item,
                    quantity: qty,
                    amount: amount,
                    currency: mainCurrency,
                    exchangeRate: rate,
                    date: date
                )
                expense.location = location
                expense.paymentMethod = [PaymentMethod.cash.rawValue, PaymentMethod.creditCard.rawValue].randomElement()
                context.insert(expense)
            }
        }

        // 台幣支出幾筆（誤餐費等）
        let twdItems = ["誤餐費", "領隊墊付款", "行政費用"]
        guard let firstDate = cal.date(byAdding: .day, value: 1, to: team.departureDate) else { return }
        let twdExpense = Expense(
            teamID: team.id,
            item: twdItems.randomElement()!,
            quantity: 1,
            amount: Decimal(Int.random(in: 500...3000)),
            currency: "TWD",
            exchangeRate: 1,
            date: firstDate
        )
        context.insert(twdExpense)
    }

    // MARK: - 收入

    private static func generateIncomes(for team: Team, context: ModelContext) {
        let cal = Calendar.current

        let incomeData: [(String, Decimal, String, Int)] = [
            ("領隊服務費", Decimal(Int.random(in: 10000...20000)), "TWD", 0),
            ("出差費", Decimal(Int.random(in: 3000...8000)), "TWD", 0),
            ("佣金", Decimal(Int.random(in: 5000...15000)), "TWD", team.days - 1),
        ]

        for (typeName, amount, currency, dayOffset) in incomeData {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: team.departureDate) else { continue }
            let income = Income(teamID: team.id, date: date, typeName: typeName, amount: amount, currency: currency)
            context.insert(income)
        }
    }

    // MARK: - 日誌

    private static let journalTemplates: [String] = [
        "今天出發順利，團員們精神都很好。在機場集合時間大家都很準時。飛機準點起飛，機上服務不錯。\n\n⚠️ 注意：有團員輕微暈機，已提供暈機藥。",
        "抵達目的地，辦理入住一切順利。飯店位置很好，步行到主要景點只需10分鐘。晚餐安排在附近餐廳，菜色豐富，團員們都很滿意。",
        "今天行程比較緊湊，早上參觀了三個景點。團員體力都還不錯，只有幾位年長的需要稍微放慢腳步。下午自由活動時間，大部分人去購物。\n\n💬 意見：有團員反映自由活動時間太短，下次可考慮調整行程。",
        "今天天氣突然變差，下午開始下雨。臨時調整行程，將室外景點改到明天，今天改去室內博物館。團員都很配合，情緒管理做得不錯。",
        "行程進入中段，團員間的互動越來越熱絡。晚餐時自發性地互相敬酒，氣氛很好。有幾位團員問是否可以安排額外購物時間。",
        "今天的重頭戲是當地文化體驗，團員們都很投入，玩得開心。晚上安排特色料理，幾乎所有人都讚不絕口。\n\n⚠️ 注意：有團員對海鮮過敏，餐廳已提前告知並另備替代餐。",
        "今天遇到小插曲，一位團員錢包找不到，後來在遊覽車上找到，有驚無險。提醒大家隨身物品要妥善保管。行程本身很順利。",
        "參觀當地最著名的景點，人潮比預期多，等待時間較長。但整體而言團員都很有耐心。下午購物時間大家都買了不少紀念品。",
        "今天是輕鬆的半自由行程，早上統一參觀一個景點後，下午讓大家自由活動。趁空檔整理帳務，零用金使用進度正常。",
        "行程接近尾聲，今晚安排告別晚宴。餐廳環境很好，菜色精緻。團員們都說這次旅遊很滿意，希望下次還能一起出遊。",
        "今天早上辦理退房，行李托運順利。前往機場途中沒有塞車，提早抵達，大家有充裕時間逛免稅商店。",
        "平安返台。所有團員安全抵達，行李無遺失。這次帶團整體很順利！\n\n💬 意見：多位團員表示飯店選擇很棒，建議下次繼續安排同等級住宿。",
    ]

    private static func generateJournals(for team: Team, context: ModelContext) {
        let cal = Calendar.current
        for dayOffset in 0...(team.days - 1) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: team.departureDate) else { continue }
            let content = journalTemplates[min(dayOffset, journalTemplates.count - 1)]
            let journal = Journal(teamID: team.id, date: date, content: content)
            context.insert(journal)
        }
    }

    // MARK: - 團員

    private static let memberPool: [(en: String, zh: String, gender: String)] = [
        ("CHEN James", "陳志明", "M"),
        ("LIN Patricia", "林雅婷", "F"),
        ("WANG Robert", "王宗翰", "M"),
        ("LEE Mary", "李美玲", "F"),
        ("CHANG William", "張柏翰", "M"),
        ("HUANG Jennifer", "黃佳蓉", "F"),
        ("WU David", "吳俊傑", "M"),
        ("LIU Linda", "劉淑芬", "F"),
        ("TSAI Richard", "蔡彥廷", "M"),
        ("YANG Barbara", "楊思穎", "F"),
        ("CHENG Joseph", "鄭冠宇", "M"),
        ("HSU Elizabeth", "許欣怡", "F"),
        ("LIAO Thomas", "廖宏恩", "M"),
        ("CHOU Susan", "周雅婷", "F"),
        ("KAO Charles", "高建國", "M"),
    ]

    private static func generateMembers(for team: Team, context: ModelContext) {
        let cal = Calendar.current
        let shuffled = memberPool.shuffled().prefix(testMemberCount)
        let groupChars = ["A", "B", "C", "D", "E"]

        for (i, member) in shuffled.enumerated() {
            // 生日：25–65 歲之間隨機，月份和日期也隨機
            let ageYears = Int.random(in: 25...65)
            let ageMonths = Int.random(in: 0...11)
            let ageDays = Int.random(in: 0...27)
            let birthday = cal.date(byAdding: DateComponents(year: -ageYears, month: -ageMonths, day: -ageDays), to: Date())

            // 護照效期：1–5 年後隨機，月份和日期也隨機
            let expiryYears = Int.random(in: 1...5)
            let expiryMonths = Int.random(in: 0...11)
            let expiryDays = Int.random(in: 0...27)
            let passportExpiry = cal.date(byAdding: DateComponents(year: expiryYears, month: expiryMonths, day: expiryDays), to: Date())
            let passportNum = "3\(Int.random(in: 10000000...99999999))"
            let roomLabel = String(format: "%02d", (i / 2) + 1)
            let groupLabel = groupChars[min(i / 5, groupChars.count - 1)]

            let dietaryOptions = [
                "不吃牛肉",
                "不吃豬肉",
                "素食",
                "海鮮過敏",
                "花生過敏",
                "不吃辣",
                "糖尿病飲食",
                "低鈉飲食",
                "機上 VGML 素食餐",
                "機上 MOML 穆斯林餐",
                "機上 HNML 印度餐",
            ]
            let remark: String? = Int.random(in: 1...10) <= 3 ? dietaryOptions.randomElement() : nil

            let tm = TourMember(
                teamID: team.id,
                nameEN: member.en,
                nameZH: member.zh,
                gender: member.gender,
                birthday: birthday,
                passportNumber: passportNum,
                passportExpiry: passportExpiry,
                roomLabel: roomLabel,
                groupLabel: groupLabel,
                remark: remark,
                sortOrder: i
            )
            context.insert(tm)
        }
    }
}
#endif
