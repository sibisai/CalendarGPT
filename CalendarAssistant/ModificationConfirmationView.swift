//
//  ModificationConfirmationView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for multi-event modification capabilities.
//

import UIKit
import SwiftUI

struct ModificationConfirmationView: View {
    let modificationDetails: ModificationDetails
    let onConfirm: (ModificationDetails) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modification Details")) {
                    Text("Type: \(formatModificationType(modificationDetails.modificationType))")
                        .fontWeight(.medium)
                    
                    if let timeRangeStart = modificationDetails.timeRangeStart,
                       let timeRangeEnd = modificationDetails.timeRangeEnd {
                        Text("Time Range: \(formatDate(timeRangeStart)) to \(formatDate(timeRangeEnd))")
                    }
                    
                    Text("Description: \(modificationDetails.description)")
                        .padding(.vertical, 4)
                }
                
                Section(header: Text("Events to Modify")) {
                    if modificationDetails.eventModifications.isEmpty {
                        Text("All events in the specified time range")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(0..<modificationDetails.eventModifications.count, id: \.self) { index in
                            let modification = modificationDetails.eventModifications[index]
                            VStack(alignment: .leading, spacing: 4) {
                                if let title = modification.eventTitle {
                                    Text(title)
                                        .fontWeight(.medium)
                                }
                                
                                if let originalDate = modification.originalDate {
                                    Text("Date: \(formatDate(originalDate))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let originalTime = modification.originalStartTime {
                                    Text("Time: \(formatTime(originalTime))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let newTitle = modification.newTitle {
                                    Text("New Title: \(newTitle)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                if let newLocation = modification.newLocation {
                                    Text("New Location: \(newLocation)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                if let newTime = modification.newStartTime {
                                    Text("New Time: \(formatTime(newTime))")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                
                                if let targetDate = modification.targetDate {
                                    Text("Target Date: \(formatDate(targetDate))")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button("Confirm and Apply Changes") {
                        onConfirm(modificationDetails)
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
            .navigationTitle("Confirm Modifications")
        }
    }
    
    // Format modification type to be more user-friendly
    private func formatModificationType(_ type: ModificationType) -> String {
        switch type {
        case .swap:
            return "Swap Events"
        case .clear:
            return "Clear Events"
        case .copy:
            return "Copy Events"
        case .other:
            return "Custom Modification"
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
    ModificationConfirmationView(
        modificationDetails: ModificationDetails(
            modificationType: .swap,
            timeRangeStart: "2025-04-05",
            timeRangeEnd: "2025-04-15",
            eventModifications: [
                EventModification(
                    eventTitle: "Team Meeting",
                    originalDate: "2025-04-05",
                    originalStartTime: "14:00",
                    targetDate: "2025-04-06",
                    targetStartTime: "15:00"
                )
            ],
            description: "Swap team meetings between days"
        ),
        onConfirm: { _ in }
    )
}

