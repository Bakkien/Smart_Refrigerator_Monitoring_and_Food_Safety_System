#include <ArduinoJson.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include "DHT.h"
#include "time.h"

// =======================
// WiFi Configuration
// =======================
const char* ssid = "myUUM_Guest";
const char* password = ""; 

String deviceID = "SRM01";

// =======================
// DHT11 Configuration
// =======================
#define DHTPIN 4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// =======================
// Settings Variables (Default values)
// =======================
float temperatureThreshold = 10.0;
float humidityThresholdHigh = 85.0;
float humidityThresholdLow = 50.0;
int gasThresholdNormal = 150;
int gasThresholdWarning = 300;
int uploadInterval = 5;  // in seconds

// =======================
// MQ-2 Configuration
// =======================
#define MQ2_PIN 34 

// =======================
// HC-SR04 Configuration
// =======================
const int trigPin = 5;
const int echoPin = 18;

// Door status thresholds
#define DOOR_OPEN_THRESHOLD 5.0

long duration;
float distanceCm;

// =======================
// Buzzer Configuration
// =======================
#define BUZZER_PIN 25

// Buzzer timing variables
unsigned long lastBuzzerToggle = 0;
int buzzerState = LOW;
int beepInterval = 0;
bool buzzerEnabled = true; 

// =======================
// Boot Button Configuration (ESP32)
// =======================
#define BOOT_BUTTON_PIN 0

// =======================
// OLED Configuration
// =======================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// =======================
// NTP Time Configuration
// Malaysia time = UTC +8
// =======================
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 8 * 3600;
const int daylightOffset_sec = 0;

// =======================
// Timing
// =======================
unsigned long previousMillis = 0;
unsigned long lastSettingsCheck = 0;

// Variables to store latest readings
float latestTemperature = 0;
float latestHumidity = 0;
int latestGas = 0;
float latestDistance = 0;
String latestTime = "";
String latestDate = "";

bool dataAvailable = false;
bool wifiConnected = false;

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Initialize DHT11
  dht.begin();

  // Initialize HC-SR04 pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  // Initialize buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Initialize boot button (pull-up enabled)
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("OLED Not Found"));
    while (true);
  }
  
  // Clear display and show startup message
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 10);
  display.println("Refrigerator Monitor");
  display.setCursor(0, 25);
  display.println("Initializing...");
  display.display();
  delay(1000);

  connectWiFi();

  if (WiFi.status() == WL_CONNECTED) {
    setupTime();
    getSettingsFromServer();
  }

  // Show initial display
  updateOLEDDisplay();
}

void loop() {
  // Check WiFi connection and reconnect if needed
  checkWiFiConnection();

  unsigned long currentMillis = millis();

  // Handle boot button press
  handleBootButton();

  // Handle buzzer
  handleBuzzer();

  static unsigned long lastDisplayUpdate = 0;
  if (currentMillis - lastDisplayUpdate >= 1000) {
    lastDisplayUpdate = currentMillis;
    updateOLEDDisplay();
  }

  // Check for settings update every 10 seconds
  if (currentMillis - lastSettingsCheck >= 10000) {
    lastSettingsCheck = currentMillis;
    if (WiFi.status() == WL_CONNECTED) {
      getSettingsFromServer();
    }
  }

  if (currentMillis - previousMillis >= (uploadInterval * 1000)) {
    previousMillis = currentMillis;

    // Read all sensors
    latestHumidity = dht.readHumidity();
    latestTemperature = dht.readTemperature();
    latestGas = analogRead(MQ2_PIN);
    latestDistance = getDistanceCM();

    // Check if DHT readings are valid
    if (isnan(latestHumidity) || isnan(latestTemperature)) {
      Serial.println("Failed to read from DHT11 sensor.");
      dataAvailable = false;
    } else {
      dataAvailable = true;
    }

    // Get time
    latestDate = getDateString();
    latestTime = getTimeString();

    if (latestDate == "" || latestTime == "") {
      Serial.println("Time not available. Data not sent.");
      return;
    }

    // Print to Serial Monitor
    Serial.println();
    Serial.println("========== REFRIGERATOR STATUS ==========");
    Serial.print("Device ID: ");
    Serial.println(deviceID);

    Serial.print("Temperature: ");
    Serial.print(latestTemperature);
    Serial.print(" °C [");
    Serial.print(getTempStatus(latestTemperature));
    Serial.println("]");

    Serial.print("Humidity: ");
    Serial.print(latestHumidity);
    Serial.print(" % [");
    Serial.print(getHumidityStatus(latestHumidity));
    Serial.println("]");

    Serial.print("Gas Status: ");
    Serial.print(getGasStatus(latestGas));
    Serial.print(" (Raw: ");
    Serial.print(latestGas);
    Serial.println(")");

    Serial.print("Distance: ");
    Serial.print(latestDistance);
    Serial.print(" cm [DOOR: ");
    Serial.print(getDoorStatus(latestDistance));
    Serial.println("]");

    Serial.print("Date: ");
    Serial.println(latestDate);

    Serial.print("Time: ");
    Serial.println(latestTime);
    
    Serial.print("Buzzer: ");
    Serial.println(buzzerEnabled ? "ENABLED" : "DISABLED");
    Serial.println("=========================================");

    updateOLEDDisplay();

    sendDataToMySQL();
  }
}

