# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Finnish weather application for macOS that provides weather forecasts in Finnish language. The project includes two versions:
- **WeatherForecast.swift**: Command-line interface version with ASCII art temperature display
- **WeatherForecastGUI.swift**: Native macOS SwiftUI application with automatic updates

Both applications fetch weather data from OpenWeatherMap API and display current weather, hourly forecasts, and tomorrow's predictions.

## Commands

### Running the Applications
```bash
# Command-line version
./WeatherForecast.swift

# GUI version
./WeatherForecastGUI.swift

# Or run with Swift directly
swift WeatherForecast.swift
swift WeatherForecastGUI.swift
```

### Setup
```bash
# Copy and configure the API key
cp config.example.json config.json
# Edit config.json to add your OpenWeatherMap API key

# Make scripts executable
chmod +x WeatherForecast.swift
chmod +x WeatherForecastGUI.swift
```

## Architecture

### Configuration System
Both applications share a configuration approach:
- `Config` struct that reads from `config.json`
- Required fields: `openWeatherMapApiKey`, `city`, `country`
- Optional: `updateIntervalSeconds` (GUI only)

### Weather Data Flow
1. **API Integration**: Both apps use OpenWeatherMap API endpoints
   - Current weather: `/data/2.5/weather`
   - Forecast: `/data/2.5/forecast`
2. **Data Processing**: 
   - Weather descriptions are translated to Finnish via `translateWeatherDescription()`
   - Forecast data includes interpolation for accurate hourly predictions
   - Time-based forecasts (afternoon/evening) calculated dynamically

### Key Shared Components
- **Translation System**: Finnish translations for weather conditions
- **Time Formatting**: Consistent time display across both versions
- **Error Handling**: Finnish error messages for configuration and API issues

### CLI-Specific Features
- ASCII art 7-segment display for temperature (digital watch style)
- Box-drawing characters for formatted tables
- Synchronous execution model

### GUI-Specific Features
- SwiftUI-based interface with `@StateObject` for reactive updates
- Timer-based automatic refresh system with pause/resume capability
- Monospaced font for digital temperature display
- Background threading for API calls to maintain UI responsiveness

## Recent Enhancements

The codebase recently added:
- Interpolated hourly forecasts (+1h, +2h, +3h)
- Time period forecasts (Iltapäivä/afternoon, Ilta/evening)
- Digital watch-style temperature displays in both versions
- Increased GUI window height (750px) to accommodate larger temperature display