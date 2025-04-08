//
//  NaturalLanguageInputView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//  Updated with UI improvements and haptic/animation feedback
//

import SwiftUI

struct NaturalLanguageInputView: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var eventDetails: EventDetails?
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    @State private var isSubmitting = false // For animation

    private let openAIService = OpenAIService()
    
    // Reference to your calendar manager
    @EnvironmentObject var calendarManager: CalendarManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            
            // Input area at the bottom
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    Button(action: {
                        // Add any additional action here if needed
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .padding(.leading, 8)
                    
                    TextField("e.g., Meeting with John tomorrow at 2pm", text: $inputText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .submitLabel(.return)
                        .onSubmit {
                            if !inputText.isEmpty {
                                processInput()
                            }
                        }
                        .scaleEffect(isSubmitting ? 0.95 : 1.0) // Scale animation
                    
                    Button(action: {
                        processInput()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isProcessing)
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            if let details = eventDetails {
                EventConfirmationView(eventDetails: details, onConfirm: createEvent)
            }
        }
    }
    
    private func processInput() {
        guard !inputText.isEmpty else { return }
        
        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Trigger animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isSubmitting = true
        }
        
        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isSubmitting = false
            }
        }
        
        isProcessing = true
        errorMessage = nil
        isInputFocused = false // Dismiss keyboard
        
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
                    
                    // Error haptic feedback
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
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
                
                // Success haptic feedback
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                
                DispatchQueue.main.async {
                    self.inputText = ""
                    // Optionally show success message
                }
            } catch {
                // Error haptic feedback
                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)
                
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
