//
//  EventConfirmationView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//
import UIKit
import SwiftUI

struct EventConfirmationView: View {
    let eventDetails: EventDetails
    let onConfirm: (EventDetails) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    Text("Title: \(eventDetails.title)")
                    Text("Date: \(formatDate(eventDetails.date))")
                    Text("Start Time: \(formatTime(eventDetails.start_time))")
                    
                    if let endTime = eventDetails.end_time {
                        Text("End Time: \(formatTime(endTime))")
                    }
                    
                    if let location = eventDetails.location {
                        Text("Location: \(location)")
                    }
                    
                    if let attendees = eventDetails.attendees, !attendees.isEmpty {
                        Text("Attendees: \(attendees.joined(separator: ", "))")
                    }
                }
                
                Section {
                    Button("Confirm and Create Event") {
                        onConfirm(eventDetails)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Confirm Event")
        }
    }
    
    // Format date from YYYY-MM-DD to a more readable format
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    // Format time from 24-hour (HH:MM) to AM/PM format
    private func formatTime(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm"
        
        if let time = inputFormatter.date(from: timeString) {
            let outputFormatter = DateFormatter()
            outputFormatter.timeStyle = .short // This will use the device's preferred format (usually AM/PM in US)
            return outputFormatter.string(from: time)
        }
        return timeString
    }
}

#Preview {
    EventConfirmationView(
        eventDetails: EventDetails(
            title: "Meeting with Team",
            date: "2025-04-05",
            start_time: "14:00",
            end_time: "15:00",
            location: "Conference Room A",
            attendees: ["John", "Sarah"]
        ),
        onConfirm: { _ in }
    )
}
