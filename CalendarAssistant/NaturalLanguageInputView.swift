//
//  NaturalLanguageInputView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//
//

import SwiftUI

struct NaturalLanguageInputView: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var eventDetails: EventDetails?
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    private let openAIService = OpenAIService()
    
    // Reference to your calendar manager
    @EnvironmentObject var calendarManager: CalendarManager
    
    var body: some View {
        VStack {
            Text("Create Event Using Natural Language")
                .font(.headline)
                .padding()
            
            TextField("e.g., Meeting with John tomorrow at 2pm", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                processInput()
            }) {
                Text("Create Event")
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(inputText.isEmpty || isProcessing)
            .padding()
            
            if isProcessing {
                ProgressView("Processing...")
                    .padding()
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingConfirmation) {
            if let details = eventDetails {
                EventConfirmationView(eventDetails: details, onConfirm: createEvent)
            }
        }
    }
    
    private func processInput() {
        guard !inputText.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let details = try await openAIService.parseEventDetails(from: inputText)
                await MainActor.run {
                    self.eventDetails = details
                    self.isProcessing = false
                    self.showingConfirmation = true
                }
            } catch {
                await MainActor.run {
                    // Log detailed error for debugging
                    print("Error occurred during input processing:", error)
                    debugPrint(error)
                    
                    // Map error to a user-friendly message
                    self.errorMessage = userFriendlyErrorMessage(from: error)
                    self.isProcessing = false
                }
            }
        }
    }

    // Helper function to map error details to a user-friendly message
    private func userFriendlyErrorMessage(from error: Error) -> String {
        // Check for specific error types or use a default message
        if let nsError = error as NSError? {
            // For example, if you detect network issues
            if nsError.domain == NSURLErrorDomain {
                return "Network error. Please check your connection and try again."
            }
            // Add more error-specific mappings as needed
        }
        return "Sorry, we encountered an unexpected error. Please try again later."
    }
    
    private func createEvent(details: EventDetails) {
        // Convert EventDetails to EKEvent and save
        Task {
            do {
                try await calendarManager.createEventFromDetails(details)
                DispatchQueue.main.async {
                    self.inputText = ""
                    // Optionally show success message
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create event: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NaturalLanguageInputView()
        .environmentObject(CalendarManager())
}

