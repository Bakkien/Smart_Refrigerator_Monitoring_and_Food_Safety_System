# Smart Refrigerator Monitoring and Food Safety System

## Overview

The Smart Refrigerator Monitoring and Food Safety System is an IoT-based solution designed to continuously monitor the environmental conditions inside a household refrigerator. The system uses an ESP32 microcontroller equipped with DHT11, HC-SR04, and MQ-2 sensors to measure temperature, humidity, door status, and gas levels. Real-time data is displayed locally on an OLED display, and an active buzzer provides audible alerts for abnormal conditions. Sensor data is transmitted to a cloud server built with PHP and MySQL, and users can remotely monitor and control the system through a Flutter mobile application.

## Features

- **Real-time Sensor Monitoring**: Continuously measures temperature, humidity, gas levels, and door status using DHT11, MQ-2, and HC-SR04 sensors.
- **Local Display and Alerts**: OLED display shows real-time sensor readings; active buzzer triggers alerts for WARNING and CRITICAL conditions.
- **Cloud Data Storage**: Sensor data is securely stored in a MySQL database via PHP API endpoints.
- **Remote Monitoring and Control**: Flutter mobile application allows users to view live data, access historical trends, and configure system settings remotely.
- **System Status Classification**: Automatically classifies refrigerator conditions as NORMAL, WARNING, or CRITICAL based on user-defined thresholds.
- **Auto-Reconnection**: The ESP32 automatically reconnects to Wi-Fi after a lost connection to ensure continuous data transmission.

## System Architecture

The system is built on a four-layer architecture:

| **Layer** | **Components** | **Function** |
| :--- | :--- | :--- |
| **Hardware** | ESP32, DHT11, HC-SR04, MQ-2, OLED Display, Active Buzzer | Reads environmental data and provides local alerts and display |
| **Communication** | Wi-Fi Module (ESP32 built-in), HTTP/HTTPS Protocol | Transmits sensor data from hardware to cloud server |
| **Backend and Database** | PHP, MySQL | Stores and manages incoming sensor data and system configurations |
| **Application** | Flutter Mobile App | Fetches and displays real-time and historical data remotely |

## Hardware Components

| **Category** | **Component** | **Purpose** |
| :--- | :--- | :--- |
| Microcontroller | ESP32 Breakout Board | Reads data from sensors, connects to Wi-Fi, and uploads data to the database |
| Sensors | DHT11 Temperature & Humidity Sensor | Measures temperature and humidity inside the refrigerator |
| | MQ-2 Smoke & Gas Sensor | Detects gas levels emitted from spoiled food or refrigerator leaks |
| | HC-SR04 Ultrasonic Sensor | Measures distance to detect whether the refrigerator door is open or closed |
| Display | 0.96" I2C OLED (SSD1306) | Displays real-time sensor data locally |
| Input | ESP32 Boot Button | Toggles the active buzzer on or off |
| Output | Active Buzzer (5V) | Generates audible alerts when abnormal conditions are detected |
| Prototype | Custom PCB, Breadboard | Used to build and assemble the prototype circuit |
| Wiring | Male-to-Male Jumpers, Male-to-Female Jumpers | Establishes electrical connections between components |

## Circuit Diagram

<img width="845" height="897" alt="image" src="https://github.com/user-attachments/assets/d9b58f93-f0a4-4431-9306-38cbc81f1dbf" />


## Backend API Endpoints

| **API Endpoint** | **Method** | **Purpose** |
| :--- | :--- | :--- |
| `api/getDevices.php` | GET | Retrieves registered device details for multi-refrigerator support |
| `api/getHistory.php` | GET | Fetches historical sensor readings for analysis over selected periods |
| `api/getLatestData.php` | GET | Retrieves the latest sensor data for the mobile dashboard |
| `api/getSettings.php` | GET | Reads current system thresholds and configurations |
| `api/updateBuzzer.php` | POST | Toggles the buzzer on or off from the mobile application |
| `api/updateSettings.php` | POST | Updates system thresholds from the mobile application |
| `api/uploadSensor.php` | POST | Receives sensor data from the ESP32 and stores it in the database |

## Database Schema

### Table 1: `sensor_data`

| **Field** | **Description** |
| :--- | :--- |
| `id` | Unique record ID |
| `device_id` | ESP32 device identifier |
| `temperature` | Temperature reading in degrees Celsius (°C) |
| `humidity` | Humidity reading in percentage (%) |
| `gas_level` | Gas level reading from MQ-2 sensor |
| `door_status` | OPEN or CLOSED |
| `status` | NORMAL, WARNING, or CRITICAL |
| `created_at` | Date and time of reading |

### Table 2: `device_settings`

