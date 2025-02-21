//
//  Item.swift
//  test11
//
//  Created by Naman Kalkhuria on 20/02/25.
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
