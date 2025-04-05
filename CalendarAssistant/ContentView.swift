//
//  ContentView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25.
//  Updated with multi-event modification capabilities
//

import UIKit
import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var calendarManager = CalendarManager()
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var eventDetails: EventDetails?
    @State private var showingConfirmation = false
    @State private var selectedEvent: EKEvent?
    @State private var showingEventEdit = false
    @State private var errorMessage: String?
    @State private var isRefreshing = false
    
    // New state variables for modification mode
    @State private var isModificationMode = false
    @State private var modificationDetails: ModificationDetails?
    
    // Reference to your OpenAI service
    private let openAIService = OpenAIService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Enhanced input field
                    VStack {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                                .padding(.leading, 8)
                            
                            TextField("Add event or modify events (e.g., Meeting with John tomorrow at 2pm)", text: $inputText)
                                .padding(10)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .disabled(isProcessing)
                                .submitLabel(.send)
                                .onSubmit {
                                    if !inputText.isEmpty {
                                        processInput()
                                    }
                                }
                            
                            if !inputText.isEmpty {
                                Button(action: {
                                    processInput()
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                                .disabled(isProcessing)
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Processing...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Date header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(formattedDate())
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Today")
                                .font(.system(size: 24, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Manually trigger refresh
                            Task {
                                await refreshCalendar()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    
                    // Enhanced calendar events list with pull-to-refresh
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedEvents.keys.sorted(), id: \.self) { hour in
                                VStack(alignment: .leading, spacing: 0) {
                                    // Hour marker
                                    HStack(alignment: .top) {
                                        Text(formatHour(hour))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 8)
                                    
                                    // Events for this hour
                                    ForEach(groupedEvents[hour] ?? [], id: \.calendarItemIdentifier) { event in
                                        EventRow(event: event)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                
                                                selectedEvent = event
                                                showingEventEdit = true
                                            }
                                    }
                                }
                            }
                            
                            if calendarManager.todaysEvents.isEmpty {
                                VStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.bottom, 16)
                                    
                                    Text("No events for today")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Pull down to refresh or add a new event")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await refreshCalendar()
                    }
                }
            }
            .onAppear {
                calendarManager.requestAccess()
            }
            .navigationTitle("ICGPT")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingConfirmation) {
                if isModificationMode, let details = modificationDetails {
                    ModificationConfirmationView(modificationDetails: details, onConfirm: applyModifications)
                } else if let details = eventDetails {
                    EventConfirmationView(eventDetails: details, onConfirm: createEvent)
                }
            }
            .sheet(isPresented: $showingEventEdit) {
                if let event = selectedEvent {
                    EventEditView(event: event, calendarManager: calendarManager)
                        .environmentObject(calendarManager)
                }
            }
            .onChange(of: isRefreshing) { oldValue, newValue in
                if newValue {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
        }
    }
    
    // Group events by hour for timeline display
    private var groupedEvents: [Int: [EKEvent]] {
        var result: [Int: [EKEvent]] = [:]
        
        for event in calendarManager.todaysEvents {
            let hour = Calendar.current.component(.hour, from: event.startDate)
            if result[hour] == nil {
                result[hour] = []
            }
            result[hour]?.append(event)
        }
        
        return result
    }
    
    // Format hour for timeline
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(hour)"
    }
    
    // Format today's date
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    // Function to refresh calendar data with visual feedback
    private func refreshCalendar() async {
        withAnimation {
            isRefreshing = true
        }
        
        // Add slight delay to make refresh animation visible
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        await MainActor.run {
            calendarManager.loadTodaysEvents()
            print("Loaded \(calendarManager.todaysEvents.count) events")
            
            withAnimation {
                isRefreshing = false
            }
        }
    }

    // Updated process input method to handle both single events and modifications
    private func processInput() {
        guard !inputText.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Use the new combined method to classify and parse input
                let result = try await openAIService.classifyAndParseInput(from: inputText)
                
                await MainActor.run {
                    switch result {
                    case .singleEvent(let details):
                        // Handle single event creation
                        self.eventDetails = details
                        self.isModificationMode = false
                        self.modificationDetails = nil
                        self.showingConfirmation = true
                        
                    case .modification(let details):
                        // Handle multi-event modification
                        self.modificationDetails = details
                        self.isModificationMode = true
                        self.eventDetails = nil
                        self.showingConfirmation = true
                    }
                    
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Existing method for creating a single event
    private func createEvent(details: EventDetails) {
        Task {
            do {
                try await calendarManager.createEventFromDetails(details)
                await MainActor.run {
                    self.inputText = ""
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create event: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // New method for applying modifications to multiple events
    private func applyModifications(details: ModificationDetails) {
        Task {
            do {
                try await calendarManager.applyModifications(modificationDetails: details)
                await MainActor.run {
                    self.inputText = ""
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to apply modifications: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Event row component for the list (unchanged)
struct EventRow: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator column with color accent
            VStack(spacing: 4) {
                Text(formatTime(event.startDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(formatTime(event.endDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical color bar based on event type/calendar
            Rectangle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 4)
                .cornerRadius(2)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Preview provider
#Preview {
    ContentView()
}
