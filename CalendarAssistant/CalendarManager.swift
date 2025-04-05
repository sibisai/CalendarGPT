//
//  CalendarManager.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25.
//  Updated with multi-event modification capabilities
//

import Foundation
import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    private var eventStore = EKEventStore()
    @Published var todaysEvents: [EKEvent] = []
    @Published var hasCalendarAccess = false
    
    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadTodaysEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadTodaysEvents()
                    }
                }
            }
        }
    }
    
    // Helper function to convert authorization status to string
    private func authStatusString(_ status: EKAuthorizationStatus) -> String {
        if #available(iOS 17.0, *) {
            switch status {
            case .notDetermined:
                return "notDetermined"
            case .restricted:
                return "restricted"
            case .denied:
                return "denied"
            case .fullAccess:
                return "fullAccess"
            case .writeOnly:
                return "writeOnly"
            @unknown default:
                return "unknown"
            }
        } else {
            // iOS 16 and earlier
            switch status {
            case .notDetermined:
                return "notDetermined"
            case .restricted:
                return "restricted"
            case .denied:
                return "denied"
            case .authorized:
                return "authorized"
                // These cases won't be reached in iOS 16, but needed for exhaustive switch
            case .fullAccess:
                return "fullAccess"
            case .writeOnly:
                return "writeOnly"
            @unknown default:
                return "unknown"
            }
        }
    }
    
    func loadTodaysEvents() {
        guard hasCalendarAccess else {
            return
        }
        
        let calendar = Calendar.current
        
        // Get start and end of today
        let startDate = calendar.startOfDay(for: Date())
        var components = DateComponents()
        components.day = 1
        let endDate = calendar.date(byAdding: components, to: startDate)!
        
        // Create the predicate for events
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        // Always filter out all-day events
        let filteredEvents = events.filter { !$0.isAllDay }
        
        // Sort events by start date
        let sortedEvents = filteredEvents.sorted {
            $0.startDate < $1.startDate
        }
        
        DispatchQueue.main.async {
            self.todaysEvents = sortedEvents
        }
    }
    
    // Create event from parsed details
    func createEventFromDetails(_ details: EventDetails) async throws {
        // Create a new event
        let event = EKEvent(eventStore: eventStore)
        
        // Set the title
        event.title = details.title
        
        // Set the date and times
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        guard let date = dateFormatter.date(from: details.date),
              let startTime = timeFormatter.date(from: details.start_time) else {
            throw NSError(domain: "CalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid date or time format"])
        }
        
        // Combine date and time
        let calendar = Calendar.current
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        
        startDateComponents.hour = startTimeComponents.hour
        startDateComponents.minute = startTimeComponents.minute
        
        guard let startDate = calendar.date(from: startDateComponents) else {
            throw NSError(domain: "CalendarManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create start date"])
        }
        
        event.startDate = startDate
        
        // Set end date
        if let endTimeString = details.end_time, let endTime = timeFormatter.date(from: endTimeString) {
            var endDateComponents = startDateComponents
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            
            endDateComponents.hour = endTimeComponents.hour
            endDateComponents.minute = endTimeComponents.minute
            
            if let endDate = calendar.date(from: endDateComponents) {
                event.endDate = endDate
            } else {
                // Default to 1 hour duration
                event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)
            }
        } else {
            // Default to 1 hour duration
            event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)
        }
        
        // Set location if available
        if let location = details.location {
            event.location = location
        }
        
        // Set calendar (default to primary calendar)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save the event
        try eventStore.save(event, span: .thisEvent)
        
        // Refresh the events list
        await MainActor.run {
            self.loadTodaysEvents()
        }
    }
    
    func listAvailableCalendars() {
        let calendars = eventStore.calendars(for: .event)
        for (index, calendar) in calendars.enumerated() {
            print("\(index + 1). \(calendar.title) (source: \(calendar.source.title)) - Writable: \(calendar.allowsContentModifications)")
        }
    }
    /*
    func checkTimeZoneSettings() {
        print("Current time zone: \(TimeZone.current.identifier)")
        print("Calendar time zone: \(Calendar.current.timeZone.identifier)")
        print("Current date: \(Date())")
        print("Start of today: \(Calendar.current.startOfDay(for: Date()))")
    }
    */
    // Update an existing event
    func updateEvent(_ event: EKEvent, with details: EventDetails) async throws {
        // Set the title
        event.title = details.title
        
        // Set the date and times
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        guard let date = dateFormatter.date(from: details.date),
              let startTime = timeFormatter.date(from: details.start_time) else {
            throw NSError(domain: "CalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid date or time format"])
        }
        
        // Combine date and time
        let calendar = Calendar.current
        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        
        startDateComponents.hour = startTimeComponents.hour
        startDateComponents.minute = startTimeComponents.minute
        
        guard let startDate = calendar.date(from: startDateComponents) else {
            throw NSError(domain: "CalendarManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create start date"])
        }
        
        event.startDate = startDate
        
        // Set end date
        if let endTimeString = details.end_time, let endTime = timeFormatter.date(from: endTimeString) {
            var endDateComponents = startDateComponents
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            
            endDateComponents.hour = endTimeComponents.hour
            endDateComponents.minute = endTimeComponents.minute
            
            if let endDate = calendar.date(from: endDateComponents) {
                event.endDate = endDate
            } else {
                // Default to 1 hour duration
                event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)
            }
        } else {
            // Default to 1 hour duration
            event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)
        }
        
        // Set location if available
        if let location = details.location {
            event.location = location
        }
        
        // Save the event
        try eventStore.save(event, span: .thisEvent)
        
        // Refresh the events list
        await MainActor.run {
            self.loadTodaysEvents()
        }
    }
    
    // Delete an event
    func deleteEvent(_ event: EKEvent) async throws {
        try eventStore.remove(event, span: .thisEvent)
        
        // Refresh the events list
        await MainActor.run {
            self.loadTodaysEvents()
        }
    }
    
    // Convert EKEvent to EventDetails for editing
    func convertToEventDetails(_ event: EKEvent) -> EventDetails {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: event.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let startTime = timeFormatter.string(from: event.startDate)
        let endTime = timeFormatter.string(from: event.endDate)
        
        return EventDetails(
            title: event.title,
            date: date,
            start_time: startTime,
            end_time: endTime,
            location: event.location,
            attendees: event.attendees?.map { $0.name ?? "" } ?? []
        )
    }
    
    // New method to apply modifications to multiple events
    func applyModifications(modificationDetails: ModificationDetails) async throws {
        // Get date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        // Get calendar
        let calendar = Calendar.current
        
        // Determine the time range for the modifications
        var startDate: Date
        var endDate: Date
        
        if let timeRangeStart = modificationDetails.timeRangeStart,
           let timeRangeEnd = modificationDetails.timeRangeEnd,
           let start = dateFormatter.date(from: timeRangeStart),
           let end = dateFormatter.date(from: timeRangeEnd) {
            // Use the specified time range
            startDate = calendar.startOfDay(for: start)
            // Add 1 day to end date to include the entire day
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        } else {
            // Default to today if no time range is specified
            startDate = calendar.startOfDay(for: Date())
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }
        
        // Create the predicate for events in the time range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Fetch events in the time range
        var eventsInRange = eventStore.events(matching: predicate)
        
        // Filter out all-day events
        eventsInRange = eventsInRange.filter { !$0.isAllDay }
        
        // Filter out events from specific calendars (like Todoist)
        eventsInRange = eventsInRange.filter { event in
            // Skip events from Todoist calendar
            if event.calendar.title.contains("Todoist") {
                return false
            }
            return true
        }
        
        // Apply modifications based on the modification type
        switch modificationDetails.modificationType {
        case .swap:
            try await applySwapModifications(modificationDetails, eventsInRange, dateFormatter, timeFormatter)
            
        case .clear:
            try await applyClearModifications(modificationDetails, eventsInRange)
            
        case .copy:
            try await applyCopyModifications(modificationDetails, eventsInRange, dateFormatter, timeFormatter)
            
        case .other:
            try await applyCustomModifications(modificationDetails, eventsInRange, dateFormatter, timeFormatter)
        }
        
        // Refresh the events list
        await MainActor.run {
            self.loadTodaysEvents()
        }
    }
    
    
    // Helper method to apply swap modifications
    private func applySwapModifications(_ details: ModificationDetails, _ eventsInRange: [EKEvent], _ dateFormatter: DateFormatter, _ timeFormatter: DateFormatter) async throws {
        // Expecting the event_modifications array to contain exactly two modifications with non-nil event titles.
            guard details.eventModifications.count == 2,
                  let name1 = details.eventModifications[0].eventTitle,
                  let name2 = details.eventModifications[1].eventTitle else {
                print("SWAP DEBUG: Please specify exactly two event titles for swapping.")
                return
            }
            
            // Filter events for today
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            let todayEvents = eventsInRange.filter { event in
                let eventDay = calendar.startOfDay(for: event.startDate)
                return eventDay >= today && eventDay < tomorrow
            }
            
            guard let event1 = findEventByName(name1, in: todayEvents),
                  let event2 = findEventByName(name2, in: todayEvents) else {
                print("SWAP DEBUG: Could not find both events by the provided names.")
                return
            }
            
//            print("SWAP DEBUG: Found events '\(event1.title)' and '\(event2.title)'. Proceeding with time swap.")
            
            // Swap times (keeping all other properties unchanged)
            let tempStartDate = event1.startDate
            let tempEndDate = event1.endDate
            
            event1.startDate = event2.startDate
            event1.endDate = event2.endDate
            
            event2.startDate = tempStartDate
            event2.endDate = tempEndDate
            
            // Save changes
            try eventStore.save(event1, span: .thisEvent)
            try eventStore.save(event2, span: .thisEvent)
            
            print("SWAP DEBUG: Swap of times completed successfully.")
    }
    // Helper function to find an event by name (exact match, ignoring case and whitespace)
    private func findEventByName(_ name: String, in events: [EKEvent]) -> EKEvent? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return events.first { event in
            return event.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }
    }

    // Helper method to apply clear modifications
    private func applyClearModifications(_ details: ModificationDetails, _ eventsInRange: [EKEvent]) async throws {
        // Implementation for clearing events
        if details.eventModifications.isEmpty {
            // If no specific events are mentioned, clear all events in the range
            for event in eventsInRange {
                // Check if calendar allows modifications
                if event.calendar.allowsContentModifications {
                    do {
                        try eventStore.remove(event, span: .thisEvent)
                    } catch {
                        // Continue with other events if one fails
                        continue
                    }
                }
            }
        } else {
            // Clear only specific events
            for modification in details.eventModifications {
                let eventsToClear = findEventsForModification(modification, eventsInRange)
                
                for event in eventsToClear {
                    // Check if calendar allows modifications
                    if event.calendar.allowsContentModifications {
                        do {
                            try eventStore.remove(event, span: .thisEvent)
                        } catch {
                            // Continue with other events if one fails
                            continue
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to apply copy modifications
    private func applyCopyModifications(_ details: ModificationDetails, _ eventsInRange: [EKEvent], _ dateFormatter: DateFormatter, _ timeFormatter: DateFormatter) async throws {
        // Implementation for copying events
        let calendar = Calendar.current
        
        // Determine the target date for copying
        var targetDate: Date
        
        // If no specific modifications but we have a time range in the main details
        if details.eventModifications.isEmpty {
            // For "copy yesterday events" or similar, we want to copy to today by default
            // unless a specific target date is provided
            if details.timeRangeEnd != nil && details.timeRangeEnd != details.timeRangeStart {
                // If timeRangeEnd is different from timeRangeStart, use it as target
                guard let targetDateString = details.timeRangeEnd,
                      let parsedTargetDate = dateFormatter.date(from: targetDateString) else {
                    // If no valid target date, default to today
                    targetDate = calendar.startOfDay(for: Date())
                    
                    // Copy all events to today
                    try await copyEventsToDate(eventsInRange, targetDate, calendar, dateFormatter, timeFormatter)
                    return
                }
                
                targetDate = parsedTargetDate
            } else {
                // Default to today if no specific target is provided
                targetDate = calendar.startOfDay(for: Date())
            }
            
            // Copy all events to the target date
            try await copyEventsToDate(eventsInRange, targetDate, calendar, dateFormatter, timeFormatter)
            return
        }
        
        // Process specific modifications
        for modification in details.eventModifications {
            // Find the events to copy
            let eventsToCopy = findEventsForModification(modification, eventsInRange)
            
            // Get target date
            if let targetDateString = modification.targetDate,
               let parsedTargetDate = dateFormatter.date(from: targetDateString) {
                targetDate = parsedTargetDate
            } else {
                // Default to today if no specific target is provided
                targetDate = calendar.startOfDay(for: Date())
            }
            
            // Copy events with the specific target time if provided
            for event in eventsToCopy {
                // Create a new event as a copy
                let newEvent = EKEvent(eventStore: eventStore)
                newEvent.title = event.title
                newEvent.location = event.location
                newEvent.notes = event.notes
                
                // Try to use the source event's calendar if it allows modifications, otherwise use default
                if event.calendar.allowsContentModifications {
                    newEvent.calendar = event.calendar
                } else {
                    newEvent.calendar = eventStore.defaultCalendarForNewEvents
                }
                
                // Calculate the date difference
                let originalDate = calendar.startOfDay(for: event.startDate)
                let targetDay = calendar.startOfDay(for: targetDate)
                let daysDifference = calendar.dateComponents([.day], from: originalDate, to: targetDay).day ?? 0
                
                // Apply the date difference to start and end dates
                newEvent.startDate = calendar.date(byAdding: .day, value: daysDifference, to: event.startDate)!
                newEvent.endDate = calendar.date(byAdding: .day, value: daysDifference, to: event.endDate)!
                
                // If a specific target time is provided, adjust the time
                if let targetTimeString = modification.targetStartTime,
                   let targetTime = timeFormatter.date(from: targetTimeString) {
                    let targetHour = calendar.component(.hour, from: targetTime)
                    let targetMinute = calendar.component(.minute, from: targetTime)
                    
                    var startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: newEvent.startDate)
                    startComponents.hour = targetHour
                    startComponents.minute = targetMinute
                    
                    if let adjustedStartDate = calendar.date(from: startComponents) {
                        // Calculate the duration of the original event
                        let duration = event.endDate.timeIntervalSince(event.startDate)
                        
                        newEvent.startDate = adjustedStartDate
                        newEvent.endDate = adjustedStartDate.addingTimeInterval(duration)
                    }
                }
                
                // Save the new event
                do {
                    try eventStore.save(newEvent, span: .thisEvent)
                } catch {
                    // Continue with other events if one fails
                    continue
                }
            }
        }
    }
    
    // Helper method to copy events to a specific date
    private func copyEventsToDate(_ events: [EKEvent], _ targetDate: Date, _ calendar: Calendar, _ dateFormatter: DateFormatter, _ timeFormatter: DateFormatter) async throws {
        for event in events {
            // Create a new event as a copy
            let newEvent = EKEvent(eventStore: eventStore)
            newEvent.title = event.title
            newEvent.location = event.location
            newEvent.notes = event.notes
            
            // Try to use the source event's calendar if it allows modifications, otherwise use default
            if event.calendar.allowsContentModifications {
                newEvent.calendar = event.calendar
            } else {
                newEvent.calendar = eventStore.defaultCalendarForNewEvents
            }
            
            // Calculate the date difference
            let originalDate = calendar.startOfDay(for: event.startDate)
            let targetDay = calendar.startOfDay(for: targetDate)
            let daysDifference = calendar.dateComponents([.day], from: originalDate, to: targetDay).day ?? 0
            
            // Apply the date difference to start and end dates
            newEvent.startDate = calendar.date(byAdding: .day, value: daysDifference, to: event.startDate)!
            newEvent.endDate = calendar.date(byAdding: .day, value: daysDifference, to: event.endDate)!
            
            // Save the new event
            do {
                try eventStore.save(newEvent, span: .thisEvent)
            } catch {
                // Continue with other events if one fails
                continue
            }
        }
    }
    
    // Helper method to apply custom modifications
    private func applyCustomModifications(_ details: ModificationDetails, _ eventsInRange: [EKEvent], _ dateFormatter: DateFormatter, _ timeFormatter: DateFormatter) async throws {
        // Implementation for custom modifications
        for modification in details.eventModifications {
            // Find the events to modify
            let eventsToModify = findEventsForModification(modification, eventsInRange)
            
            for event in eventsToModify {
                // Check if calendar allows modifications
                if !event.calendar.allowsContentModifications {
                    continue
                }
                
                // Apply title change if specified
                if let newTitle = modification.newTitle {
                    event.title = newTitle
                }
                
                // Apply location change if specified
                if let newLocation = modification.newLocation {
                    event.location = newLocation
                }
                
                // Apply time changes if specified
                if let newStartTimeString = modification.newStartTime,
                   let newStartTime = timeFormatter.date(from: newStartTimeString) {
                    let calendar = Calendar.current
                    let newHour = calendar.component(.hour, from: newStartTime)
                    let newMinute = calendar.component(.minute, from: newStartTime)
                    
                    var startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.startDate)
                    startComponents.hour = newHour
                    startComponents.minute = newMinute
                    
                    if let adjustedStartDate = calendar.date(from: startComponents) {
                        // Calculate the original duration
                        let duration = event.endDate.timeIntervalSince(event.startDate)
                        
                        // Update start date and calculate new end date based on original duration
                        event.startDate = adjustedStartDate
                        
                        // If end time is also specified, use it; otherwise, maintain the original duration
                        if let newEndTimeString = modification.newEndTime,
                           let newEndTime = timeFormatter.date(from: newEndTimeString) {
                            let newEndHour = calendar.component(.hour, from: newEndTime)
                            let newEndMinute = calendar.component(.minute, from: newEndTime)
                            
                            var endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.startDate)
                            endComponents.hour = newEndHour
                            endComponents.minute = newEndMinute
                            
                            if let adjustedEndDate = calendar.date(from: endComponents) {
                                event.endDate = adjustedEndDate
                            }
                        } else {
                            event.endDate = adjustedStartDate.addingTimeInterval(duration)
                        }
                    }
                }
                
                // Save the modified event
                do {
                    try eventStore.save(event, span: .thisEvent)
                } catch {
                    // Continue with other events if one fails
                    continue
                }
            }
        }
    }
    
    private func findEventsForModification(_ modification: EventModification, _ eventsInRange: [EKEvent]) -> [EKEvent] {
        // If no specific criteria are provided, return all events in range
        if modification.eventTitle == nil && modification.originalDate == nil && modification.originalStartTime == nil {
            return eventsInRange
        }
        
        var matchingEvents: [EKEvent] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        // Set to UTC so that API strings and event dates align
        dateFormatter.timeZone = TimeZone.current
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        // Set to UTC for consistent time parsing
        timeFormatter.timeZone = TimeZone.current
        
        for event in eventsInRange {
            var isMatch = true
            
            // Match by title if specified
            if let eventTitle = modification.eventTitle, !eventTitle.isEmpty {
                let titleMatch = event.title.lowercased().contains(eventTitle.lowercased())
                isMatch = isMatch && titleMatch
            }
            
            // Match by date if specified
            if let originalDateString = modification.originalDate {
                if let originalDate = dateFormatter.date(from: originalDateString) {
                    let calendar = Calendar.current
                    // Convert event startDate to UTC for comparison
                    var utcCalendar = Calendar.current
                    utcCalendar.timeZone = TimeZone(abbreviation: "UTC")!
                    let eventDay = utcCalendar.startOfDay(for: event.startDate)
                    let originalDay = utcCalendar.startOfDay(for: originalDate)
                    let dateMatch = calendar.isDate(eventDay, inSameDayAs: originalDay)
                    isMatch = isMatch && dateMatch
                } else {
                    isMatch = false
                }
            }
            
            // Match by start time if specified and not default
            if let originalStartTimeString = modification.originalStartTime, !originalStartTimeString.isEmpty, originalStartTimeString != "09:00" {
                if let originalStartTime = timeFormatter.date(from: originalStartTimeString) {
                    let calendar = Calendar.current
                    let eventHour = calendar.component(.hour, from: event.startDate)
                    let eventMinute = calendar.component(.minute, from: event.startDate)
                    let originalHour = calendar.component(.hour, from: originalStartTime)
                    let originalMinute = calendar.component(.minute, from: originalStartTime)
                    
                    let timeMatch = (eventHour == originalHour && eventMinute == originalMinute)
                    isMatch = isMatch && timeMatch
                } else {
                    isMatch = false
                }
            }
            
            if isMatch {
                matchingEvents.append(event)
            }
        }
        
        return matchingEvents
    }
}
