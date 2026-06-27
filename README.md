# Smart Refrigerator Monitoring and Food Safety System

## Overview

The Smart Refrigerator Monitoring and Food Safety System is an IoT-based solution designed to continuously monitor the environmental conditions inside a household refrigerator. The system uses an ESP32 microcontroller equipped with DHT11, HC-SR04, and MQ-2 sensors to measure temperature, humidity, door status, and gas levels. Real-time data is displayed locally on an OLED display, and an active buzzer provides audible alerts for abnormal conditions. Sensor data is transmitted to a cloud server built with PHP and MySQL, and users can remotely monitor and control the system through a Flutter mobile application.

## Features

- **Real-time Sensor Monitoring**: Continuously measures temperature, humidity, gas levels, and door status using DHT11, MQ-2, and HC-SR04 sensors.
- **Local Display and Alerts**: OLED display shows real-time sensor readings; active buzzer triggers alerts for WARNING and CRITICAL conditions.
- **Cloud Data Storage**: Sensor data is securely stored in a MySQL database via PHP API endpoints.
- **Remote Monitoring and Control**: Flutter mobile application allows users to view live data, access historical trends, and configure system settings remotely.
- **System Status Classification**: Automatically classifies refrigerator conditions as NORMAL, WARNING, or CRITICAL based on user-defined thresholds.
- **User Authentication**: Secure login and registration system for user access control.
- **Multi-Device Support**: Users can register and monitor multiple refrigerator devices.
- **Dual WiFi Configuration**: Configure WiFi via web interface (AP mode) or mobile application.
- **Auto-Reconnection**: The ESP32 automatically reconnects to Wi-Fi after a lost connection to ensure continuous data transmission.

## System Architecture

The system is built on a four-layer architecture:

| **Layer** | **Components** | **Function** |
| :--- | :--- | :--- |
| **Hardware** | ESP32, DHT11, HC-SR04, MQ-2, OLED Display, Active Buzzer | Reads environmental data and provides local alerts and display |
| **Communication** | Wi-Fi Module (ESP32 built-in), HTTP/HTTPS Protocol | Transmits sensor data from hardware to cloud server |
| **Backend and Database** | PHP, MySQL | Handles authentication, stores and manages incoming sensor data and system configurations |
| **Application** | Flutter Mobile App | Fetches and displays real-time and historical data remotely |

## Hardware Components

| **Category** | **Component** | **Purpose** |
| :--- | :--- | :--- |
| Microcontroller | ESP32 Breakout Board | Reads data from sensors, connects to Wi-Fi, and uploads data to the database |
| Sensors | DHT11 Temperature & Humidity Sensor | Measures temperature and humidity inside the refrigerator |
| | MQ-2 Smoke & Gas Sensor | Detects gas levels emitted from spoiled food or refrigerator leaks |
| | HC-SR04 Ultrasonic Sensor | Measures distance to detect whether the refrigerator door is open or closed |
| Display | 0.96" I2C OLED (SSD1306) | Displays real-time sensor data locally |
| Input | ESP32 Boot Button | Short press to toggle the active buzzer; long press (3 seconds) to reset WiFi configuration |
| Output | Active Buzzer (5V) | Generates audible alerts when abnormal conditions are detected |
| Prototype | Custom PCB, Breadboard | Used to build and assemble the prototype circuit |
| Wiring | Male-to-Male Jumpers, Male-to-Female Jumpers | Establishes electrical connections between components |

## Circuit Diagram

<img width="500" alt="Circuit Diagram" src="https://github.com/user-attachments/assets/0fc48180-43f8-4151-a6b7-a0d06aa421fe" />

## Backend API Endpoints

