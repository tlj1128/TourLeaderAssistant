import Foundation
import SwiftData

// MARK: - 資料來源
// 電話國碼：https://gist.github.com/anubhavshrimal/75f6183458db8c453306f93521e93d37
// 原始資料庫：https://github.com/dr5hn/countries-states-cities-database（ODbL 授權）
// 國旗 emoji 可由 ISO code 直接計算，無需額外資料
// 幣種：ISO 4217

struct SeedData {

    // MARK: - 第一次啟動時植入國家資料

    static func seedCountriesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Country>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for item in countries {
            let country = Country(
                nameZH: item.0,
                nameEN: item.1,
                code: item.2,
                phoneCode: item.3,
                currencyCode: item.4
            )
            modelContext.insert(country)
        }

        try? modelContext.save()
    }

    // MARK: - 國家清單
    // 格式：(繁體中文名稱, 英文名稱, ISO 3166-1 alpha-2, 電話國碼, ISO 4217 幣種)

    static let countries: [(String, String, String, String, String)] = [

        // ── 東亞 ──
        ("台灣", "Taiwan", "TW", "+886", "TWD"),
        ("日本", "Japan", "JP", "+81", "JPY"),
        ("韓國", "South Korea", "KR", "+82", "KRW"),
        ("中國", "China", "CN", "+86", "CNY"),
        ("香港", "Hong Kong", "HK", "+852", "HKD"),
        ("澳門", "Macao", "MO", "+853", "MOP"),
        ("蒙古", "Mongolia", "MN", "+976", "MNT"),

        // ── 東南亞 ──
        ("泰國", "Thailand", "TH", "+66", "THB"),
        ("越南", "Vietnam", "VN", "+84", "VND"),
        ("新加坡", "Singapore", "SG", "+65", "SGD"),
        ("馬來西亞", "Malaysia", "MY", "+60", "MYR"),
        ("印尼", "Indonesia", "ID", "+62", "IDR"),
        ("菲律賓", "Philippines", "PH", "+63", "PHP"),
        ("緬甸", "Myanmar", "MM", "+95", "MMK"),
        ("柬埔寨", "Cambodia", "KH", "+855", "KHR"),
        ("寮國", "Laos", "LA", "+856", "LAK"),
        ("汶萊", "Brunei", "BN", "+673", "BND"),
        ("東帝汶", "Timor-Leste", "TL", "+670", "USD"),

        // ── 南亞 ──
        ("印度", "India", "IN", "+91", "INR"),
        ("尼泊爾", "Nepal", "NP", "+977", "NPR"),
        ("斯里蘭卡", "Sri Lanka", "LK", "+94", "LKR"),
        ("不丹", "Bhutan", "BT", "+975", "BTN"),
        ("孟加拉", "Bangladesh", "BD", "+880", "BDT"),
        ("馬爾地夫", "Maldives", "MV", "+960", "MVR"),
        ("巴基斯坦", "Pakistan", "PK", "+92", "PKR"),

        // ── 中亞 ──
        ("哈薩克", "Kazakhstan", "KZ", "+7", "KZT"),
        ("烏茲別克", "Uzbekistan", "UZ", "+998", "UZS"),
        ("吉爾吉斯", "Kyrgyzstan", "KG", "+996", "KGS"),
        ("塔吉克", "Tajikistan", "TJ", "+992", "TJS"),
        ("土庫曼", "Turkmenistan", "TM", "+993", "TMT"),

        // ── 西亞 ──
        ("土耳其", "Turkey", "TR", "+90", "TRY"),
        ("以色列", "Israel", "IL", "+972", "ILS"),
        ("約旦", "Jordan", "JO", "+962", "JOD"),
        ("黎巴嫩", "Lebanon", "LB", "+961", "LBP"),
        ("敘利亞", "Syria", "SY", "+963", "SYP"),
        ("伊拉克", "Iraq", "IQ", "+964", "IQD"),
        ("伊朗", "Iran", "IR", "+98", "IRR"),
        ("沙烏地阿拉伯", "Saudi Arabia", "SA", "+966", "SAR"),
        ("阿拉伯聯合大公國", "United Arab Emirates", "AE", "+971", "AED"),
        ("卡達", "Qatar", "QA", "+974", "QAR"),
        ("科威特", "Kuwait", "KW", "+965", "KWD"),
        ("巴林", "Bahrain", "BH", "+973", "BHD"),
        ("阿曼", "Oman", "OM", "+968", "OMR"),
        ("葉門", "Yemen", "YE", "+967", "YER"),
        ("喬治亞", "Georgia", "GE", "+995", "GEL"),
        ("亞美尼亞", "Armenia", "AM", "+374", "AMD"),
        ("亞塞拜然", "Azerbaijan", "AZ", "+994", "AZN"),
        ("賽普勒斯", "Cyprus", "CY", "+357", "EUR"),

        // ── 北歐 ──
        ("瑞典", "Sweden", "SE", "+46", "SEK"),
        ("挪威", "Norway", "NO", "+47", "NOK"),
        ("丹麥", "Denmark", "DK", "+45", "DKK"),
        ("芬蘭", "Finland", "FI", "+358", "EUR"),
        ("冰島", "Iceland", "IS", "+354", "ISK"),
        ("愛沙尼亞", "Estonia", "EE", "+372", "EUR"),
        ("拉脫維亞", "Latvia", "LV", "+371", "EUR"),
        ("立陶宛", "Lithuania", "LT", "+370", "EUR"),

        // ── 西歐 ──
        ("英國", "United Kingdom", "GB", "+44", "GBP"),
        ("愛爾蘭", "Ireland", "IE", "+353", "EUR"),
        ("法國", "France", "FR", "+33", "EUR"),
        ("德國", "Germany", "DE", "+49", "EUR"),
        ("荷蘭", "Netherlands", "NL", "+31", "EUR"),
        ("比利時", "Belgium", "BE", "+32", "EUR"),
        ("盧森堡", "Luxembourg", "LU", "+352", "EUR"),
        ("瑞士", "Switzerland", "CH", "+41", "CHF"),
        ("列支敦斯登", "Liechtenstein", "LI", "+423", "CHF"),
        ("奧地利", "Austria", "AT", "+43", "EUR"),
        ("摩納哥", "Monaco", "MC", "+377", "EUR"),

        // ── 南歐 ──
        ("葡萄牙", "Portugal", "PT", "+351", "EUR"),
        ("西班牙", "Spain", "ES", "+34", "EUR"),
        ("安道爾", "Andorra", "AD", "+376", "EUR"),
        ("義大利", "Italy", "IT", "+39", "EUR"),
        ("聖馬利諾", "San Marino", "SM", "+378", "EUR"),
        ("梵蒂岡", "Vatican City", "VA", "+379", "EUR"),
        ("馬爾他", "Malta", "MT", "+356", "EUR"),
        ("希臘", "Greece", "GR", "+30", "EUR"),
        ("阿爾巴尼亞", "Albania", "AL", "+355", "ALL"),
        ("北馬其頓", "North Macedonia", "MK", "+389", "MKD"),
        ("蒙特內哥羅", "Montenegro", "ME", "+382", "EUR"),
        ("克羅埃西亞", "Croatia", "HR", "+385", "EUR"),
        ("波士尼亞與赫塞哥維納", "Bosnia and Herzegovina", "BA", "+387", "BAM"),
        ("塞爾維亞", "Serbia", "RS", "+381", "RSD"),
        ("科索沃", "Kosovo", "XK", "+383", "EUR"),
        ("斯洛維尼亞", "Slovenia", "SI", "+386", "EUR"),

        // ── 東歐 ──
        ("俄羅斯", "Russia", "RU", "+7", "RUB"),
        ("烏克蘭", "Ukraine", "UA", "+380", "UAH"),
        ("白俄羅斯", "Belarus", "BY", "+375", "BYN"),
        ("摩爾多瓦", "Moldova", "MD", "+373", "MDL"),
        ("波蘭", "Poland", "PL", "+48", "PLN"),
        ("捷克", "Czech Republic", "CZ", "+420", "CZK"),
        ("斯洛伐克", "Slovakia", "SK", "+421", "EUR"),
        ("匈牙利", "Hungary", "HU", "+36", "HUF"),
        ("羅馬尼亞", "Romania", "RO", "+40", "RON"),
        ("保加利亞", "Bulgaria", "BG", "+359", "BGN"),

        // ── 北非 ──
        ("摩洛哥", "Morocco", "MA", "+212", "MAD"),
        ("阿爾及利亞", "Algeria", "DZ", "+213", "DZD"),
        ("突尼西亞", "Tunisia", "TN", "+216", "TND"),
        ("利比亞", "Libya", "LY", "+218", "LYD"),
        ("埃及", "Egypt", "EG", "+20", "EGP"),
        ("蘇丹", "Sudan", "SD", "+249", "SDG"),

        // ── 東非 ──
        ("衣索比亞", "Ethiopia", "ET", "+251", "ETB"),
        ("肯亞", "Kenya", "KE", "+254", "KES"),
        ("坦尚尼亞", "Tanzania", "TZ", "+255", "TZS"),
        ("烏干達", "Uganda", "UG", "+256", "UGX"),
        ("盧安達", "Rwanda", "RW", "+250", "RWF"),
        ("尚比亞", "Zambia", "ZM", "+260", "ZMW"),
        ("辛巴威", "Zimbabwe", "ZW", "+263", "ZWL"),
        ("馬達加斯加", "Madagascar", "MG", "+261", "MGA"),
        ("模里西斯", "Mauritius", "MU", "+230", "MUR"),
        ("塞席爾", "Seychelles", "SC", "+248", "SCR"),

        // ── 中非 ──
        ("喀麥隆", "Cameroon", "CM", "+237", "XAF"),
        ("剛果共和國", "Republic of the Congo", "CG", "+242", "XAF"),
        ("剛果民主共和國", "Democratic Republic of the Congo", "CD", "+243", "CDF"),

        // ── 西非 ──
        ("迦納", "Ghana", "GH", "+233", "GHS"),
        ("塞內加爾", "Senegal", "SN", "+221", "XOF"),
        ("奈及利亞", "Nigeria", "NG", "+234", "NGN"),
        ("象牙海岸", "Côte d'Ivoire", "CI", "+225", "XOF"),
        ("維德角", "Cape Verde", "CV", "+238", "CVE"),

        // ── 南非地區 ──
        ("南非", "South Africa", "ZA", "+27", "ZAR"),
        ("納米比亞", "Namibia", "NA", "+264", "NAD"),
        ("波札那", "Botswana", "BW", "+267", "BWP"),
        ("莫三比克", "Mozambique", "MZ", "+258", "MZN"),
        ("史瓦帝尼", "Eswatini", "SZ", "+268", "SZL"),
        ("賴索托", "Lesotho", "LS", "+266", "LSL"),

        // ── 北美 ──
        ("美國", "United States", "US", "+1", "USD"),
        ("加拿大", "Canada", "CA", "+1", "CAD"),

        // ── 中美洲 ──
        ("墨西哥", "Mexico", "MX", "+52", "MXN"),
        ("瓜地馬拉", "Guatemala", "GT", "+502", "GTQ"),
        ("貝里斯", "Belize", "BZ", "+501", "BZD"),
        ("宏都拉斯", "Honduras", "HN", "+504", "HNL"),
        ("薩爾瓦多", "El Salvador", "SV", "+503", "USD"),
        ("尼加拉瓜", "Nicaragua", "NI", "+505", "NIO"),
        ("哥斯大黎加", "Costa Rica", "CR", "+506", "CRC"),
        ("巴拿馬", "Panama", "PA", "+507", "PAB"),

        // ── 加勒比海 ──
        ("古巴", "Cuba", "CU", "+53", "CUP"),
        ("牙買加", "Jamaica", "JM", "+1-876", "JMD"),
        ("多明尼加共和國", "Dominican Republic", "DO", "+1-809", "DOP"),
        ("波多黎各", "Puerto Rico", "PR", "+1-787", "USD"),
        ("巴哈馬", "Bahamas", "BS", "+1-242", "BSD"),
        ("千里達及托巴哥", "Trinidad and Tobago", "TT", "+1-868", "TTD"),
        ("巴貝多", "Barbados", "BB", "+1-246", "BBD"),
        ("聖露西亞", "Saint Lucia", "LC", "+1-758", "XCD"),
        ("阿魯巴", "Aruba", "AW", "+297", "AWG"),

        // ── 南美洲 ──
        ("巴西", "Brazil", "BR", "+55", "BRL"),
        ("阿根廷", "Argentina", "AR", "+54", "ARS"),
        ("智利", "Chile", "CL", "+56", "CLP"),
        ("秘魯", "Peru", "PE", "+51", "PEN"),
        ("哥倫比亞", "Colombia", "CO", "+57", "COP"),
        ("厄瓜多", "Ecuador", "EC", "+593", "USD"),
        ("玻利維亞", "Bolivia", "BO", "+591", "BOB"),
        ("巴拉圭", "Paraguay", "PY", "+595", "PYG"),
        ("烏拉圭", "Uruguay", "UY", "+598", "UYU"),
        ("委內瑞拉", "Venezuela", "VE", "+58", "VES"),
        ("蓋亞那", "Guyana", "GY", "+592", "GYD"),
        ("蘇利南", "Suriname", "SR", "+597", "SRD"),

        // ── 澳洲與紐西蘭 ──
        ("澳洲", "Australia", "AU", "+61", "AUD"),
        ("紐西蘭", "New Zealand", "NZ", "+64", "NZD"),

        // ── 美拉尼西亞 ──
        ("斐濟", "Fiji", "FJ", "+679", "FJD"),
        ("萬那杜", "Vanuatu", "VU", "+678", "VUV"),
        ("巴布亞紐幾內亞", "Papua New Guinea", "PG", "+675", "PGK"),
        ("索羅門群島", "Solomon Islands", "SB", "+677", "SBD"),

        // ── 密克羅尼西亞 ──
        ("帛琉", "Palau", "PW", "+680", "USD"),
        ("關島", "Guam", "GU", "+1-671", "USD"),
        ("北馬里亞納群島", "Northern Mariana Islands", "MP", "+1-670", "USD"),
        ("密克羅尼西亞聯邦", "Micronesia", "FM", "+691", "USD"),
        ("馬紹爾群島", "Marshall Islands", "MH", "+692", "USD"),

        // ── 玻里尼西亞 ──
        ("法屬玻里尼西亞", "French Polynesia", "PF", "+689", "XPF"),
        ("薩摩亞", "Samoa", "WS", "+685", "WST"),
        ("東加", "Tonga", "TO", "+676", "TOP"),
        ("庫克群島", "Cook Islands", "CK", "+682", "NZD"),
        ("新喀里多尼亞", "New Caledonia", "NC", "+687", "XPF"),
    ]
}
