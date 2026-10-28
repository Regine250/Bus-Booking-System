import 'dart:convert';

import 'package:http/http.dart' as http;

// This file has NO widgets and NO saving: only the model and the server.
// That is why `dart run check_weather.dart` can test it without an emulator.

// ---------------- Cities (step 6) ----------------

class City {
  const City(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}

const cities = [
  City('Kigali', -1.9441, 30.0619),
  City('Huye', -2.5967, 29.7394),
  City('Musanze', -1.4998, 29.6344),
  City('Rubavu', -1.6792, 29.2585),
];

// ---------------- The model (step 2, + time and toJson for step 8) ----------------

class Weather {
  Weather({
    required this.temperature,
    required this.humidity,
    required this.wind,
    required this.code,
    required this.time,
  });

  final double temperature;
  final int humidity;
  final double wind;
  final int code;
  final String time; // looks like "2026-10-28T12:30" (Kigali time)

  // JSON Map -> Weather (reading from the server, or from the phone)
  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature_2m'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      wind: (json['wind_speed_10m'] as num).toDouble(),
      code: (json['weather_code'] as num).toInt(),
      time: json['time'] as String,
    );
  }

  // Weather -> JSON Map (the opposite of fromJson, used to save on the phone).
  // Same keys as the server, so fromJson can read both.
  Map<String, dynamic> toJson() {
    return {
      'temperature_2m': temperature,
      'relative_humidity_2m': humidity,
      'wind_speed_10m': wind,
      'weather_code': code,
      'time': time,
    };
  }

  // "2026-10-28T12:30" -> "12:30" (characters 11 to 15)
  String get clock => time.substring(11, 16);
}

// ---------------- Weather code -> words (step 5) ----------------

String describe(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Cloudy';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}

// ---------------- The request (step 2, now for any city) ----------------

Future<Weather> fetchWeather(City city) async {
  final url = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
        '?latitude=${city.latitude}&longitude=${city.longitude}'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
        '&timezone=Africa%2FKigali',
  );
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('The weather server answered ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return Weather.fromJson(data['current'] as Map<String, dynamic>);
}
