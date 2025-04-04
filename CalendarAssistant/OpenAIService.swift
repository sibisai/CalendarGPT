//
//  OpenAIService.swift
//  CalendarAssistant
//
//  Created by Sibi on 4/4/25 for OpenAI integration.
//
//

import Foundation

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init() {
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
    
    func parseEventDetails(from text: String) async throws -> EventDetails {
        // Get current date and time information
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let formattedDate = dateFormatter.string(from: now)
        
        // Format dates for API
        let todayISO = formatDateToISO(now)
        let tomorrowISO = formatDateToISO(Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        
        // Current time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let currentTime = timeFormatter.string(from: now)
        
        // Create the request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey) ", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    Extract calendar event details from the following text.
                    Today's date is \(formattedDate) (\(todayISO)).
                    Tomorrow's date is \(tomorrowISO).
                    The current time is \(currentTime).
                    
                    Return a JSON object with the following fields:
                    - title: The title or name of the event
                    - date: The date in YYYY-MM-DD format
                    - start_time: Start time in HH:MM format (24-hour)
                    - end_time: End time in HH:MM format (24-hour), can be null
                    - location: Location of the event, can be null
                    - attendees: Array of attendees, can be empty array
                    
                    If the text mentions "today", use \(todayISO).
                    If the text mentions "tomorrow", use \(tomorrowISO).
                    If no date is specified, assume today (\(todayISO)).
                    If no time is specified, assume a default time of 09:00.
                    
                    Return ONLY the JSON object, no other text.
                    """
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 150
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
        return try JSONDecoder().decode(EventDetails.self, from: jsonData)
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

// Event details model
struct EventDetails: Codable {
    var title: String
    var date: String
    var start_time: String
    var end_time: String?
    var location: String?
    var attendees: [String]?
}