// =======================
// Settings Functions
// =======================
void getSettingsFromServer() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected. Cannot get settings.");
        return;
    }
    
    String serverURL = "http://canorcannot.com/Bakkien/SRM/api/getSettings.php?device_id=" + deviceID;
    
    HTTPClient http;
    http.begin(serverURL);
    
    Serial.println("Getting settings from server...");
    int httpResponseCode = http.GET();
    
    if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.println("Settings response: " + response);
        
        StaticJsonDocument<512> doc;
        DeserializationError error = deserializeJson(doc, response);
        
        if (!error) {
            String status = doc["status"];
            if (status == "success") {
                JsonObject data = doc["data"];
                
                // Update settings from database
                temperatureThreshold = data["temperature_threshold"] | 10.0;
                humidityThresholdHigh = data["humidity_threshold_high"] | 85.0;
                humidityThresholdLow = data["humidity_threshold_low"] | 50.0;
                gasThresholdNormal = data["gas_threshold_normal"] | 150;
                gasThresholdWarning = data["gas_threshold_warning"] | 300;
                uploadInterval = data["upload_interval"] | 5;
                buzzerEnabled = data["buzzer_enabled"].as<bool>();
                
                Serial.println("Settings loaded from database successfully!");
                applySettings();
            } else {
                String message = doc["message"];
                Serial.println("Error: " + message);
                Serial.println("Using default settings.");
            }
        } else {
            Serial.println("Failed to parse JSON. Using default settings.");
        }
    } else {
        Serial.println("Error getting settings. HTTP Code: " + String(httpResponseCode));
        Serial.println("Using default settings.");
    }
    
    http.end();
}

void updateBuzzerSettingToServer(bool enabled) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected. Cannot update buzzer setting.");
        return;
    }
    
    const char* serverURL = "http://canorcannot.com/Bakkien/SRM/api/updateBuzzer.php";
    
    HTTPClient http;
    http.begin(serverURL);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    
    String postData = "device_id=" + deviceID;
    postData += "&buzzer_enabled=" + String(enabled ? 1 : 0);
    
    Serial.println("Updating buzzer setting to: " + String(enabled ? "ENABLED" : "DISABLED"));
    int httpResponseCode = http.POST(postData);
    
    if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.println("Update response: " + response);
        
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, response);
        
        if (!error) {
            String status = doc["status"];
            if (status == "success") {
                Serial.println("Buzzer setting updated on server!");
            } else {
                String message = doc["message"];
                Serial.println("Error: " + message);
            }
        } else {
            Serial.println("Failed to parse response");
        }
    } else {
        Serial.println("Error updating buzzer. HTTP Code: " + String(httpResponseCode));
    }
    
    http.end();
}

void applySettings() {
    Serial.println("========================================");
    Serial.println("SETTINGS APPLIED");
    Serial.println("========================================");
    Serial.println("Temp Threshold: " + String(temperatureThreshold) + "°C");
    Serial.println("Humidity High: " + String(humidityThresholdHigh) + "%");
    Serial.println("Humidity Low: " + String(humidityThresholdLow) + "%");
    Serial.println("Gas Normal: " + String(gasThresholdNormal));
    Serial.println("Gas Warning: " + String(gasThresholdWarning));
    Serial.println("Upload Interval: " + String(uploadInterval) + "s");
    Serial.println("Buzzer: " + String(buzzerEnabled ? "ENABLED" : "DISABLED"));
    Serial.println("========================================");
}

