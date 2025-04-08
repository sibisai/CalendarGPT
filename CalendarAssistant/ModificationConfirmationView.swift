//
//  ModificationConfirmationView.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for multi-event modification capabilities.
//  Updated with haptic and animation feedback
//

import SwiftUI

struct ModificationConfirmationView: View {
    let modificationDetails: ModificationDetails
    let onConfirm: (ModificationDetails) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var isKeyboardVisible = false
    @State private var isConfirming = false // For animation
    @State private var isCancelling = false // For animation
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modification Details")) {
                    Text("Type: \(modificationDetails.modificationType.rawValue.capitalized)")
                    
                    if let start = modificationDetails.timeRangeStart {
                        Text("From: \(formatDate(start))")
                    }
                    
                    if let end = modificationDetails.timeRangeEnd {
                        Text("To: \(formatDate(end))")
                    }
                    
                    Text("Description: \(modificationDetails.description)")
                    
                    if !modificationDetails.eventModifications.isEmpty {
                        ForEach(0..<modificationDetails.eventModifications.count, id: \.self) { index in
                            let modification = modificationDetails.eventModifications[index]
                            VStack(alignment: .leading, spacing: 4) {
                                if let title = modification.eventTitle {
                                    Text("Event: \(title)")
                                        .font(.headline)
                                }
                                
                                if let originalDate = modification.originalDate {
                                    Text("Original Date: \(formatDate(originalDate))")
                                }
                                
                                if let targetDate = modification.targetDate {
                                    Text("Target Date: \(formatDate(targetDate))")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button("Confirm and Apply Changes") {
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
                            onConfirm(modificationDetails)
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
            .navigationTitle("Confirm Modification")
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
}
