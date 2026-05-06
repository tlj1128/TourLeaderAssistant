import SwiftUI

// MARK: - 存取需求

enum AccessRequirement {
    case verifiedLeader     // 認證領隊
    case vip                // VIP（高貢獻度）
    case verifiedOrVIP      // 其中一個即可
    case verifiedAndVIP     // 兩個都要

    var lockMessage: String {
        switch self {
        case .verifiedLeader:   return "認證領隊限定"
        case .vip:              return "VIP 會員限定"
        case .verifiedOrVIP:    return "認證領隊或 VIP 會員限定"
        case .verifiedAndVIP:   return "需同時具備認證領隊及 VIP 資格"
        }
    }
}

// MARK: - 使用者權限

struct UserPermissions {
    var isVerifiedLeader: Bool = false
    var isVIP: Bool = false

    func satisfies(_ requirement: AccessRequirement) -> Bool {
        guard AppConfigManager.shared.isPremiumCheckEnforced else { return true }
        switch requirement {
        case .verifiedLeader:  return isVerifiedLeader
        case .vip:             return isVIP
        case .verifiedOrVIP:   return isVerifiedLeader || isVIP
        case .verifiedAndVIP:  return isVerifiedLeader && isVIP
        }
    }

    // Phase 6 登入完成後從 user session 填值；目前全部 false
    static var current = UserPermissions()
}

// MARK: - AccessGate（List row 用）

struct AccessGate<Content: View>: View {
    let requirement: AccessRequirement
    @ViewBuilder let content: () -> Content

    var body: some View {
        if UserPermissions.current.satisfies(requirement) {
            content()
        } else {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray3))
                Text(requirement.lockMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
    }
}
