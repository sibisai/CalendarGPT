//
//  CalendarManager.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25.
//
import Foundation
import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    private var eventStore = EKEventStore()
    @Published var todaysEvents: [EKEvent] = []
    @Published var hasCalendarAccess = false
    
    func requestAccess() {
        // Simple approach that worked before
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



    
    // Add this function to your CalendarManager class
    func createTestEvents() {
        guard hasCalendarAccess else {
            print("Cannot create test events: No calendar access")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Create a few test events at different times today
        let eventTitles = ["Morning Meeting", "Lunch with Team", "Afternoon Review", "Evening Workout"]
        let startHours = [9, 12, 15, 18]
        
        for (index, title) in eventTitles.enumerated() {
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            
            // Set start time (hours from start of day)
            var startComponents = DateComponents()
            startComponents.hour = startHours[index]
            startComponents.minute = 0
            let startDate = calendar.date(byAdding: startComponents, to: startOfDay)!
            event.startDate = startDate
            
            // Set end time (1 hour after start)
            event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
            
            // Add location for some events
            if index % 2 == 0 {
                event.location = "Office Room \(index + 1)"
            }
            
            // Set calendar (default to primary calendar)
            event.calendar = eventStore.defaultCalendarForNewEvents
            
            // Try to save the event
            do {
                try eventStore.save(event, span: .thisEvent)
                print("Created test event: \(title)")
            } catch {
                print("Failed to create test event: \(error.localizedDescription)")
            }
        }
        
        // Reload events after creating test data
        loadTodaysEvents()
    }

    
    func loadTodaysEvents() {
        guard hasCalendarAccess else {
            print("Cannot load events: No calendar access")
            return
        }
        
        let calendar = Calendar.current
        
        // Get start and end of today
        let startDate = calendar.startOfDay(for: Date())
        var components = DateComponents()
        components.day = 1
        let endDate = calendar.date(byAdding: components, to: startDate)!
        
        print("Fetching events from \(startDate) to \(endDate)")
        
        // Create the predicate for events
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        print("Found \(events.count) total events before filtering")
        
        // Always filter out all-day events
        let filteredEvents = events.filter { !$0.isAllDay }
        print("After filtering all-day events: \(filteredEvents.count) events")
        
        // Sort events by start date
        let sortedEvents = filteredEvents.sorted {
            $0.startDate < $1.startDate
        }
        
        for (index, event) in sortedEvents.enumerated() {
            let title = event.title ?? "Untitled"
            let startDate = event.startDate?.description ?? "Unknown start date"
            print("Event \(index + 1): \(title) at \(startDate)")
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
        print("Available calendars (\(calendars.count)):")
        for (index, calendar) in calendars.enumerated() {
            print("\(index + 1). \(calendar.title) (source: \(calendar.source.title))")
        }
    }
    
    func checkTimeZoneSettings() {
        print("Current time zone: \(TimeZone.current.identifier)")
        print("Calendar time zone: \(Calendar.current.timeZone.identifier)")
        print("Current date: \(Date())")
        print("Start of today: \(Calendar.current.startOfDay(for: Date()))")
    }
    
    // NEW: Update an existing event
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
    
    // NEW: Delete an event
    func deleteEvent(_ event: EKEvent) async throws {
        try eventStore.remove(event, span: .thisEvent)
        
        // Refresh the events list
        await MainActor.run {
            self.loadTodaysEvents()
        }
    }
    
    // NEW: Convert EKEvent to EventDetails for editing
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
}
