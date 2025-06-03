#!/usr/bin/swift

import SwiftUI
import Foundation

// Constants
let CITY = "Lappeenranta"
let COUNTRY = "Finland"
let API_KEY = "a571e40b56a00bdd00715a6219f2f2dd" // OpenWeatherMap API key

// Weather data models
struct CurrentWeather {
    let temperature: Double
    let feelsLike: Double
    let description: String
    let humidity: Int
    let windSpeed: Double
}

struct ForecastItem {
    let time: String
    let temperature: Double
    let description: String
    let humidity: Int
    let windSpeed: Double
}

struct TomorrowForecast {
    let morning: ForecastItem?
    let afternoon: ForecastItem?
}

// Weather data container
class WeatherData: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [ForecastItem] = []
    @Published var tomorrowForecast: TomorrowForecast?
    @Published var isLoading = true
    @Published var errorMessage: String?
}

// API URL for current weather
func getCurrentWeatherURL() -> URL? {
    let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    let urlString = "\(baseURL)?q=\(CITY),\(COUNTRY)&units=metric&appid=\(API_KEY)"
    return URL(string: urlString)
}

// API URL for forecast
func getForecastURL() -> URL? {
    let baseURL = "https://api.openweathermap.org/data/2.5/forecast"
    let urlString = "\(baseURL)?q=\(CITY),\(COUNTRY)&units=metric&appid=\(API_KEY)"
    return URL(string: urlString)
}

// Translate weather descriptions from English to Finnish
func translateWeatherDescription(_ description: String) -> String {
    let translations: [String: String] = [
        "clear sky": "Kirkas taivas",
        "few clouds": "Muutamia pilviä",
        "scattered clouds": "Hajanaisia pilviä",
        "broken clouds": "Melko pilvistä",
        "overcast clouds": "Täysin pilvessä",
        "shower rain": "Sadekuuroja",
        "rain": "Sadetta",
        "light rain": "Kevyttä sadetta",
        "moderate rain": "Kohtalaista sadetta",
        "heavy intensity rain": "Kovaa sadetta",
        "thunderstorm": "Ukkosmyrsky",
        "snow": "Lumisadetta",
        "light snow": "Kevyttä lumisadetta",
        "mist": "Sumua",
        "fog": "Sumua",
        "haze": "Usvaa"
    ]
    
    let lowercaseDesc = description.lowercased()
    return translations[lowercaseDesc] ?? description.capitalized
}

// Convert timestamp to formatted string
func formatTime(from timestamp: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"
    dateFormatter.timeZone = TimeZone.current
    return dateFormatter.string(from: date)
}

// Check if time is morning (6-12) or afternoon (12-18)
func getTimeOfDay(from timestamp: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    
    if hour >= 6 && hour < 12 {
        return "Aamu"
    } else if hour >= 12 && hour < 18 {
        return "Iltapäivä"
    } else {
        return "Muu"
    }
}

// Fetch weather data from API
func fetchData(from url: URL) -> [String: Any]? {
    let semaphore = DispatchSemaphore(value: 0)
    var result: [String: Any]?
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("Virhe haettaessa tietoja: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let data = data else {
            print("Virhe: Virheellinen vastaus")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                result = json
            }
        } catch {
            print("Virhe jäsennettäessä JSON-tietoja: \(error.localizedDescription)")
        }
    }
    
    task.resume()
    semaphore.wait()
    
    return result
}

// Parse current weather
func parseCurrentWeather(_ weather: [String: Any]) -> CurrentWeather? {
    guard let main = weather["main"] as? [String: Any],
          let temp = main["temp"] as? Double,
          let feelsLike = main["feels_like"] as? Double,
          let humidity = main["humidity"] as? Int,
          let weatherArray = weather["weather"] as? [[String: Any]],
          let firstWeather = weatherArray.first,
          let description = firstWeather["description"] as? String,
          let wind = weather["wind"] as? [String: Any],
          let windSpeed = wind["speed"] as? Double else {
        return nil
    }
    
    return CurrentWeather(
        temperature: temp,
        feelsLike: feelsLike,
        description: translateWeatherDescription(description),
        humidity: humidity,
        windSpeed: windSpeed
    )
}