| **API Endpoint** | **Method** | **Purpose** |
| :--- | :--- | :--- |
| `api/getDevices.php` | GET | Retrieves registered device details for multi-refrigerator support |
| `api/getHistory.php` | GET | Fetches historical sensor readings for analysis over selected periods |
| `api/getLatestData.php` | GET | Retrieves the latest sensor data for the mobile dashboard |
| `api/getSettings.php` | GET | Reads current system thresholds and configurations |
| `api/getWifiConfig.php` | GET | Gets the current WiFi connection details including SSID and password |
| `api/loginUser.php` | POST | Verifies user credentials before navigating to the dashboard |
| `api/registerDevice.php` | POST | Registers a new device to access its sensor data |
| `api/registerUser.php` | POST | Registers a new user for first-time access |
| `api/updateBuzzer.php` | POST | Toggles the buzzer on or off from the mobile application |
| `api/updateSettings.php` | POST | Updates system thresholds from the mobile application |
| `api/updateWifiConfig.php` | POST | Updates WiFi configuration from the mobile application |
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
| `wifi_ssid` | WiFi name/Service Set Identifier |
| `wifi_password` | WiFi password |
| `temperature_threshold` | Maximum allowable temperature limit |
| `humidity_threshold_low` | Minimum allowable humidity limit |
| `humidity_threshold_high` | Maximum allowable humidity limit |
| `gas_threshold_normal` | Normal gas level threshold |
| `gas_threshold_warning` | Warning gas level threshold |
| `upload_interval` | Interval for uploading sensor data (in seconds) |
| `buzzer_enabled` | 0 (DISABLED) or 1 (ENABLED) |
| `updated_at` | Date and time of last update |

### Table 3: `users`

| **Field** | **Description** |
| :--- | :--- |
| `id` | Unique record ID |
| `username` | User's username |
| `email` | User's email address |
| `password` | User's login password |
| `device_id` | ESP32 device identifier |
| `created_at` | Date and time of registration |

## WiFi Configuration

The ESP32 firmware contains an extensive WiFi configuration system that allows users to connect the device to their existing WiFi network through two methods: web interface or mobile application.

### Web-Based WiFi Configuration (AP Mode)

1. Power on the ESP32. If no WiFi credentials are saved, it will boot into AP mode.
2. Connect your phone or computer to the **SRM01_AP** WiFi network.
3. Open a browser and navigate to **192.168.4.1**.
4. The web interface displays the device ID and a list of available WiFi networks with security information.
5. Select your WiFi network from the list.
6. Enter the WiFi password if required.
7. Press the "Connect" button.
8. The ESP32 saves the credentials to preferences, restarts, and connects to the network in station mode.

### Mobile Application WiFi Configuration

1. Log in to the mobile application and navigate to the WiFi Configuration page.
2. Select the device you want to configure.
3. The text fields display the current SSID and password the ESP32 is connected to.
4. Enter the new SSID and password.
5. Click the "Save Wi-Fi Settings" button.
6. The new SSID and password are stored in the database.
7. The ESP32 checks for WiFi configuration updates every 5 minutes.
8. If the SSID and password are different from the stored preferences, the ESP32 clears the previous credentials and connects to the new WiFi.
9. The ESP32 stores the new SSID and password in preferences.

### Connection Process (Web-Based)

1. ESP32 loads preferences to get saved WiFi credentials.
2. If credentials exist, ESP32 initializes in station mode and attempts to connect to the saved SSID. If no credentials exist, ESP32 initializes in AP mode.
3. User browses 192.168.4.1 to configure the WiFi.
4. ESP32 scans nearby available WiFi networks for easy selection.
5. User enters the password and ESP32 starts connecting to the WiFi.
6. Attempts are made up to 30 times to connect to the network.
7. After successfully connecting, the ESP32 gets its IP address and verifies connectivity via the Serial Monitor. The ESP32 also stores the SSID and password in preferences.
8. If connection fails after 30 attempts, the system returns to AP mode.

### Resetting WiFi Configuration

1. Long-press the BOOT button on the ESP32 for **3 seconds** until the OLED shows **"SETTINGS RESET"**.
2. The ESP32 clears all stored preferences, restarts, and boots into AP mode.
3. Users can then reconfigure the WiFi connection from scratch.

## Settings Configuration

Settings are retrieved from the MySQL database via the PHP API endpoint `getSettings.php`. This enables users to configure thresholds and system behavior from the mobile application without reprogramming the ESP32.

### Retrieval Process:

1. The ESP32 makes a GET request to `getSettings.php` with the `device_id` parameter.
2. The server responds with a JSON object containing the settings for the specific device.
3. The ESP32 parses the JSON and updates local configuration parameters.
4. If the request fails, default values are used.

### Settings Update Process:

