#!/usr/bin/swift

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

// Convert timestamp to day name
func getDayName(from timestamp: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEEE"
    dateFormatter.locale = Locale(identifier: "fi_FI")
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

// Format current weather
func formatCurrentWeather(_ weather: [String: Any]) -> String {
    guard let main = weather["main"] as? [String: Any],
          let temp = main["temp"] as? Double,
          let feelsLike = main["feels_like"] as? Double,
          let humidity = main["humidity"] as? Int,
          let weatherArray = weather["weather"] as? [[String: Any]],
          let firstWeather = weatherArray.first,
          let description = firstWeather["description"] as? String,
          let wind = weather["wind"] as? [String: Any],
          let windSpeed = wind["speed"] as? Double else {
        return "Virhe jäsennettäessä säätietoja"
    }
    
    let finnishDescription = translateWeatherDescription(description)
    
    return """
    Nykyinen sää: \(CITY), \(COUNTRY)
    ┌─────────────────────────────────────────────┐
    │ Lämpötila:   \(String(format: "%.1f", temp))°C (tuntuu \(String(format: "%.1f", feelsLike))°C)
    │ Säätila:     \(finnishDescription)
    │ Kosteus:     \(humidity)%
    │ Tuulen nopeus: \(String(format: "%.1f", windSpeed)) m/s
    └─────────────────────────────────────────────┘
    """
}

// Format hourly forecast
func formatHourlyForecast(_ forecastData: [String: Any]) -> String {
    guard let list = forecastData["list"] as? [[String: Any]] else {
        return "Virhe jäsennettäessä ennustetietoja"
    }
    
    let now = Date()
    let threeHoursLater = now.addingTimeInterval(3 * 3600)
    
    var hourlyForecasts: [String] = []
    hourlyForecasts.append("\nSeuraavien 3 tunnin ennuste:")
    hourlyForecasts.append("┌──────────┬──────────┬─────────────────────┬──────────┬──────────┐")
    hourlyForecasts.append("│   Aika   │ Lämpöt.  │      Säätila        │ Kosteus  │  Tuuli   │")
    hourlyForecasts.append("├──────────┼──────────┼─────────────────────┼──────────┼──────────┤")
    
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
        
        let time = formatTime(from: dt)
        let tempStr = String(format: "%.1f", temp)
        let windStr = String(format: "%.1f m/s", windSpeed)
        let finnishDesc = translateWeatherDescription(description)
        let desc = finnishDesc.prefix(19)
        
        let row = "│ \(time.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(tempStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(String(desc).padding(toLength: 19, withPad: " ", startingAt: 0)) │ \(String(humidity).padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(windStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │"
        hourlyForecasts.append(row)
    }
    
    hourlyForecasts.append("└──────────┴──────────┴─────────────────────┴──────────┴──────────┘")
    
    return hourlyForecasts.joined(separator: "\n")
}

// Format tomorrow's forecast
func formatTomorrowForecast(_ forecastData: [String: Any]) -> String {
    guard let list = forecastData["list"] as? [[String: Any]] else {
        return "Virhe jäsennettäessä ennustetietoja"
    }
    
    let calendar = Calendar.current
    var morningForecast: [String: Any]?
    var afternoonForecast: [String: Any]?
    
    for item in list {
        guard let dt = item["dt"] as? TimeInterval else { continue }
        let itemDate = Date(timeIntervalSince1970: dt)
        
        if calendar.isDateInTomorrow(itemDate) {
            let timeOfDay = getTimeOfDay(from: dt)
            if timeOfDay == "Aamu" && morningForecast == nil {
                morningForecast = item
            } else if timeOfDay == "Iltapäivä" && afternoonForecast == nil {
                afternoonForecast = item
            }
            
            if morningForecast != nil && afternoonForecast != nil {
                break
            }
        }
    }
    
    var result = "\nHuomisen ennuste:"
    result += "\n┌──────────────┬──────────┬─────────────────────┬──────────┬──────────┐"
    result += "\n│  Ajankohta   │ Lämpöt.  │      Säätila        │ Kosteus  │  Tuuli   │"
    result += "\n├──────────────┼──────────┼─────────────────────┼──────────┼──────────┤"
    
    if let morning = morningForecast,
       let main = morning["main"] as? [String: Any],
       let temp = main["temp"] as? Double,
       let humidity = main["humidity"] as? Int,
       let weather = morning["weather"] as? [[String: Any]],
       let firstWeather = weather.first,
       let description = firstWeather["description"] as? String,
       let wind = morning["wind"] as? [String: Any],
       let windSpeed = wind["speed"] as? Double {
        
        let tempStr = String(format: "%.1f", temp)
        let windStr = String(format: "%.1f m/s", windSpeed)
        let finnishDesc = translateWeatherDescription(description)
        let desc = finnishDesc.prefix(19)
        
        let morningRow = "\n│ \("Aamu".padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(tempStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(String(desc).padding(toLength: 19, withPad: " ", startingAt: 0)) │ \(String(humidity).padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(windStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │"
        result += morningRow
    }
    
    if let afternoon = afternoonForecast,
       let main = afternoon["main"] as? [String: Any],
       let temp = main["temp"] as? Double,
       let humidity = main["humidity"] as? Int,
       let weather = afternoon["weather"] as? [[String: Any]],
       let firstWeather = weather.first,
       let description = firstWeather["description"] as? String,
       let wind = afternoon["wind"] as? [String: Any],
       let windSpeed = wind["speed"] as? Double {
        
        let tempStr = String(format: "%.1f", temp)
        let windStr = String(format: "%.1f m/s", windSpeed)
        let finnishDesc = translateWeatherDescription(description)
        let desc = finnishDesc.prefix(19)
        
        let afternoonRow = "\n│ \("Iltapäivä".padding(toLength: 12, withPad: " ", startingAt: 0)) │ \(tempStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(String(desc).padding(toLength: 19, withPad: " ", startingAt: 0)) │ \(String(humidity).padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(windStr.padding(toLength: 8, withPad: " ", startingAt: 0)) │"
        result += afternoonRow
    }
    
    result += "\n└──────────────┴──────────┴─────────────────────┴──────────┴──────────┘"
    
    return result
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

// Main function to fetch and display weather data
func fetchWeather() {
    // Fetch current weather
    guard let currentURL = getCurrentWeatherURL(),
          let currentWeatherData = fetchData(from: currentURL) else {
        print("Virhe: Nykyisen sään hakeminen epäonnistui")
        return
    }
    
    // Fetch forecast data
    guard let forecastURL = getForecastURL(),
          let forecastData = fetchData(from: forecastURL) else {
        print("Virhe: Ennustetietojen hakeminen epäonnistui")
        return
    }
    
    // Display all weather information
    print(formatCurrentWeather(currentWeatherData))
    print(formatHourlyForecast(forecastData))
    print(formatTomorrowForecast(forecastData))
}

// Execute the program
fetchWeather()