// Parse hourly forecast
func parseHourlyForecast(_ forecastData: [String: Any]) -> [ForecastItem] {
    guard let list = forecastData["list"] as? [[String: Any]] else {
        return []
    }
    
    let now = Date()
    let threeHoursLater = now.addingTimeInterval(3 * 3600)
    var forecasts: [ForecastItem] = []
    
    for item in list.prefix(4) { // Get next 3-4 entries (3 hour intervals)
        guard let dt = item["dt"] as? TimeInterval,
              let main = item["main"] as? [String: Any],
              let temp = main["temp"] as? Double,
              let humidity = main["humidity"] as? Int,
              let weather = item["weather"] as? [[String: Any]],
              let firstWeather = weather.first,
              let description = firstWeather["description"] as? String,
              let wind = item["wind"] as? [String: Any],
              let windSpeed = wind["speed"] as? Double else { continue }
        
        let itemDate = Date(timeIntervalSince1970: dt)
        if itemDate > threeHoursLater { break }
        
        forecasts.append(ForecastItem(
            time: formatTime(from: dt),
            temperature: temp,
            description: translateWeatherDescription(description),
            humidity: humidity,
            windSpeed: windSpeed
        ))
    }
    
    return forecasts
}

// Parse tomorrow's forecast
func parseTomorrowForecast(_ forecastData: [String: Any]) -> TomorrowForecast {
    guard let list = forecastData["list"] as? [[String: Any]] else {
        return TomorrowForecast(morning: nil, afternoon: nil)
    }
    
    let calendar = Calendar.current
    var morningForecast: ForecastItem?
    var afternoonForecast: ForecastItem?
    
    for item in list {
        guard let dt = item["dt"] as? TimeInterval else { continue }
        let itemDate = Date(timeIntervalSince1970: dt)
        
        if calendar.isDateInTomorrow(itemDate) {
            let timeOfDay = getTimeOfDay(from: dt)
            
            guard let main = item["main"] as? [String: Any],
                  let temp = main["temp"] as? Double,
                  let humidity = main["humidity"] as? Int,
                  let weather = item["weather"] as? [[String: Any]],
                  let firstWeather = weather.first,
                  let description = firstWeather["description"] as? String,
                  let wind = item["wind"] as? [String: Any],
                  let windSpeed = wind["speed"] as? Double else { continue }
            
            let forecastItem = ForecastItem(
                time: timeOfDay,
                temperature: temp,
                description: translateWeatherDescription(description),
                humidity: humidity,
                windSpeed: windSpeed
            )
            
            if timeOfDay == "Aamu" && morningForecast == nil {
                morningForecast = forecastItem
            } else if timeOfDay == "Iltapäivä" && afternoonForecast == nil {
                afternoonForecast = forecastItem
            }
            
            if morningForecast != nil && afternoonForecast != nil {
                break
            }
        }
    }
    
    return TomorrowForecast(morning: morningForecast, afternoon: afternoonForecast)
}

// Load all weather data
func loadWeatherData(_ weatherData: WeatherData) {
    DispatchQueue.global(qos: .background).async {
        // Fetch current weather
        guard let currentURL = getCurrentWeatherURL(),
              let currentWeatherData = fetchData(from: currentURL) else {
            DispatchQueue.main.async {
                weatherData.errorMessage = "Virhe: Nykyisen sään hakeminen epäonnistui"
                weatherData.isLoading = false
            }
            return
        }
        
        // Fetch forecast data
        guard let forecastURL = getForecastURL(),
              let forecastData = fetchData(from: forecastURL) else {
            DispatchQueue.main.async {
                weatherData.errorMessage = "Virhe: Ennustetietojen hakeminen epäonnistui"
                weatherData.isLoading = false
            }
            return
        }
        
        let current = parseCurrentWeather(currentWeatherData)
        let hourly = parseHourlyForecast(forecastData)
        let tomorrow = parseTomorrowForecast(forecastData)
        
        DispatchQueue.main.async {
            weatherData.currentWeather = current
            weatherData.hourlyForecast = hourly
            weatherData.tomorrowForecast = tomorrow
            weatherData.isLoading = false
        }
    }
}

// Main content view
struct ContentView: View {
    @StateObject private var weatherData = WeatherData()
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Sää: \(CITY), \(COUNTRY)")
                .font(.title)
                .fontWeight(.bold)
            