| **Field** | **Description** |
| :--- | :--- |
| `id` | Unique record ID |
| `device_id` | ESP32 device identifier |
| `temperature_threshold` | Maximum allowable temperature limit |
| `humidity_threshold_low` | Minimum allowable humidity limit |
| `humidity_threshold_high` | Maximum allowable humidity limit |
| `gas_threshold_normal` | Normal gas level threshold |
| `gas_threshold_warning` | Warning gas level threshold |
| `upload_interval` | Interval for uploading sensor data (in seconds) |
| `buzzer_enabled` | 0 (DISABLED) or 1 (ENABLED) |
| `updated_at` | Date and time of last update |

## Repository Structure

| **Folder** | **Description** |
| :--- | :--- |
| `esp32_smart_refrigerator_monitoring_system/` | Arduino sketch for ESP32 to read sensor data, connect to Wi-Fi, and upload data |
| `server/api/` | PHP backend and API endpoints for data handling and configuration |
| `mobile_app/` | Flutter application for cross-platform mobile monitoring (Android, iOS, etc.) |
| `database/` | Database export file for importing into MySQL |

## Getting Started

### Prerequisites

- ESP32 development board
- DHT11, MQ-2, and HC-SR04 sensors
- 0.96" OLED display (SSD1306)
- Active buzzer (5V)
- Arduino IDE with ESP32 add-on installed
- Web hosting server with PHP and MySQL support
- Flutter SDK for mobile application development

### Installation and Setup

1. **Hardware Setup**
   - Connect the sensors, OLED display, and buzzer to the ESP32 according to the circuit diagram.
   - Ensure all connections are secure.

2. **Arduino IDE Setup**
   - Install the ESP32 add-on in Arduino IDE.
   - Install required libraries: Adafruit DHT, Adafruit SSD1306, Adafruit GFX, and Arduino_JSON.
   - Open the `esp32_smart_refrigerator_monitoring_system.ino` file.
   - Update the Wi-Fi credentials (SSID and password) in the code.
   - Upload the sketch to the ESP32.

3. **Backend Setup**
   - Upload the PHP files (in `server/api/`) to your web hosting server.
   - Import the database file (in `database/`) into your MySQL database using phpMyAdmin or command line.
   - Update the database connection credentials in the PHP files (`$dbname`, `$username`, `$password`).

4. **Mobile Application Setup**
   - Open the Flutter project in your preferred IDE (Android Studio, VS Code).
   - Run `flutter pub get` to install dependencies.
   - Update the API base URL in the application to point to your server.
   - Build and run the application on an emulator or physical device.

## Usage

1. Power on the ESP32. The system will initialize, connect to Wi-Fi, and start displaying sensor data on the OLED display.
2. The mobile application dashboard will show real-time readings, system status, and historical charts.
3. Use the Settings page in the mobile app to configure thresholds, toggle the buzzer, and adjust the upload interval.
4. The active buzzer will sound locally when the system detects WARNING or CRITICAL conditions.

## Testing

The system was tested for:
- Wi-Fi connectivity and auto-reconnection
- NTP time synchronization
- Sensor data accuracy and display
- OLED display functionality
- Buzzer activation and control
- Data upload to the server
- Database storage and retrieval
- Mobile application dashboard and settings synchronization

All test cases were completed successfully.

## Gallery
### Hardware System
| | | |
|:---:|:---:|:---:|
| <img width="300" alt="System Photo 1" src="https://github.com/user-attachments/assets/b6283b7e-196e-442c-a4b3-b480b75e8a90" /> | <img width="300" alt="System Photo 2" src="https://github.com/user-attachments/assets/d36c2f81-0840-4bce-8105-d4f45b5a5084" /> | <img width="300" alt="System Photo 3" src="https://github.com/user-attachments/assets/3f95a5e9-1123-4104-8bf7-d71ea487d2ad" /> |
| *Front View* | *Top View* | *Back View* |

---

### Mobile Application

| | |
|:---:|:---:|
| <img width="250" alt="Dashboard" src="https://github.com/user-attachments/assets/abc6e1e1-b843-40be-98be-49c5cf936806" /> | <img width="250" alt="Settings" src="https://github.com/user-attachments/assets/2b0473af-94cd-49d8-9f12-e188040165c5" /> |
| *Dashboard Screen* | *Settings Screen* |

---

### OLED Display

| | | |
|:---:|:---:|:---:|
| <img width="250" alt="Startup Screen" src="https://github.com/user-attachments/assets/9f6c1a1c-da8f-469b-a463-96ebabc0a354" /> | <img width="250" alt="Main Display" src="https://github.com/user-attachments/assets/cf5f9530-e4ab-4e90-b9d8-3cd28c7b1023" /> | <img width="250" alt="WiFi Status" src="https://github.com/user-attachments/assets/d781aff6-f50a-4871-aa56-67754d1c3360" /> |
| *Startup Screen* | *Main Monitoring Screen* | *WiFi Status Screen* |
