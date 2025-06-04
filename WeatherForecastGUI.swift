#!/usr/bin/swift

import SwiftUI
import Foundation

// Configuration structure
struct Config: Codable {
    let openWeatherMapApiKey: String
    let city: String
    let country: String
    let updateIntervalSeconds: Int?
}

// Load configuration
func loadConfig() -> Config? {
    let configPath = "config.json"
    let url = URL(fileURLWithPath: configPath)
    
    do {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data)
        return config
    } catch {
        print("Virhe: config.json tiedostoa ei löydy tai se on virheellinen.")
        print("Luo config.json tiedosto config.example.json pohjalta.")
        print("Lisää oma OpenWeatherMap API-avaimesi tiedostoon.")
        return nil
    }
}

// Load configuration
guard let config = loadConfig() else {
    exit(1)
}

// Constants from config
let CITY = config.city
let COUNTRY = config.country
let API_KEY = config.openWeatherMapApiKey
let UPDATE_INTERVAL = TimeInterval(config.updateIntervalSeconds ?? 60)

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
@MainActor
class WeatherData: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [ForecastItem] = []
    @Published var tomorrowForecast: TomorrowForecast?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var isFrozen = false
    
    private var updateTimer: Timer?
    
    func startAutoUpdate() {
        guard !isFrozen else { return }
        stopAutoUpdate()
        
        // Update immediately
        loadWeatherData()
        
        // Then update based on config interval
        updateTimer = Timer.scheduledTimer(withTimeInterval: UPDATE_INTERVAL, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isFrozen {
                    self.loadWeatherData()
                }
            }
        }
    }
    
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func toggleFreeze() {
        isFrozen.toggle()
        if isFrozen {
            stopAutoUpdate()
        } else {
            startAutoUpdate()
        }
    }
    
    func manualRefresh() {
        loadWeatherData()
    }
    
    deinit {
        // Timer cleanup happens automatically when WeatherData is deallocated
    }
    
    // Load all weather data
    private func loadWeatherData() {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // Run network operations in background
            let result = await Task.detached { () -> (error: String?, current: CurrentWeather?, hourly: [ForecastItem], tomorrow: TomorrowForecast) in
                // Fetch current weather
                guard let currentURL = getCurrentWeatherURL(),
                      let currentWeatherData = fetchData(from: currentURL) else {
                    return (error: "Virhe: Nykyisen sään hakeminen epäonnistui", current: nil, hourly: [], tomorrow: TomorrowForecast(morning: nil, afternoon: nil))
                }
                
                // Fetch forecast data
                guard let forecastURL = getForecastURL(),
                      let forecastData = fetchData(from: forecastURL) else {
                    return (error: "Virhe: Ennustetietojen hakeminen epäonnistui", current: nil, hourly: [], tomorrow: TomorrowForecast(morning: nil, afternoon: nil))
                }
                
                let current = parseCurrentWeather(currentWeatherData)
                let hourly = parseHourlyForecast(forecastData)
                let tomorrow = parseTomorrowForecast(forecastData)
                
                return (error: nil, current: current, hourly: hourly, tomorrow: tomorrow)
            }.value
            
            // Update UI on main thread
            await MainActor.run {
                if let error = result.error {
                    self.errorMessage = error
                } else {
                    self.currentWeather = result.current
                    self.hourlyForecast = result.hourly
                    self.tomorrowForecast = result.tomorrow
                    self.lastUpdateTime = Date()
                }
                self.isLoading = false
            }
        }
    }
}

// API URL for current weather
@Sendable
func getCurrentWeatherURL() -> URL? {
    let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    let urlString = "\(baseURL)?q=\(CITY),\(COUNTRY)&units=metric&appid=\(API_KEY)"
    return URL(string: urlString)
}

// API URL for forecast
@Sendable
func getForecastURL() -> URL? {
    let baseURL = "https://api.openweathermap.org/data/2.5/forecast"
    let urlString = "\(baseURL)?q=\(CITY),\(COUNTRY)&units=metric&appid=\(API_KEY)"
    return URL(string: urlString)
}

// Translate weather descriptions from English to Finnish
@Sendable
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
@Sendable
func formatTime(from timestamp: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"
    dateFormatter.timeZone = TimeZone.current
    return dateFormatter.string(from: date)
}

// Check if time is morning (6-12) or afternoon (12-18)
@Sendable
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
@Sendable
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
@Sendable
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