            if weatherData.isLoading {
                ProgressView("Ladataan säätietoja...")
                    .padding()
            } else if let error = weatherData.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current weather
                        if let current = weatherData.currentWeather {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Nykyinen sää")
                                    .font(.headline)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("Lämpötila:")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        Text(String(format: "%.1f°C (tuntuu %.1f°C)", current.temperature, current.feelsLike))
                                    }
                                    HStack {
                                        Text("Säätila:")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        Text(current.description)
                                    }
                                    HStack {
                                        Text("Kosteus:")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        Text("\(current.humidity)%")
                                    }
                                    HStack {
                                        Text("Tuulen nopeus:")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        Text(String(format: "%.1f m/s", current.windSpeed))
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Hourly forecast
                        if !weatherData.hourlyForecast.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Seuraavien 3 tunnin ennuste")
                                    .font(.headline)
                                
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text("Aika")
                                            .fontWeight(.medium)
                                            .frame(width: 50, alignment: .leading)
                                        Text("Lämpöt.")
                                            .fontWeight(.medium)
                                            .frame(width: 60, alignment: .leading)
                                        Text("Säätila")
                                            .fontWeight(.medium)
                                            .frame(width: 140, alignment: .leading)
                                        Text("Kosteus")
                                            .fontWeight(.medium)
                                            .frame(width: 60, alignment: .leading)
                                        Text("Tuuli")
                                            .fontWeight(.medium)
                                            .frame(width: 70, alignment: .leading)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.blue.opacity(0.1))
                                    
                                    // Data rows
                                    ForEach(weatherData.hourlyForecast, id: \.time) { forecast in
                                        HStack {
                                            Text(forecast.time)
                                                .frame(width: 50, alignment: .leading)
                                            Text(String(format: "%.1f°", forecast.temperature))
                                                .frame(width: 60, alignment: .leading)
                                            Text(forecast.description)
                                                .frame(width: 140, alignment: .leading)
                                            Text("\(forecast.humidity)%")
                                                .frame(width: 60, alignment: .leading)
                                            Text(String(format: "%.1f m/s", forecast.windSpeed))
                                                .frame(width: 70, alignment: .leading)
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 10)
                                    }
                                }
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Tomorrow's forecast
                        if let tomorrow = weatherData.tomorrowForecast,
                           (tomorrow.morning != nil || tomorrow.afternoon != nil) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Huomisen ennuste")
                                    .font(.headline)
                                
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text("Ajankohta")
                                            .fontWeight(.medium)
                                            .frame(width: 80, alignment: .leading)
                                        Text("Lämpöt.")
                                            .fontWeight(.medium)
                                            .frame(width: 60, alignment: .leading)
                                        Text("Säätila")
                                            .fontWeight(.medium)
                                            .frame(width: 140, alignment: .leading)
                                        Text("Kosteus")
                                            .fontWeight(.medium)
                                            .frame(width: 60, alignment: .leading)
                                        Text("Tuuli")
                                            .fontWeight(.medium)
                                            .frame(width: 70, alignment: .leading)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.green.opacity(0.1))
                                    
                                    // Morning forecast
                                    if let morning = tomorrow.morning {
                                        HStack {
                                            Text("Aamu")
                                                .frame(width: 80, alignment: .leading)
                                            Text(String(format: "%.1f°", morning.temperature))
                                                .frame(width: 60, alignment: .leading)
                                            Text(morning.description)
                                                .frame(width: 140, alignment: .leading)
                                            Text("\(morning.humidity)%")
                                                .frame(width: 60, alignment: .leading)
                                            Text(String(format: "%.1f m/s", morning.windSpeed))
                                                .frame(width: 70, alignment: .leading)
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 10)
                                    }
                                    
                                    // Afternoon forecast
                                    if let afternoon = tomorrow.afternoon {
                                        HStack {
                                            Text("Iltapäivä")
                                                .frame(width: 80, alignment: .leading)
                                            Text(String(format: "%.1f°", afternoon.temperature))
                                                .frame(width: 60, alignment: .leading)
                                            Text(afternoon.description)
                                                .frame(width: 140, alignment: .leading)
                                            Text("\(afternoon.humidity)%")
                                                .frame(width: 60, alignment: .leading)
                                            Text(String(format: "%.1f m/s", afternoon.windSpeed))
                                                .frame(width: 70, alignment: .leading)
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 10)
                                    }
                                }
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Close button
            Button("Sulje") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 10)
        }
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            loadWeatherData(weatherData)
        }
    }
}

// Main App
struct WeatherApp: App {
    init() {
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = false
            window.title = "Säätiedot"
            window.setContentSize(NSSize(width: 500, height: 600))
            window.center()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}

// Run the app
WeatherApp.main()