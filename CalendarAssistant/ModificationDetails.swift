//
//  ModificationDetails.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for multi-event modification capabilities.
//

import Foundation

// Enum to represent different types of modifications
enum ModificationType: String, Codable {
    case swap
    case clear
    case copy
    case other
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "swap": self = .swap
        case "clear": self = .clear
        case "copy": self = .copy
        case "other": self = .other
        default: self = .other
        }
    }
}

// Struct to capture details of a specific event modification
struct EventModification: Codable {
    var eventTitle: String?
    var originalDate: String?
    var originalStartTime: String?
    var targetDate: String?
    var targetStartTime: String?
    var newTitle: String?
    var newLocation: String?
    var newStartTime: String?
    var newEndTime: String?
    
    enum CodingKeys: String, CodingKey {
        case eventTitle = "event_title"
        case originalDate = "original_date"
        case originalStartTime = "original_start_time"
        case targetDate = "target_date"
        case targetStartTime = "target_start_time"
        case newTitle = "new_title"
        case newLocation = "new_location"
        case newStartTime = "new_start_time"
        case newEndTime = "new_end_time"
    }
}

// Main struct to capture all details of a multi-event modification
struct ModificationDetails: Codable {
    var modificationType: ModificationType
    var timeRangeStart: String?
    var timeRangeEnd: String?
    var eventModifications: [EventModification]
    var description: String
    
    enum CodingKeys: String, CodingKey {
        case modificationType = "modification_type"
        case timeRangeStart = "time_range_start"
        case timeRangeEnd = "time_range_end"
        case eventModifications = "event_modifications"
        case description
    }
    
    // Helper computed property to get a user-friendly description
    var userFriendlyDescription: String {
        switch modificationType {
        case .swap:
            return "Swap events in the specified time range"
        case .clear:
            return "Clear events in the specified time range"
        case .copy:
            return "Copy events to the specified time range"
        case .other:
            return description
        }
    }
}