// =======================
// WiFi Functions
// =======================
void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid);

  int retry = 0;

  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected successfully.");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Failed to connect WiFi.");
  }
}

void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    Serial.println("WiFi disconnected. Reconnecting...");
    showWiFiStatus("DISCONNECTED");
    
    connectWiFi();
    
    if (WiFi.status() == WL_CONNECTED) {
      wifiConnected = true;
      showWiFiStatus("CONNECTED");
      setupTime();
      getSettingsFromServer();  // Get settings after reconnection
      delay(1000);
    } else {
      showWiFiStatus("FAILED");
      delay(1000);
    }
  } else {
    wifiConnected = true;
  }
}

void showWiFiStatus(String status) {
  display.clearDisplay();
  display.drawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  display.setCursor(2, 10);
  display.println("WiFi Status");
  display.drawLine(0, 20, 128, 20, SSD1306_WHITE);
  
  display.setCursor(2, 30);
  display.print("SSID: ");
  display.println(ssid);
  
  display.setCursor(2, 42);
  display.print("Status: ");
  display.println(status);
  
  display.setCursor(2, 54);
  if (status == "CONNECTED") {
    display.print("IP: ");
    display.print(WiFi.localIP());
  } else {
    display.print("Reconnecting...");
  }
  
  display.display();
}

// =======================
// Sensor Functions
// =======================
float getDistanceCM() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  duration = pulseIn(echoPin, HIGH, 30000);
  
  if (duration == 0) {
    return 999.0;
  }
  
  float distance = duration * 0.0343 / 2.0;
  
  if (distance > 400) {
    return 999.0;
  }
  
  return distance;
}

String getTempStatus(float temp) {
  if (temp > temperatureThreshold) {
    return "WARM";
  } else {
    return "NORMAL";
  }
}

String getHumidityStatus(float humidity) {
  if (humidity > humidityThresholdHigh) {
    return "HIGH";
  } else if (humidity < humidityThresholdLow) {
    return "LOW";
  } else {
    return "NORMAL";
  }
}

String getGasStatus(int gasValue) {
  if (gasValue < gasThresholdNormal) {
    return "NORMAL";
  } else if (gasValue < gasThresholdWarning) {
    return "SPOILAGE";
  } else {
    return "LEAK";
  }
}

String getDoorStatus(float distance) {
  if (distance < 0) {
    return "ERROR";
  } else if (distance > DOOR_OPEN_THRESHOLD) {
    return "OPEN";
  } else {
    return "CLOSED";
  }
}

String getSystemStatus() {
    if (getGasStatus(latestGas) == "LEAK" || getDoorStatus(latestDistance) == "OPEN") {
        return "CRITICAL";
    } else if (getGasStatus(latestGas) == "SPOILAGE" || 
               getTempStatus(latestTemperature) == "WARM" ||
               getHumidityStatus(latestHumidity) == "HIGH" ||
               getHumidityStatus(latestHumidity) == "LOW") {
        return "WARNING";
    }
    return "NORMAL";
}

// =======================
// Time Functions
// =======================
void setupTime() {
  Serial.println("Configuring NTP time...");
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  struct tm timeinfo;

  int retry = 0;
  while (!getLocalTime(&timeinfo) && retry < 20) {
    Serial.print(".");
    delay(500);
    retry++;
  }

  Serial.println();

  if (retry < 20) {
    Serial.println("Time synchronized successfully.");
    Serial.println(&timeinfo, "%Y-%m-%d %H:%M:%S");
  } else {
    Serial.println("Failed to obtain NTP time.");
  }
}

String getDateString() {
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    return "";
  }

  char dateBuffer[11];
  strftime(dateBuffer, sizeof(dateBuffer), "%Y-%m-%d", &timeinfo);

  return String(dateBuffer);
}

String getTimeString() {
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    return "";
  }

  char timeBuffer[9];
  strftime(timeBuffer, sizeof(timeBuffer), "%H:%M:%S", &timeinfo);

  return String(timeBuffer);
}

// =======================
// Buzzer Functions
// =======================
bool shouldBuzzerBeActive() {
  if (getSystemStatus() == "CRITICAL" || getSystemStatus() == "WARNING") {
    return true;
  }
  return false;
}

