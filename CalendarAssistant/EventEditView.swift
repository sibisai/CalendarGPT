//
//  EventEditView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for event editing functionality.
//

import SwiftUI
import EventKit

struct EventEditView: View {
    let event: EKEvent
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var eventDetails: EventDetails
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false
    
    init(event: EKEvent, calendarManager: CalendarManager) {
        self.event = event
        self._eventDetails = State(initialValue: calendarManager.convertToEventDetails(event))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $eventDetails.title)
                    
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    
                    DatePicker("Start Time", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                    
                    DatePicker("End Time", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                    
                    TextField("Location", text: Binding(
                        get: { eventDetails.location ?? "" },
                        set: { eventDetails.location = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section {
                    Button(action: {
                        updateEvent()
                    }) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Event")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isProcessing)
                }
                
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Text("Delete Event")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                    }
                    .disabled(isProcessing)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteEvent()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // Computed bindings for date pickers
    private var dateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: eventDetails.date) ?? Date()
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                eventDetails.date = formatter.string(from: newDate)
            }
        )
    }
    
    private var startTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: eventDetails.start_time) ?? Date()
            },
            set: { newTime in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                eventDetails.start_time = formatter.string(from: newTime)
            }
        )
    }
    
    private var endTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return formatter.date(from: eventDetails.end_time ?? "00:00") ?? Date()
            },
            set: { newTime in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                eventDetails.end_time = formatter.string(from: newTime)
            }
        )
    }
    
    private func updateEvent() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                try await calendarManager.updateEvent(event, with: eventDetails)
                
                DispatchQueue.main.async {
                    isProcessing = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = "Failed to update event: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteEvent() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                try await calendarManager.deleteEvent(event)
                
                DispatchQueue.main.async {
                    isProcessing = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = "Failed to delete event: \(error.localizedDescription)"
                }
            }
        }
    }
}

