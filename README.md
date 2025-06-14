# Finnish Weather Application 🌤️

A beautiful weather application for macOS that displays current weather and forecasts in Finnish language. Available in both command-line and graphical user interface versions.

![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features ✨

### Both Versions
- 🌡️ Current weather conditions with temperature, humidity, and wind speed
- 📅 3-hour forecast for the next few hours
- 🌅 Tomorrow's morning and afternoon weather predictions
- 🇫🇮 Complete Finnish language interface
- 🔄 Real-time weather data from OpenWeatherMap API

### GUI Version Additional Features
- 🖥️ Native macOS SwiftUI interface
- ⏱️ Automatic weather updates (configurable interval)
- 🔄 Manual refresh button
- ⏸️ Pause/resume automatic updates
- 🕐 Last update timestamp display
- 📊 Clean, organized table layout for forecasts

## Screenshots 📸

### Command Line Version
```
Nykyinen sää: Lappeenranta, Finland
┌─────────────────────────────────────────────┐
│ Lämpötila:   16.0°C (tuntuu 15.3°C)
│ Säätila:     Kirkas taivas
│ Kosteus:     63%
│ Tuulen nopeus: 3.1 m/s
└─────────────────────────────────────────────┘

Seuraavien 3 tunnin ennuste:
┌──────────┬──────────┬─────────────────────┬──────────┬──────────┐
│   Aika   │ Lämpöt.  │      Säätila        │ Kosteus  │  Tuuli   │
├──────────┼──────────┼─────────────────────┼──────────┼──────────┤
│ 21:00    │ 16.0     │ Kirkas taivas       │ 63       │ 3.4 m/s  │
│ 00:00    │ 14.7     │ Hajanaisia pilviä   │ 68       │ 3.4 m/s  │
└──────────┴──────────┴─────────────────────┴──────────┴──────────┘
```

### GUI Version
The GUI version displays the same information in a modern macOS window with buttons for manual refresh, pause/resume updates, and close.

## Prerequisites 📋

- macOS 11.0 or later
- Swift 5.0 or later (comes with Xcode)
- An OpenWeatherMap API key (free tier available)

## Installation 🚀

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/finnish-weather-app.git
   cd finnish-weather-app
   ```

2. **Get an OpenWeatherMap API key:**
   - Visit [OpenWeatherMap](https://openweathermap.org/api)
   - Sign up for a free account
   - Generate an API key

3. **Configure the application:**
   ```bash
   cp config.example.json config.json
   ```
   
   Edit `config.json` and add your API key:
   ```json
   {
     "openWeatherMapApiKey": "YOUR_API_KEY_HERE",
     "city": "Lappeenranta",
     "country": "Finland",
     "updateIntervalSeconds": 60
   }
   ```

4. **Make the scripts executable:**
   ```bash
   chmod +x WeatherForecast.swift
   chmod +x WeatherForecastGUI.swift
   ```

## Usage 🎯

### Command Line Version
```bash
./WeatherForecast.swift
```

### GUI Version
```bash
./WeatherForecastGUI.swift
```

Or you can run them directly with Swift:
```bash
swift WeatherForecast.swift
swift WeatherForecastGUI.swift
```

## Configuration ⚙️

The `config.json` file supports the following options:

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `openWeatherMapApiKey` | Your OpenWeatherMap API key | Yes | - |
| `city` | City name for weather data | Yes | - |
| `country` | Country name for weather data | Yes | - |
| `updateIntervalSeconds` | Auto-update interval (GUI only) | No | 60 |

## Weather Translations 🌍

The application automatically translates common weather conditions to Finnish:

- Clear sky → Kirkas taivas
- Few clouds → Muutamia pilviä
- Scattered clouds → Hajanaisia pilviä
- Rain → Sadetta
- Snow → Lumisadetta
- And many more...

## Project Structure 📁

```
.
├── WeatherForecast.swift      # Command-line version
├── WeatherForecastGUI.swift   # GUI version
├── config.example.json        # Example configuration
├── config.json               # Your configuration (git-ignored)
├── README.md                 # This file
├── LICENSE                   # MIT License
└── .gitignore               # Git ignore rules
```

## Development 🛠️

### Adding New Weather Translations

Edit the `translateWeatherDescription` function in either version:

```swift
let translations: [String: String] = [
    "clear sky": "Kirkas taivas",
    "your weather": "sinun sää",
    // Add more translations here
]
```

### Changing Update Interval

Modify the `updateIntervalSeconds` in your `config.json` file. The value is in seconds.

### Customizing the Location

Update the `city` and `country` fields in your `config.json` file to get weather for a different location.

## Error Handling 🚨

The application includes comprehensive error handling:

- Missing configuration file detection
- Invalid API key handling
- Network error recovery
- JSON parsing error messages

All error messages are displayed in Finnish for consistency.

## Contributing 🤝

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- Weather data provided by [OpenWeatherMap](https://openweathermap.org/)
- Built with Swift and SwiftUI
- Finnish translations by native speakers

## Support 💬

If you encounter any issues or have questions:

1. Check the error messages (they're in Finnish but descriptive)
2. Ensure your API key is valid and active
3. Verify your internet connection
4. Open an issue on GitHub

---

Made with ❤️ in Finland 🇫🇮