int getBeepInterval() {
  if (getSystemStatus() == "CRITICAL") {
    return 200;
  }
  if (getSystemStatus() == "WARNING") {
    return 400;
  }
  return 0;
}

void handleBuzzer() {
  unsigned long currentMillis = millis();
  
  if (!buzzerEnabled) {
    digitalWrite(BUZZER_PIN, LOW);
    return;
  }
  
  if (shouldBuzzerBeActive()) {
    beepInterval = getBeepInterval();
    
    if (currentMillis - lastBuzzerToggle >= beepInterval) {
      lastBuzzerToggle = currentMillis;
      buzzerState = !buzzerState;
      digitalWrite(BUZZER_PIN, buzzerState);
    }
  } else {
    digitalWrite(BUZZER_PIN, LOW);
    buzzerState = LOW;
  }
}

void handleBootButton() {
  static unsigned long lastButtonPress = 0;
  static bool lastButtonState = HIGH;
  
  bool buttonState = digitalRead(BOOT_BUTTON_PIN);
  
  if (buttonState == LOW && lastButtonState == HIGH) {
    if (millis() - lastButtonPress > 300) {
      buzzerEnabled = !buzzerEnabled;
      lastButtonPress = millis();
      
      Serial.println();
      Serial.println("========== BUZZER CONTROL ==========");
      Serial.println(buzzerEnabled ? "BUZZER: ENABLED" : "BUZZER: DISABLED");
      digitalWrite(BUZZER_PIN, LOW);
      Serial.println("====================================");

      if (WiFi.status() == WL_CONNECTED) {
        updateBuzzerSettingToServer(buzzerEnabled);
      } else {
        Serial.println("WiFi not connected. Buzzer setting will be updated when WiFi reconnects.");
      }
    }
  }
  
  lastButtonState = buttonState;
}

// =======================
// OLED Display Function
// =======================
void updateOLEDDisplay() {
  display.clearDisplay();
  
  display.drawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
  
  display.setTextSize(1);
  display.setCursor(2, 2);
  if (latestDate != "") {
    display.print(latestDate);
  } else {
    display.print("--/--/----");
  }
  
  if (latestTime != "") {
    display.setCursor(70, 2);
    display.print(latestTime);
  } else {
    display.setCursor(70, 2);
    display.print("--:--:--");
  }
  
  display.drawLine(0, 11, 128, 11, SSD1306_WHITE);
  
  display.setCursor(2, 15);
  display.print("ID: ");
  display.print(deviceID);

  display.setCursor(80, 15);
  display.print(getSystemStatus());
  
  display.setCursor(2, 28);
  display.print("Door: ");
  if (latestDistance < 999.0) {
    display.print(getDoorStatus(latestDistance));
  } else {
    display.print("ERROR");
  }
  
  display.setCursor(2, 41);
  display.print("Gas: ");
  display.print(getGasStatus(latestGas));
  
  display.setCursor(2, 54);
  display.print("T: ");
  if (dataAvailable) {
    display.print(latestTemperature, 1);
    display.print((char)247);
    display.print("C");
  } else {
    display.print("--.- C");
  }
  
  display.setCursor(70, 54);
  display.print("H: ");
  if (dataAvailable) {
    display.print(latestHumidity, 1);
    display.print("%");
  } else {
    display.print("--.-%");
  }
  
  display.display();
}

// =======================
// Data Upload Function
// =======================
void sendDataToMySQL() {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected. Cannot send data.");
        return;
    }
    
    const char* serverURL = "http://canorcannot.com/Bakkien/SRM/api/uploadSensor.php";

    HTTPClient http;
    http.begin(serverURL);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");

    String datetime = latestDate + " " + latestTime;
    
    String postData = "device_id=" + deviceID;
    postData += "&temperature=" + String(latestTemperature, 2);
    postData += "&humidity=" + String(latestHumidity, 2);
    postData += "&gas_level=" + String(latestGas);
    postData += "&door_status=" + getDoorStatus(latestDistance);
    postData += "&system_status=" + getSystemStatus();
    postData += "&created_at=" + datetime;
    
    int httpResponseCode = http.POST(postData);
    
    if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.println("HTTP Response code: " + String(httpResponseCode));
        Serial.println("Server response: " + response);
    } else {
        Serial.println("Error sending data. HTTP Code: " + String(httpResponseCode));
    }
    
    http.end();
}