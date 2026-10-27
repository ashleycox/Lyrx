//
//  Item.swift
//  Lyrx
//
//  Created by Ashley Cox on 27/10/2026.
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