// Helper function to interpolate weather data for specific hour offset
@Sendable
func interpolateForecastForHour(_ list: [[String: Any]], hoursFromNow: Double) -> [String: Any]? {
    let targetTime = Date().addingTimeInterval(hoursFromNow * 3600)
    
    // Find the two closest forecast entries
    var before: [String: Any]?
    var after: [String: Any]?
    
    for item in list {
        guard let dt = item["dt"] as? TimeInterval else { continue }
        let itemDate = Date(timeIntervalSince1970: dt)
        
        if itemDate <= targetTime {
            before = item
        } else if after == nil {
            after = item
            break
        }
    }
    
    // If we have exact match or only one bound, return it
    if let beforeItem = before,
       let beforeDt = beforeItem["dt"] as? TimeInterval,
       Date(timeIntervalSince1970: beforeDt) == targetTime {
        return beforeItem
    }
    
    // If we only have before or after, return what we have
    if before != nil && after == nil {
        return before
    }
    if before == nil && after != nil {
        return after
    }
    
    // Interpolate between the two
    guard let beforeItem = before,
          let afterItem = after,
          let beforeDt = beforeItem["dt"] as? TimeInterval,
          let afterDt = afterItem["dt"] as? TimeInterval,
          let beforeMain = beforeItem["main"] as? [String: Any],
          let afterMain = afterItem["main"] as? [String: Any],
          let beforeTemp = beforeMain["temp"] as? Double,
          let afterTemp = afterMain["temp"] as? Double,
          let beforeHumidity = beforeMain["humidity"] as? Int,
          let afterHumidity = afterMain["humidity"] as? Int,
          let beforeWind = beforeItem["wind"] as? [String: Any],
          let afterWind = afterItem["wind"] as? [String: Any],
          let beforeWindSpeed = beforeWind["speed"] as? Double,
          let afterWindSpeed = afterWind["speed"] as? Double else {
        return before ?? after
    }
    
    // Calculate interpolation factor
    let targetTimestamp = targetTime.timeIntervalSince1970
    let factor = (targetTimestamp - beforeDt) / (afterDt - beforeDt)
    
    // Interpolate values
    let interpTemp = beforeTemp + (afterTemp - beforeTemp) * factor
    let interpHumidity = Int(Double(beforeHumidity) + Double(afterHumidity - beforeHumidity) * factor)
    let interpWindSpeed = beforeWindSpeed + (afterWindSpeed - beforeWindSpeed) * factor
    
    // Use the weather description from the closest time
    let weather = factor < 0.5 ? beforeItem["weather"] : afterItem["weather"]
    
    // Create interpolated result
    var result = beforeItem
    result["dt"] = targetTimestamp
    result["main"] = [
        "temp": interpTemp,
        "humidity": interpHumidity
    ]
    result["wind"] = [
        "speed": interpWindSpeed
    ]
    result["weather"] = weather
    
    return result
}

