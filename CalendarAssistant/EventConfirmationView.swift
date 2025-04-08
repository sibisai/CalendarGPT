//
//  EventConfirmationView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//  Updated to fix Auto Layout constraint issues and add feedback
//

import UIKit
import SwiftUI

struct EventConfirmationView: View {
    let eventDetails: EventDetails
    let onConfirm: (EventDetails) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var isKeyboardVisible = false
    @State private var isConfirming = false // For animation
    @State private var isCancelling = false // For animation
    
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
                        // Trigger haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Trigger animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isConfirming = true
                        }
                        
                        // Reset animation after delay and perform action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation {
                                isConfirming = false
                            }
                            onConfirm(eventDetails)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .scaleEffect(isConfirming ? 0.95 : 1.0) // Scale animation
                }
                
                Section {
                    Button("Cancel") {
                        // Trigger haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Trigger animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isCancelling = true
                        }
                        
                        // Reset animation after delay and perform action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation {
                                isCancelling = false
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                    .scaleEffect(isCancelling ? 0.95 : 1.0) // Scale animation
                }
            }
            .navigationTitle("Confirm Event")
            // Add padding at the bottom to avoid keyboard overlap
            .padding(.bottom, isKeyboardVisible ? 100 : 0)
            // Listen for keyboard notifications
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    isKeyboardVisible = true
                }
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    isKeyboardVisible = false
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
        // Use inline presentation style to avoid constraint conflicts
        .navigationViewStyle(StackNavigationViewStyle())
        // Disable the swipe-to-dismiss gesture to prevent constraint issues
        .interactiveDismissDisabled()
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
