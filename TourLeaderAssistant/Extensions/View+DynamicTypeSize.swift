import SwiftUI

extension View {
    func appDynamicTypeSize(_ preference: String) -> some View {
        let size: DynamicTypeSize = switch preference {
        case "large":   .xLarge
        case "xlarge":  .xxLarge
        case "xxlarge": .xxxLarge
        default:        .large
        }
        return self.dynamicTypeSize(size)
    }
}