// Parse hourly forecast
@Sendable
func parseHourlyForecast(_ forecastData: [String: Any]) -> [ForecastItem] {
    guard let list = forecastData["list"] as? [[String: Any]] else {
        return []
    }
    
    var forecasts: [ForecastItem] = []
    
    // Get forecasts for 1h, 2h, 3h from now
    for hours in [1.0, 2.0, 3.0] {
        if let forecast = interpolateForecastForHour(list, hoursFromNow: hours),
           let dt = forecast["dt"] as? TimeInterval,
           let main = forecast["main"] as? [String: Any],
           let temp = main["temp"] as? Double,
           let humidity = main["humidity"] as? Int,
           let weather = forecast["weather"] as? [[String: Any]],
           let firstWeather = weather.first,
           let description = firstWeather["description"] as? String,
           let wind = forecast["wind"] as? [String: Any],
           let windSpeed = wind["speed"] as? Double {
            
            let time = "+\(Int(hours))h (\(formatTime(from: dt)))"
            
            forecasts.append(ForecastItem(
                time: time,
                temperature: temp,
                description: translateWeatherDescription(description),
                humidity: humidity,
                windSpeed: windSpeed
            ))
        }
    }
    
    // Add afternoon and evening if they're today
    let now = Date()
    let calendar = Calendar.current
    
    // Find afternoon forecast (around 15:00)
    let afternoonComponents = calendar.dateComponents([.year, .month, .day], from: now)
    if var afternoonDate = calendar.date(from: afternoonComponents) {
        afternoonDate = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: afternoonDate) ?? afternoonDate
        
        if afternoonDate > now {
            let hoursUntilAfternoon = afternoonDate.timeIntervalSince(now) / 3600
            if hoursUntilAfternoon <= 12 { // Only show if within next 12 hours
                if let forecast = interpolateForecastForHour(list, hoursFromNow: hoursUntilAfternoon),
                   let main = forecast["main"] as? [String: Any],
                   let temp = main["temp"] as? Double,
                   let humidity = main["humidity"] as? Int,
                   let weather = forecast["weather"] as? [[String: Any]],
                   let firstWeather = weather.first,
                   let description = firstWeather["description"] as? String,
                   let wind = forecast["wind"] as? [String: Any],
                   let windSpeed = wind["speed"] as? Double {
                    
                    forecasts.append(ForecastItem(
                        time: "Iltapäivä",
                        temperature: temp,
                        description: translateWeatherDescription(description),
                        humidity: humidity,
                        windSpeed: windSpeed
                    ))
                }
            }
        }
    }
    
    // Find evening forecast (around 20:00)
    let eveningComponents = calendar.dateComponents([.year, .month, .day], from: now)
    if var eveningDate = calendar.date(from: eveningComponents) {
        eveningDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: eveningDate) ?? eveningDate
        
        if eveningDate > now {
            let hoursUntilEvening = eveningDate.timeIntervalSince(now) / 3600
            if hoursUntilEvening <= 12 { // Only show if within next 12 hours
                if let forecast = interpolateForecastForHour(list, hoursFromNow: hoursUntilEvening),
                   let main = forecast["main"] as? [String: Any],
                   let temp = main["temp"] as? Double,
                   let humidity = main["humidity"] as? Int,
                   let weather = forecast["weather"] as? [[String: Any]],
                   let firstWeather = weather.first,
                   let description = firstWeather["description"] as? String,
                   let wind = forecast["wind"] as? [String: Any],
                   let windSpeed = wind["speed"] as? Double {
                    
                    forecasts.append(ForecastItem(
                        time: "Ilta",
                        temperature: temp,
                        description: translateWeatherDescription(description),
                        humidity: humidity,
                        windSpeed: windSpeed
                    ))
                }
            }
        }
    }
    
    return forecasts
}

// Parse tomorrow's forecast
@Sendable
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


// Main content view
struct ContentView: View {
    @StateObject private var weatherData = WeatherData()
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M.yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "fi_FI")
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            HStack {
                Text("Sää: \(CITY), \(COUNTRY)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if weatherData.isFrozen, let updateTime = weatherData.lastUpdateTime {
                    VStack(alignment: .trailing) {
                        Text("PYSÄYTETTY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Päivitetty: \(timeFormatter.string(from: updateTime))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
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
                                
                                // Digital temperature display
                                HStack {
                                    Spacer()
                                    Text(String(format: "%.1f°C", current.temperature))
                                        .font(.system(size: 48, weight: .light, design: .monospaced))
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("Tuntuu kuin:")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        Text(String(format: "%.1f°C", current.feelsLike))
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
                                Text("Tänään")
                                    .font(.headline)
                                
                                VStack(spacing: 0) {
                                    // Header
                                    HStack {
                                        Text("Aika")
                                            .fontWeight(.medium)
                                            .frame(width: 80, alignment: .leading)
                                        Text("Lämpöt.")
                                            .fontWeight(.medium)
                                            .frame(width: 60, alignment: .leading)
                                        Text("Säätila")
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
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
                                                .frame(width: 80, alignment: .leading)
                                            Text(String(format: "%.1f°", forecast.temperature))
                                                .frame(width: 60, alignment: .leading)
                                            Text(forecast.description)
                                                .frame(width: 120, alignment: .leading)
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
            
            // Control buttons
            HStack(spacing: 20) {
                Button(action: {
                    weatherData.manualRefresh()
                }) {
                    Label("Päivitä nyt", systemImage: "arrow.clockwise")
                }
                .disabled(weatherData.isLoading)
                
                Button(action: {
                    weatherData.toggleFreeze()
                }) {
                    Label(weatherData.isFrozen ? "Jatka päivityksiä" : "Pysäytä päivitykset", 
                          systemImage: weatherData.isFrozen ? "play.fill" : "pause.fill")
                }
                
                Spacer()
                
                Button("Sulje") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Status bar
            if !weatherData.isFrozen, let updateTime = weatherData.lastUpdateTime {
                Text("Päivitetty: \(timeFormatter.string(from: updateTime)) • Päivittyy automaattisesti")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            }
        }
        .padding()
        .frame(width: 550, height: 750)
        .onAppear {
            weatherData.startAutoUpdate()
        }
        .onDisappear {
            weatherData.stopAutoUpdate()
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
            window.setContentSize(NSSize(width: 550, height: 750))
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