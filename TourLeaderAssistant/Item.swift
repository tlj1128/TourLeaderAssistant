//
//  Item.swift
//  TourLeaderAssistant
//
//  Created by 杜立仁 on 2026/3/30.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
