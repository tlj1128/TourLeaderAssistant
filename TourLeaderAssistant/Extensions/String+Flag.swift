import Foundation

extension String {
    var flag: String {
        self.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar(127397 + $0.value)
        }.map { String($0) }.joined()
    }
}
