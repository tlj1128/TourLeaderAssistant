import SwiftUI

struct HotelAnnouncementView: View {
    let hotel: PlaceHotel

    @State private var announcementText: String = ""
    @State private var showCopied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // 說明文字
                        Text("以下訊息已依飯店資料自動整理，複製後可在 LINE 直接貼上並依實際情況微調。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // 公告內容
                        Text(announcementText)
                            .font(.system(.body, design: .default))
                            .lineSpacing(4)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("AppCard"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textSelection(.enabled)
                            .padding(.horizontal)

                        // 複製按鈕
                        Button {
                            UIPasteboard.general.string = announcementText
                            withAnimation { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopied = false }
                            }
                        } label: {
                            Label(
                                showCopied ? "已複製！" : "複製文字",
                                systemImage: showCopied ? "checkmark.circle.fill" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(showCopied ? .green : Color("AppAccent"))
                        .animation(.easeInOut(duration: 0.2), value: showCopied)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("LINE 公告訊息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                announcementText = generateAnnouncement()
            }
        }
    }

    // MARK: - 公告產生邏輯

    private func generateAnnouncement() -> String {
        var lines: [String] = []

        // ── 飯店名稱 ──
        let name = hotel.nameZH.isEmpty
            ? hotel.nameEN
            : "\(hotel.nameEN)\n\(hotel.nameZH)"
        lines.append("🏨 \(name)")

        // ── 樓層與時間 ──
        let fh = hotel.floorsAndHours
        var floorLines: [String] = []

        if !fh.breakfastRestaurantFloor.isEmpty {
            var line = "🍽 早餐在 \(fh.breakfastRestaurantFloor)"
            if !fh.breakfastHours.isEmpty { line += "，\(fh.breakfastHours)" }
            floorLines.append(line)
        }
        if !fh.lobbyFloor.isEmpty {
            floorLines.append("大廳在 \(fh.lobbyFloor)")
        }
        if !fh.poolFloor.isEmpty {
            var line = "游泳池在 \(fh.poolFloor)"
            if !fh.poolHours.isEmpty { line += "，\(fh.poolHours)" }
            floorLines.append(line)
        }
        if !fh.gymFloor.isEmpty {
            var line = "健身房在 \(fh.gymFloor)"
            if !fh.gymHours.isEmpty { line += "，\(fh.gymHours)" }
            floorLines.append(line)
        }

        if !floorLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: floorLines)
        }

        // ── Wi-Fi ──
        let wifi = hotel.wifi
        let hasWifi = !wifi.network.isEmpty || !wifi.password.isEmpty || !wifi.loginMethod.isEmpty
        if hasWifi {
            lines.append("")
            lines.append("🛜 Wi-Fi")
            if !wifi.network.isEmpty {
                lines.append("網路名稱：\(wifi.network)")
            }
            if !wifi.password.isEmpty {
                lines.append("密碼：\(wifi.password)")
            } else if !wifi.loginMethod.isEmpty {
                // 沒有密碼但有連線方式（例如「密碼在房卡套上」）
                lines.append(wifi.loginMethod)
            }
        }

        // ── 撥號 ──
        let pd = hotel.phoneDialing
        let hasDialing = !pd.roomToFront.isEmpty || !pd.roomToRoom.isEmpty
        if hasDialing {
            lines.append("")
            if !pd.roomToFront.isEmpty {
                lines.append("☎️ 撥櫃檯按 \(pd.roomToFront)")
            }
            if !pd.roomToRoom.isEmpty {
                lines.append("☎️ 房間撥房間：\(pd.roomToRoom)")
            }
            lines.append("領隊房號：[請填入]")
            lines.append("找領隊請撥：[請自行填入]")
        }

        // ── 備註（surroundingsAndNotes）放最後 ──
        if !hotel.surroundingsAndNotes.isEmpty {
            lines.append("")
            lines.append(hotel.surroundingsAndNotes)
        }

        return lines.joined(separator: "\n")
    }
}
