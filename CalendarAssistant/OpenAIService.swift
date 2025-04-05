//
//  OpenAIService.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//  Updated with multi-event modification capabilities and JSON parsing fixes
//

import Foundation

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init()  {
        // Initialize apiKey first, then call methods
        self.apiKey = OpenAIService.getAPIKey() ?? ""
    }
    
    static func getAPIKey() -> String? {
        guard let apiKey = Bundle.main.infoDictionary?["OpenAIAPIKey"] as? String else {
            print("API key not found in Info.plist")
            return nil
        }
        
        // Check if the key is the placeholder or empty
        if apiKey.isEmpty || apiKey == "$(OPENAI_API_KEY)" {
            print("$(OPENAI_API_KEY)")
            print("API key is not properly configured")
            return nil
        }
        
        return apiKey
    }
    
    // New method to classify and parse user input
    func classifyAndParseInput(from text: String) async throws -> InputParseResult {
        // Get current date and time information
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let formattedDate = dateFormatter.string(from: now)
        
        // Format dates for API
        let todayISO = formatDateToISO(now)
        let tomorrowISO = formatDateToISO(Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        let tenDaysLaterISO = formatDateToISO(Calendar.current.date(byAdding: .day, value: 10, to: now)!)
        
        // Current time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let currentTime = timeFormatter.string(from: now)
        
        // Create the request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)  ", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body with a system prompt that handles both classification and parsing
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a calendar assistant that processes natural language inputs to create or modify calendar events.
                    
                    Today's date is \(formattedDate) (\(todayISO)).
                    Tomorrow's date is \(tomorrowISO).
                    Ten days from now is \(tenDaysLaterISO).
                    The current time is \(currentTime).
                    
                    STEP 1: Classify the input as either:
                    - "single_event": A request to create a single new event
                    - "modification": A request to modify multiple events (e.g., swap, clear, copy)
                    
                    STEP 2: Based on the classification, extract the appropriate details:
                    
                    For "single_event", extract:
                    - title: The title or name of the event
                    - date: The date in YYYY-MM-DD format
                    - start_time: Start time in HH:MM format (24-hour)
                    - end_time: End time in HH:MM format (24-hour), can be null
                    - location: Location of the event, can be null
                    - attendees: Array of attendees, can be empty array
                    
                    For "modification", extract:
                    - modification_type: The type of modification ("swap", "clear", "copy", or "other")
                    - time_range_start: Start date of the time range in YYYY-MM-DD format
                    - time_range_end: End date of the time range in YYYY-MM-DD format
                    - event_modifications: Array of specific event modifications, each containing:
                      - event_title: Title of the event to modify (if applicable)
                      - original_date: Original date of the event in YYYY-MM-DD format (if applicable)
                      - original_start_time: Original start time in HH:MM format (if applicable)
                      - target_date: Target date for the event in YYYY-MM-DD format (if applicable)
                      - target_start_time: Target start time in HH:MM format (if applicable)
                      - new_title: New title for the event (if applicable)
                      - new_location: New location for the event (if applicable)
                      - new_start_time: New start time in HH:MM format (if applicable)
                      - new_end_time: New end time in HH:MM format (if applicable)
                    - description: A brief description of the modification
                    
                    If the text mentions "today", use \(todayISO).
                    If the text mentions "tomorrow", use \(tomorrowISO).
                    If no date is specified, assume today (\(todayISO)).
                    If no time is specified, assume a default time of 09:00.
                    
                    Return a JSON object with the following structure:
                    {
                      "input_type": "single_event" or "modification",
                      "details": {
                        // Either single event details or modification details based on input_type
                      }
                    }
                    
                    Return ONLY the JSON object, no other text.
                    """
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        // Convert the request body to JSON data
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Send the request
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse the response
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = response.choices[0].message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse the JSON content
        let jsonData = content.data(using: .utf8)!
        
        // First decode to get the input type
        let typeContainer = try JSONDecoder().decode(InputTypeContainer.self, from: jsonData)
        
        // Then decode the appropriate type based on the input type
        switch typeContainer.inputType {
        case "single_event":
            let fullResponse = try JSONDecoder().decode(SingleEventResponse.self, from: jsonData)
            return .singleEvent(fullResponse.details)
        case "modification":
            let fullResponse = try JSONDecoder().decode(ModificationResponse.self, from: jsonData)
            return .modification(fullResponse.details)
        default:
            throw NSError(domain: "OpenAIService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown input type"])
        }
    }
    
    // Keep the original method for backward compatibility
    func parseEventDetails(from text: String) async throws -> EventDetails {
        let result = try await classifyAndParseInput(from: text)
        
        switch result {
        case .singleEvent(let eventDetails):
            return eventDetails
        case .modification:
            throw NSError(domain: "OpenAIService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Input is a modification request, not a single event"])
        }
    }
    
    // New method to parse modification details
    func parseModificationDetails(from text: String) async throws -> ModificationDetails {
        let result = try await classifyAndParseInput(from: text)
        
        switch result {
        case .singleEvent:
            throw NSError(domain: "OpenAIService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Input is a single event request, not a modification"])
        case .modification(let modificationDetails):
            return modificationDetails
        }
    }
    
    private func formatDateToISO(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// Response models
struct OpenAIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let content: String
    }
}

// Type-safe containers for decoding JSON responses
struct InputTypeContainer: Decodable {
    let inputType: String
    
    enum CodingKeys: String, CodingKey {
        case inputType = "input_type"
    }
}

struct SingleEventResponse: Decodable {
    let inputType: String
    let details: EventDetails
    
    enum CodingKeys: String, CodingKey {
        case inputType = "input_type"
        case details
    }
}

struct ModificationResponse: Decodable {
    let inputType: String
    let details: ModificationDetails
    
    enum CodingKeys: String, CodingKey {
        case inputType = "input_type"
        case details
    }
}

// Enum to represent the result of parsing user input
enum InputParseResult {
    case singleEvent(EventDetails)
    case modification(ModificationDetails)
}

// Event details model (existing)
struct EventDetails: Codable {
    var title: String
    var date: String
    var start_time: String
    var end_time: String?
    var location: String?
    var attendees: [String]?
}
