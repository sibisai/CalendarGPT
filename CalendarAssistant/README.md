# Calendar Assistant

A natural language calendar management app for iOS that allows you to create, edit, and manage calendar events using plain English.

## Features

- Create calendar events using natural language input
- View, edit, and delete existing calendar events
- Filter out all-day events for a cleaner view
- Color-code events based on calendar categories
- Secure handling of API keys and sensitive data

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.0+
- OpenAI API key for natural language processing

## Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/calendar-assistant.git
   cd calendar-assistant
   ```

2. Configure your API key
   - Copy `Secrets-Template.xcconfig` to `Secrets.xcconfig`
   - Replace the placeholder with your actual OpenAI API key
   - Ensure this file is not committed to git (it should be in .gitignore)

3. Open the project in Xcode
   ```bash
   open CalendarAssistant.xcodeproj
   ```

4. Select the appropriate build configuration that uses your Secrets.xcconfig file

5. Build and run the application

## API Key Configuration

This project requires an OpenAI API key:

1. Copy `Secrets-Template.xcconfig` to `Secrets.xcconfig`
2. Replace the placeholder with your actual OpenAI API key:
   ```
   OPENAI_API_KEY = your-api-key-here
   ```
3. In Xcode, ensure your target is using the build configuration that references this file
4. Never commit your `Secrets.xcconfig` file to git (it should be in .gitignore)

## Security

This application uses several security measures to protect sensitive information:

1. API keys are stored in xcconfig files excluded from git
2. The app accesses API keys via Info.plist using the $(OPENAI_API_KEY) syntax
3. All calendar access is managed through Apple's EventKit framework
4. The app implements proper error handling for API failures

## Usage

1. Grant calendar access when prompted
2. Type natural language event descriptions in the input field
3. Review and confirm event details before creation
4. View your events in the timeline
5. Tap on events to edit or delete them
6. Change event calendars to organize with different colors

## Calendar Features

- View all your events in a clean timeline interface
- Filter out all-day events for a cleaner view
- Color-code events based on their calendar
- Change which calendar an event belongs to
- Create new calendars with custom colors

## Natural Language Processing

The app uses OpenAI's API to parse natural language input into structured event data:

- "Meeting with John tomorrow at 2pm"
- "Lunch with Sarah on Friday from 12-1pm"
- "Dentist appointment next Tuesday at 10am"
- "Weekly team standup every Monday at 9am"

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [OpenAI](https://openai.com/) for natural language processing
- [Apple EventKit](https://developer.apple.com/documentation/eventkit) for calendar integration
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) for the user interface