1. User modifies thresholds via the mobile application.
2. A POST request is sent to `updateSettings.php`.
3. The server updates the sensor threshold fields in the database.
4. The ESP32 fetches updated settings every **5 minutes**.
5. The buzzer can also be toggled locally using the boot button.

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
   - Open the Arduino sketch file.
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

1. Power on the ESP32. The system will initialize and start displaying sensor data on the OLED display.
2. If no WiFi credentials are saved, the ESP32 will enter AP mode. Connect to the **SRM01_AP** network and configure WiFi via the web interface at **192.168.4.1**.
3. Launch the mobile application and log in or register a new account.
4. Register your device ID in the app to start viewing sensor data.
5. The dashboard will show real-time readings, system status, and historical charts.
6. Use the Settings page to configure thresholds, toggle the buzzer, and adjust the upload interval.
7. The active buzzer will sound locally when the system detects WARNING or CRITICAL conditions.

## Testing

The system was tested for:

**Hardware:**
- Access Point Mode
- WiFi connectivity and auto-reconnection
- NTP time synchronization
- Sensor data accuracy and display
- OLED display functionality
- Buzzer activation and control via short press
- WiFi reset via long press

**Mobile Application:**
- User registration and login
- Auto-login functionality
- Device registration and multi-device support
- User device isolation (users cannot view/control other users' devices)
- Dashboard display and auto-refresh
- System alerts
- Logout functionality

**Data Communication:**
- Data upload to the server
- Database storage and retrieval
- WiFi configuration via mobile app
- Settings configuration via mobile app

All test cases were completed successfully.

## Gallery

### Hardware System

| | | |
|:---:|:---:|:---:|
| <img width="300" alt="System Photo 1" src="https://github.com/user-attachments/assets/b6283b7e-196e-442c-a4b3-b480b75e8a90" /> | <img width="300" alt="System Photo 2" src="https://github.com/user-attachments/assets/d36c2f81-0840-4bce-8105-d4f45b5a5084" /> | <img width="300" alt="System Photo 3" src="https://github.com/user-attachments/assets/3f95a5e9-1123-4104-8bf7-d71ea487d2ad" /> |
| *Front View* | *Top View* | *Back View* |

---

### Mobile Application

| | | | | | |
|:---:|:---:|:---:|:---:|:---:|:---:|
| <img width="220"  alt="Login" src="https://github.com/user-attachments/assets/1e6174b4-531d-4c1a-926b-80b9cfd8fa56" /> | <img width="200" alt="Register" src="https://github.com/user-attachments/assets/9f5a8c6b-7cfb-4b45-9c10-1dfc81bcdcca" /> | <img width="190" alt="Dashboard" src="https://github.com/user-attachments/assets/d6fca065-5a25-4597-a6dd-c3a1660f1f70" /> | <img width="210" alt="Settings" src="https://github.com/user-attachments/assets/0d5c26fb-062f-423b-b3d4-5c1c3e18a39f" /> | <img width="180" alt="WiFi" src="https://github.com/user-attachments/assets/66e147d3-a229-4d97-8236-4d7ede80751c" /> | <img width="200" alt="Sensor" src="https://github.com/user-attachments/assets/f9b25e08-c458-4794-a736-2e59b22b9996" /> |
| *Login Page* | *Register Page* | *Dashboard Page* | *Settings Page* | *WiFi Configuration Page* | *Sensor Thresholds Page* |

---

### OLED Display

| | | | |
|:---:|:---:|:---:|:---:|
| <img width="200" alt="Startup Screen" src="https://github.com/user-attachments/assets/9f6c1a1c-da8f-469b-a463-96ebabc0a354" /> | <img width="200" alt="AP Mode Screen" src="https://github.com/user-attachments/assets/858533fb-2ece-4178-b332-ad0db9e8c30f" /> | <img width="200" alt="Main Display" src="https://github.com/user-attachments/assets/cf5f9530-e4ab-4e90-b9d8-3cd28c7b1023" /> | <img width="200" alt="WiFi Status" src="https://github.com/user-attachments/assets/a7de8b14-4f0c-403b-8958-b6be10c467eb" /> |
| *Startup Screen* | *AP Mode Screen* | *Main Monitoring Screen* | *WiFi Status Screen* |

