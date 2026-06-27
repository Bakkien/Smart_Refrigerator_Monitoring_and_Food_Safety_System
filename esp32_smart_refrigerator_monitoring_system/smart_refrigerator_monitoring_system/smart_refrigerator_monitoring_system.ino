#include <ArduinoJson.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WebServer.h>
#include <DNSServer.h>
#include "DHT.h"
#include "time.h"

// =======================
// WiFi Configuration
// =======================
const char* AP_SSID = "SRM01_AP";
const char* AP_PASSWORD = "12345678";

String wifiSSID;
String wifiPassword;
bool apMode = false;
bool wifiCredentialsAvailable = false;
bool settingsLoadedFromPreferences = false;
unsigned long lastWiFiSettingsCheck = 0;
String lastWiFiSSID = "";
String lastWiFiPassword = "";

String deviceID = "SRM01";

// =======================
// Web Server for AP Mode
// =======================
WebServer server(80);
DNSServer dnsServer;
const byte DNS_PORT = 53;

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
bool buzzerEnabled = true;

// =======================
// MQ-2 Configuration
// =======================
#define MQ2_PIN 34 

// =======================
// HC-SR04 Configuration
// =======================
const int trigPin = 5;
const int echoPin = 18;
#define DOOR_OPEN_THRESHOLD 5.0
long duration;
float distanceCm;

// =======================
// Buzzer Configuration
// =======================
#define BUZZER_PIN 25
unsigned long lastBuzzerToggle = 0;
int buzzerState = LOW;
int beepInterval = 0;

// =======================
// Boot Button Configuration
// =======================
#define BOOT_BUTTON_PIN 0
#define LONG_PRESS_TIME 3000
unsigned long buttonPressStartTime = 0;
bool buttonPressed = false;

// =======================
// OLED Configuration
// =======================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// =======================
// NTP Time Configuration
// =======================
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 8 * 3600;
const int daylightOffset_sec = 0;

// =======================
// Timing
// =======================
unsigned long previousMillis = 0;
unsigned long lastSettingsCheck = 0;
unsigned long lastWiFiScan = 0;
unsigned long apModeStartTime = 0;

// Variables to store latest readings
float latestTemperature = 0;
float latestHumidity = 0;
int latestGas = 0;
float latestDistance = 0;
String latestTime = "";
String latestDate = "";
bool dataAvailable = false;
bool wifiConnected = false;

// =======================
// Preferences Storage
// =======================
Preferences preferences;

// =======================
// Setup
// =======================
void setup() {
  Serial.begin(115200);
  delay(1000);

  // Initialize Preferences
  preferences.begin("srm_settings", false);
  
  // Initialize DHT11
  dht.begin();

  // Initialize HC-SR04 pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  // Initialize buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Initialize boot button
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("OLED Not Found"));
    while (true);
  }
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 10);
  display.println("Refrigerator Monitor");
  display.setCursor(0, 25);
  display.println("Initializing...");
  display.display();
  delay(1000);

  // Load WiFi settings from preferences
  loadWiFiSettings();
  
  // Check if WiFi credentials exist
  if (wifiCredentialsAvailable) {
    Serial.println("WiFi credentials found. Attempting to connect...");
    connectWiFi();
    
    if (WiFi.status() == WL_CONNECTED) {
      wifiConnected = true;
      getSettingsFromPreferences();
      setupTime();
      checkAndUpdateWiFiSettings();
      checkAndUpdateSettings();
    } else {
      Serial.println("WiFi connection failed. Starting AP mode...");
      setupAPMode();
    }
  } else {
    Serial.println("No WiFi credentials found. Starting AP mode...");
    setupAPMode();
  }

  updateOLEDDisplay();
}

// =======================
// Main Loop
// =======================
void loop() {
  // Handle AP mode web server
  if (apMode) {
    dnsServer.processNextRequest();
    server.handleClient();
    // Update AP mode status on OLED periodically
    static unsigned long lastAPUpdate = 0;
    if (millis() - lastAPUpdate >= 5000) {
      lastAPUpdate = millis();
      showAPModeStatus();
    }
    return; // Skip everything else when in AP mode
  }

  // Check WiFi connection and reconnect if needed
  checkWiFiConnection();

  unsigned long currentMillis = millis();

  // Handle boot button press
  handleBootButton();

  // Handle buzzer
  handleBuzzer();

  // Check for settings update only when needed
  if (WiFi.status() == WL_CONNECTED) {
    // Check settings every 5 minutes
    if (currentMillis - lastSettingsCheck >= 300000) {
      lastSettingsCheck = currentMillis;
      checkAndUpdateWiFiSettings();
      checkAndUpdateSettings();
    }
  }

  // Send sensor data based on upload interval
  if (WiFi.status() == WL_CONNECTED) {
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

      printStatus();

      updateOLEDDisplay();
      sendDataToMySQL();
    }
  }
}

// =======================
// WiFi Configuration Functions
// =======================
void loadWiFiSettings() {
  wifiSSID = preferences.getString("wifi_ssid", "");
  wifiPassword = preferences.getString("wifi_password", "");
  deviceID = preferences.getString("device_id", "SRM01");
  
  if (wifiSSID.length() > 0) {
    wifiCredentialsAvailable = true;
    Serial.println("Loaded WiFi settings from preferences:");
    Serial.println("SSID: " + wifiSSID);
    Serial.println("Device ID: " + deviceID);
    Serial.print("Password: ");
    Serial.println(wifiPassword.length() > 0 ? "****" : "(empty)");
  } else {
    wifiCredentialsAvailable = false;
    Serial.println("No WiFi credentials found in preferences");
  }
}

void saveWiFiSettings(String ssid, String password) {
  preferences.putString("wifi_ssid", ssid);
  preferences.putString("wifi_password", password);
  wifiSSID = ssid;
  wifiPassword = password;
  wifiCredentialsAvailable = true;
  Serial.println("WiFi settings saved to preferences");
}

void updateWiFiSettingsToServer(String ssid, String password) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Saving WiFi settings to preferences only.");
    saveWiFiSettings(ssid, password);
    return;
  }
  
  const char* serverURL = "http://canorcannot.com/Bakkien/SRM/api/updateWifiConfig.php";
  
  HTTPClient http;
  http.begin(serverURL);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  
  String postData = "device_id=" + deviceID;
  postData += "&wifi_ssid=" + ssid;
  postData += "&wifi_password=" + password;
  
  Serial.println("Updating WiFi settings on server...");
  int httpResponseCode = http.POST(postData);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("WiFi update response: " + response);
    
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      String respStatus = doc["status"];
      if (respStatus == "success") {
        Serial.println("WiFi settings updated on server!");
        saveWiFiSettings(ssid, password);
        lastWiFiSSID = ssid;
        lastWiFiPassword = password;
      } else {
        String message = doc["message"];
        Serial.println("Error: " + message);
        // Still save locally even if server update failed
        saveWiFiSettings(ssid, password);
      }
    } else {
      Serial.println("Failed to parse WiFi update response");
      // Still save locally
      saveWiFiSettings(ssid, password);
    }
  } else {
    Serial.println("Error updating WiFi settings. HTTP Code: " + String(httpResponseCode));
    // Still save locally
    saveWiFiSettings(ssid, password);
  }
  
  http.end();
}

void checkAndUpdateWiFiSettings() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Skipping WiFi settings update check.");
    return;
  }
  
  String serverURL = "http://canorcannot.com/Bakkien/SRM/api/getWifiConfig.php?device_id=" + deviceID;
  
  HTTPClient http;
  http.begin(serverURL);
  http.setTimeout(10000); // 10 second timeout
  
  Serial.println("Fetching WiFi settings from server...");
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("WiFi settings response received");
    
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      String status = doc["status"];
      if (status == "success") {
        JsonObject data = doc["data"];
        
        String newSSID = data["wifi_ssid"].as<String>();
        String newPassword = data["wifi_password"].as<String>();
        
        // Check if WiFi settings have changed
        if (newSSID.length() > 0 && (newSSID != lastWiFiSSID || newPassword != lastWiFiPassword)) {
          Serial.println("WiFi settings updated from server!");
          saveWiFiSettings(newSSID, newPassword);
          lastWiFiSSID = newSSID;
          lastWiFiPassword = newPassword;
          
          // Reconnect with new WiFi settings
          Serial.println("Reconnecting with new WiFi settings...");
          connectWiFi();
        } else {
          Serial.println("No WiFi settings changes detected from server");
        }
      } else {
        Serial.println("Server returned error: " + doc["message"].as<String>());
      }
    } else {
      Serial.println("Failed to parse WiFi settings JSON response");
    }
  } else {
    Serial.println("Error fetching WiFi settings. HTTP Code: " + String(httpResponseCode));
  }
  
  http.end();
}

void connectWiFi() {
  if (!wifiCredentialsAvailable) {
    Serial.println("No WiFi credentials available");
    return;
  }
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(wifiSSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

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
    wifiConnected = true;
  } else {
    Serial.println("Failed to connect WiFi.");
    wifiConnected = false;
  }
}

void checkWiFiConnection() {
  // Don't check WiFi if in AP mode
  if (apMode) {
    return;
  }
  
  // Only try to reconnect if we have credentials
  if (!wifiCredentialsAvailable) {
    return;
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    Serial.println("WiFi disconnected. Reconnecting...");
    showWiFiStatus("DISCONNECTED");
    
    connectWiFi();
    
    if (WiFi.status() == WL_CONNECTED) {
      wifiConnected = true;
      showWiFiStatus("CONNECTED");
      setupTime();
      checkAndUpdateSettings();
      checkAndUpdateWiFiSettings();
      delay(1000);
    } else {
      showWiFiStatus("FAILED");
      delay(1000);
    }
  } else {
    wifiConnected = true;
  }
}

// =======================
// AP Mode Functions
// =======================
void setupAPMode() {
  apMode = true;
  apModeStartTime = millis();
  
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  
  Serial.println("AP Mode Started");
  Serial.print("AP IP Address: ");
  Serial.println(WiFi.softAPIP());
  
  // Setup DNS server to redirect all requests to the web server
  dnsServer.start(DNS_PORT, "*", WiFi.softAPIP());
  
  // Setup web server routes
  server.on("/", handleRoot);
  server.on("/scan", handleScanWiFi);
  server.on("/connect", HTTP_POST, handleConnectWiFi);
  server.onNotFound(handleRoot);
  
  server.begin();
  Serial.println("Web server started");
  
  // Show AP mode on OLED
  showAPModeStatus();
}

void handleRoot() {
  String html = R"rawliteral(
                  <!DOCTYPE html>
                  <html>
                  <head>
                      <meta charset="UTF-8">
                      <meta name="viewport" content="width=device-width, initial-scale=1.0">
                      <title>Refrigerator WiFi Setup</title>
                      <style>
                          body { font-family: Arial; margin: 0; padding: 20px; background: #f0f0f0; }
                          .container { max-width: 500px; margin: auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                          h1 { text-align: center; color: #333; }
                          .scan-header { display: flex; justify-content: space-between; align-items: center; margin: 15px 0 10px 0; }
                          .scan-header h2 { margin: 0; font-size: 18px; color: #555; }
                          .refresh-btn { 
                              background: #28a745; 
                              color: white; 
                              border: none; 
                              padding: 8px 15px; 
                              border-radius: 5px; 
                              cursor: pointer; 
                              font-size: 14px;
                              display: flex;
                              align-items: center;
                              gap: 5px;
                          }
                          .refresh-btn:hover { background: #218838; }
                          .refresh-btn:disabled { opacity: 0.6; cursor: not-allowed; }
                          .wifi-list { margin: 10px 0; max-height: 300px; overflow-y: auto; }
                          .wifi-item { 
                              padding: 12px; 
                              margin: 5px 0; 
                              background: #f8f8f8; 
                              border-radius: 5px; 
                              cursor: pointer; 
                              border: 1px solid #ddd; 
                              transition: all 0.2s;
                          }
                          .wifi-item:hover { background: #e8e8e8; }
                          .wifi-item.selected { background: #d4edda; border-color: #28a745; }
                          .wifi-item .wifi-info { display: flex; justify-content: space-between; align-items: center; }
                          .wifi-item .wifi-name { font-weight: bold; }
                          .wifi-item .wifi-lock { font-size: 14px; color: #666; }
                          .password-input { display: none; margin: 10px 0; }
                          .password-input input { 
                              width: 100%; 
                              padding: 10px; 
                              border: 1px solid #ddd; 
                              border-radius: 5px; 
                              font-size: 16px;
                              box-sizing: border-box;
                          }
                          .password-input .hint { font-size: 12px; color: #666; margin-top: 5px; }
                          .connect-btn { 
                              width: 100%; 
                              padding: 12px; 
                              background: #007bff; 
                              color: white; 
                              border: none; 
                              border-radius: 5px; 
                              font-size: 16px; 
                              cursor: pointer; 
                              margin-top: 10px; 
                              transition: all 0.3s;
                          }
                          .connect-btn:hover { background: #0056b3; }
                          .connect-btn:disabled { opacity: 0.6; cursor: not-allowed; }
                          .connect-btn.connecting { background: #ffc107; }
                          .connect-btn.success { background: #28a745; }
                          .connect-btn.error { background: #dc3545; }
                          .loading { text-align: center; padding: 20px; }
                          .spinner { 
                              border: 4px solid #f3f3f3; 
                              border-top: 4px solid #3498db; 
                              border-radius: 50%; 
                              width: 30px; 
                              height: 30px; 
                              animation: spin 2s linear infinite; 
                              margin: auto; 
                          }
                          @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
                          .message { padding: 10px; margin: 10px 0; border-radius: 5px; display: none; }
                          .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
                          .error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
                          .info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
                          .device-info { background: #e8f4fd; padding: 10px; border-radius: 5px; margin-bottom: 15px; font-size: 14px; }
                          .device-info span { font-weight: bold; }
                          .no-wifi { text-align: center; padding: 20px; color: #666; }
                          .scan-time { font-size: 12px; color: #999; text-align: center; margin-top: 5px; }
                          .status-box {
                              display: none;
                              padding: 20px;
                              text-align: center;
                              border-radius: 10px;
                              margin: 15px 0;
                          }
                          .status-box.visible { display: block; }
                          .status-box .icon { font-size: 48px; display: block; margin-bottom: 10px; }
                          .status-box .title { font-size: 20px; font-weight: bold; margin-bottom: 5px; }
                          .status-box .subtitle { font-size: 14px; color: #666; }
                          .status-box.connecting { background: #fff3cd; border: 1px solid #ffc107; }
                          .status-box.success { background: #d4edda; border: 1px solid #28a745; }
                          .status-box.error { background: #f8d7da; border: 1px solid #dc3545; }
                      </style>
                  </head>
                  <body>
                      <div class="container">
                          <h1>📡 WiFi Setup</h1>
                          <div class="device-info">
                              Device ID: <span>SRM01</span>
                          </div>
                          <div id="message" class="message"></div>
                          
                          <!-- Connection Status Box -->
                          <div id="statusBox" class="status-box">
                              <span class="icon" id="statusIcon">⏳</span>
                              <div class="title" id="statusTitle">Connecting...</div>
                              <div class="subtitle" id="statusSubtitle">Please wait</div>
                          </div>
                          
                          <div class="scan-header">
                              <h2>Available Networks</h2>
                              <button class="refresh-btn" onclick="scanWiFi()" id="refreshBtn">
                                  <span>🔄</span> Scan
                              </button>
                          </div>
                          
                          <div class="loading" id="loading">
                              <div class="spinner"></div>
                              <p>Scanning for WiFi networks...</p>
                          </div>
                          
                          <div class="wifi-list" id="wifiList" style="display:none;"></div>
                          
                          <div class="password-input" id="passwordInput">
                              <input type="password" id="password" placeholder="Enter WiFi password (leave empty for open networks)">
                              <div class="hint">💡 Leave password field empty for open (no password) WiFi networks</div>
                              <button class="connect-btn" onclick="connectWiFi()" id="connectBtn">Connect</button>
                          </div>
                          
                          <div class="scan-time" id="scanTime">Last scan: Never</div>
                      </div>
                      <script>
                          let selectedSSID = '';
                          let selectedEncrypted = false;
                          let scanInterval = null;
                          let isScanning = false;
                          let isConnecting = false;
                          let connectionCheckInterval = null;
                          
                          function showMessage(text, type) {
                              const msg = document.getElementById('message');
                              msg.textContent = text;
                              msg.className = 'message ' + type;
                              msg.style.display = 'block';
                              setTimeout(() => {
                                  msg.style.display = 'none';
                              }, 5000);
                          }
                          
                          function updateScanTime() {
                              const now = new Date();
                              const timeString = now.toLocaleTimeString();
                              document.getElementById('scanTime').textContent = 'Last scan: ' + timeString;
                          }
                          
                          function showStatus(icon, title, subtitle, type) {
                              const box = document.getElementById('statusBox');
                              box.className = 'status-box visible ' + type;
                              document.getElementById('statusIcon').textContent = icon;
                              document.getElementById('statusTitle').textContent = title;
                              document.getElementById('statusSubtitle').textContent = subtitle;
                          }
                          
                          function hideStatus() {
                              document.getElementById('statusBox').className = 'status-box';
                          }
                          
                          function scanWiFi() {
                              if (isScanning || isConnecting) return;
                              
                              isScanning = true;
                              const refreshBtn = document.getElementById('refreshBtn');
                              refreshBtn.disabled = true;
                              refreshBtn.innerHTML = '<span>⏳</span> Scanning...';
                              
                              document.getElementById('loading').style.display = 'block';
                              document.getElementById('wifiList').style.display = 'none';
                              document.getElementById('passwordInput').style.display = 'none';
                              hideStatus();
                              
                              fetch('/scan')
                                  .then(response => response.json())
                                  .then(data => {
                                      document.getElementById('loading').style.display = 'none';
                                      const list = document.getElementById('wifiList');
                                      list.style.display = 'block';
                                      list.innerHTML = '';
                                      
                                      if (data.networks.length === 0) {
                                          list.innerHTML = '<div class="no-wifi">🔍 No WiFi networks found. Make sure WiFi is enabled and try again.</div>';
                                      } else {
                                          data.networks.forEach(network => {
                                              const div = document.createElement('div');
                                              div.className = 'wifi-item';
                                              
                                              let signalBars = '📶';
                                              if (network.rssi > -50) signalBars = '📶';
                                              else if (network.rssi > -70) signalBars = '📶';
                                              else if (network.rssi > -80) signalBars = '📶';
                                              else signalBars = '📶';
                                              
                                              const lockIcon = network.encrypted ? '🔒' : '🔓';
                                              const securityText = network.encrypted ? 'Secured' : 'Open';
                                              
                                              div.innerHTML = '<div class="wifi-info">' +
                                                  '<span class="wifi-name">' + signalBars + ' ' + network.ssid + '</span>' +
                                                  '<span class="wifi-lock">' + lockIcon + ' ' + securityText + '</span>' +
                                                  '</div>';
                                              
                                              div.onclick = function() {
                                                  if (isConnecting) return;
                                                  document.querySelectorAll('.wifi-item').forEach(item => item.classList.remove('selected'));
                                                  this.classList.add('selected');
                                                  selectedSSID = network.ssid;
                                                  selectedEncrypted = network.encrypted;
                                                  const passwordInput = document.getElementById('passwordInput');
                                                  passwordInput.style.display = 'block';
                                                  const passwordField = document.getElementById('password');
                                                  passwordField.value = '';
                                                  if (!selectedEncrypted) {
                                                      passwordField.style.opacity = '0.6';
                                                      passwordField.placeholder = 'No password required for this network';
                                                  } else {
                                                      passwordField.style.opacity = '1';
                                                      passwordField.placeholder = 'Enter WiFi password';
                                                  }
                                                  passwordField.focus();
                                              };
                                              list.appendChild(div);
                                          });
                                      }
                                      
                                      updateScanTime();
                                      isScanning = false;
                                      refreshBtn.disabled = false;
                                      refreshBtn.innerHTML = '<span>🔄</span> Scan';
                                      
                                      if (!scanInterval) {
                                          scanInterval = setInterval(() => {
                                              if (!isConnecting) {
                                                  scanWiFi();
                                              }
                                          }, 30000);
                                      }
                                  })
                                  .catch(error => {
                                      console.error('Scan error:', error);
                                      document.getElementById('loading').style.display = 'none';
                                      document.getElementById('wifiList').style.display = 'block';
                                      document.getElementById('wifiList').innerHTML = '<div class="no-wifi">❌ Error scanning WiFi networks. Please try again.</div>';
                                      showMessage('Error scanning WiFi networks', 'error');
                                      isScanning = false;
                                      refreshBtn.disabled = false;
                                      refreshBtn.innerHTML = '<span>🔄</span> Scan';
                                  });
                          }
                          
                          function connectWiFi() {
                            if (isConnecting) return;
                            
                            const password = document.getElementById('password').value;
                            if (!selectedSSID) {
                                showMessage('Please select a WiFi network first', 'error');
                                return;
                            }
                            
                            if (selectedEncrypted && password.length === 0) {
                                showMessage('Please enter the WiFi password', 'error');
                                return;
                            }
                            
                            isConnecting = true;
                            const connectBtn = document.getElementById('connectBtn');
                            connectBtn.disabled = true;
                            connectBtn.className = 'connect-btn connecting';
                            connectBtn.textContent = '⏳ Connecting...';
                            
                            if (scanInterval) {
                                clearInterval(scanInterval);
                                scanInterval = null;
                            }
                            
                            showStatus('⏳', 'Connecting...', 'Check OLED display for status', 'connecting');
                            
                            document.querySelectorAll('.wifi-item').forEach(item => {
                                item.style.cursor = 'not-allowed';
                                item.style.opacity = '0.6';
                            });
                            
                            const formData = new FormData();
                            formData.append('ssid', selectedSSID);
                            formData.append('password', password);
                            
                            fetch('/connect', {
                                method: 'POST',
                                body: formData
                            })
                            .then(() => {
                                // Just show waiting message, OLED shows the real status
                                showStatus('⏳', 'Connection in Progress', 'Please check the OLED display', 'connecting');
                                connectBtn.textContent = '⏳ Waiting...';
                                
                                // Reload after 15 seconds to check if device restarted
                                setTimeout(() => {
                                    window.location.reload();
                                }, 15000);
                            })
                            .catch(() => {
                                // If fetch fails, device might be restarting
                                showStatus('⏳', 'Processing...', 'Check OLED display', 'connecting');
                                setTimeout(() => {
                                    window.location.reload();
                                }, 15000);
                            });
                        }
                          
                          // Start scanning on page load
                          document.addEventListener('DOMContentLoaded', function() {
                              scanWiFi();
                          });
                          
                          // Clean up intervals when page is closed
                          window.addEventListener('beforeunload', function() {
                              if (scanInterval) {
                                  clearInterval(scanInterval);
                                  scanInterval = null;
                              }
                              if (connectionCheckInterval) {
                                  clearInterval(connectionCheckInterval);
                                  connectionCheckInterval = null;
                              }
                          });
                      </script>
                  </body>
              </html>
            )rawliteral";
  server.send(200, "text/html", html);
}

void handleScanWiFi() {
  Serial.println("Scanning WiFi networks...");
  
  // Set a timeout for the scan
  WiFi.scanDelete(); // Clear previous scan results
  int n = WiFi.scanNetworks();
  
  if (n == WIFI_SCAN_FAILED) {
    Serial.println("WiFi scan failed!");
    String response = "{\"networks\":[]}";
    server.send(200, "application/json", response);
    return;
  }
  
  String json = "{\"networks\":[";
  
  for (int i = 0; i < n; ++i) {
    String ssid = WiFi.SSID(i);
    // Filter out hidden networks (empty SSID)
    if (ssid.length() > 0) {
      if (i > 0 && json.length() > 1) json += ",";
      
      json += "{";
      json += "\"ssid\":\"" + ssid + "\",";
      json += "\"rssi\":" + String(WiFi.RSSI(i)) + ",";
      json += "\"encrypted\":" + String(WiFi.encryptionType(i) != WIFI_AUTH_OPEN);
      json += "}";
    }
  }
  
  json += "]}";

  WiFi.scanDelete();
  server.send(200, "application/json", json);
}

void handleConnectWiFi() {
  if (server.hasArg("ssid")) {
    String ssid = server.arg("ssid");
    String password = server.arg("password");
    
    Serial.println("Received connection request:");
    Serial.print("SSID: ");
    Serial.println(ssid);
    Serial.print("Password: ");
    Serial.println(password.length() > 0 ? "****" : "(empty)");
    
    // Save WiFi credentials
    saveWiFiSettings(ssid, password);
    
    // Send simple response
    server.send(200, "text/plain", "OK");
    server.client().flush();
    
    // Show connecting on OLED
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 10);
    display.println("CONNECTING TO");
    display.setCursor(0, 25);
    display.println(ssid);
    display.setCursor(0, 40);
    display.println("Please wait...");
    display.display();
    
    // Try to connect
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), password.c_str());
    
    int attempts = 0;
    bool connected = false;
    
    while (attempts < 30) {
      if (WiFi.status() == WL_CONNECTED) {
        connected = true;
        break;
      }
      delay(300);
      attempts++;
    }
    
    if (connected) {
      Serial.println("WiFi connected!");
      Serial.print("IP: ");
      Serial.println(WiFi.localIP());
      
      wifiConnected = true;
      wifiCredentialsAvailable = true;
      apMode = false;
      
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 10);
      display.println("CONNECTED!");
      display.setCursor(0, 25);
      display.print("IP: ");
      display.println(WiFi.localIP());
      display.setCursor(0, 40);
      display.println("Restarting...");
      display.display();
      
      delay(2000);
      ESP.restart();
      
    } else {
      Serial.println("Connection failed");
      
      preferences.remove("wifi_ssid");
      preferences.remove("wifi_password");
      wifiCredentialsAvailable = false;
      wifiSSID = "";
      wifiPassword = "";
      
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 10);
      display.println("CONNECTION FAILED");
      display.setCursor(0, 25);
      display.println("Please try again");
      display.setCursor(0, 40);
      display.println("Check password");
      display.display();
      
      delay(2000);
      showAPModeStatus();
    }
  } else {
    server.send(400, "text/plain", "Missing SSID");
  }
}

// =======================
// Settings Management Functions
// =======================
void getSettingsFromPreferences() {
  temperatureThreshold = preferences.getFloat("temp_threshold", 10.0);
  humidityThresholdHigh = preferences.getFloat("humidity_high", 85.0);
  humidityThresholdLow = preferences.getFloat("humidity_low", 50.0);
  gasThresholdNormal = preferences.getInt("gas_normal", 150);
  gasThresholdWarning = preferences.getInt("gas_warning", 300);
  uploadInterval = preferences.getInt("upload_interval", 5);
  buzzerEnabled = preferences.getBool("buzzer_enabled", true);
  
  settingsLoadedFromPreferences = true;
  applySettings();
  Serial.println("Settings loaded from preferences");
}

void saveSettingsToPreferences() {
  preferences.putFloat("temp_threshold", temperatureThreshold);
  preferences.putFloat("humidity_high", humidityThresholdHigh);
  preferences.putFloat("humidity_low", humidityThresholdLow);
  preferences.putInt("gas_normal", gasThresholdNormal);
  preferences.putInt("gas_warning", gasThresholdWarning);
  preferences.putInt("upload_interval", uploadInterval);
  preferences.putBool("buzzer_enabled", buzzerEnabled);
  
  Serial.println("Settings saved to preferences");
}

void checkAndUpdateSettings() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Using stored settings.");
    return;
  }
  
  // Get settings from server
  String serverURL = "http://canorcannot.com/Bakkien/SRM/api/getSettings.php?device_id=" + deviceID;
  
  HTTPClient http;
  http.begin(serverURL);
  http.setTimeout(10000); // 10 second timeout
  
  Serial.println("Checking for settings updates from server...");
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Settings response received");
    
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      String status = doc["status"];
      if (status == "success") {
        JsonObject data = doc["data"];
        
        // Read new settings
        float newTempThreshold = data["temperature_threshold"] | 10.0;
        float newHumidityHigh = data["humidity_threshold_high"] | 85.0;
        float newHumidityLow = data["humidity_threshold_low"] | 50.0;
        int newGasNormal = data["gas_threshold_normal"] | 150;
        int newGasWarning = data["gas_threshold_warning"] | 300;
        int newUploadInterval = data["upload_interval"] | 5;
        bool newBuzzerEnabled = data["buzzer_enabled"].as<bool>();
        
        // Check if settings have changed
        bool settingsChanged = false;
        
        if (temperatureThreshold != newTempThreshold) {
          temperatureThreshold = newTempThreshold;
          settingsChanged = true;
        }
        if (humidityThresholdHigh != newHumidityHigh) {
          humidityThresholdHigh = newHumidityHigh;
          settingsChanged = true;
        }
        if (humidityThresholdLow != newHumidityLow) {
          humidityThresholdLow = newHumidityLow;
          settingsChanged = true;
        }
        if (gasThresholdNormal != newGasNormal) {
          gasThresholdNormal = newGasNormal;
          settingsChanged = true;
        }
        if (gasThresholdWarning != newGasWarning) {
          gasThresholdWarning = newGasWarning;
          settingsChanged = true;
        }
        if (uploadInterval != newUploadInterval) {
          uploadInterval = newUploadInterval;
          settingsChanged = true;
        }
        if (buzzerEnabled != newBuzzerEnabled) {
          buzzerEnabled = newBuzzerEnabled;
          settingsChanged = true;
        }
        
        if (settingsChanged) {
          saveSettingsToPreferences();
          applySettings();
          Serial.println("Settings updated from server and saved to preferences");
        } else {
          Serial.println("No settings changes detected");
        }
      } else {
        Serial.println("Server returned error: " + doc["message"].as<String>());
        Serial.println("Using stored settings from preferences");
      }
    } else {
      Serial.println("Failed to parse JSON response. Using stored settings.");
    }
  } else {
    Serial.println("Error getting settings. HTTP Code: " + String(httpResponseCode));
    Serial.println("Using stored settings from preferences");
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
        // Save to preferences as well
        preferences.putBool("buzzer_enabled", buzzerEnabled);
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

String getGasStatus(int gasValue) {
  if (gasValue < gasThresholdNormal) return "NORMAL";
  if (gasValue < gasThresholdWarning) return "SPOILAGE";
  return "LEAK";
}

String getDoorStatus(float distance) {
  if (distance < 0) return "ERROR";
  if (distance > DOOR_OPEN_THRESHOLD) return "OPEN";
  return "CLOSED";
}

String getSystemStatus() {
  if (getGasStatus(latestGas) == "LEAK" || getDoorStatus(latestDistance) == "OPEN") {
    return "CRITICAL";
  } else if (getGasStatus(latestGas) == "SPOILAGE" || 
             latestTemperature > temperatureThreshold ||
             latestHumidity > humidityThresholdHigh ||
             latestHumidity < humidityThresholdLow) {
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
  return getSystemStatus() != "NORMAL";
}

int getBeepInterval() {
  if (getSystemStatus() == "CRITICAL") return 200;
  if (getSystemStatus() == "WARNING") return 400;
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
  static unsigned long pressStartTime = 0;
  static bool buttonIsPressed = false;
  
  bool buttonState = digitalRead(BOOT_BUTTON_PIN);
  unsigned long currentMillis = millis();
  
  // Button pressed (LOW because of pull-up)
  if (buttonState == LOW && lastButtonState == HIGH) {
    // Button just pressed
    pressStartTime = currentMillis;
    buttonIsPressed = true;
    Serial.println("Button pressed - hold for 3 seconds to reset settings");
  }
  
  // Button released
  if (buttonState == HIGH && lastButtonState == LOW) {
    if (buttonIsPressed) {
      unsigned long pressDuration = currentMillis - pressStartTime;
      
      if (pressDuration >= LONG_PRESS_TIME) {
        // Long press - clear all preferences
        Serial.println();
        Serial.println("========== LONG PRESS DETECTED ==========");
        Serial.println("Clearing all preferences...");
        
        // Clear all preferences
        preferences.clear();
        
        // Reset WiFi credentials
        wifiSSID = "";
        wifiPassword = "";
        wifiCredentialsAvailable = false;
        
        // Reset to default settings
        temperatureThreshold = 10.0;
        humidityThresholdHigh = 85.0;
        humidityThresholdLow = 50.0;
        gasThresholdNormal = 150;
        gasThresholdWarning = 300;
        uploadInterval = 5;
        buzzerEnabled = true;
        
        Serial.println("All preferences cleared!");
        Serial.println("Device will restart in 2 seconds...");
        Serial.println("==========================================");
        
        // Show message on OLED
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 10);
        display.println("SETTINGS RESET");
        display.setCursor(0, 25);
        display.println("Restarting...");
        display.display();
        
        delay(2000);
        ESP.restart();
        
      } else if (pressDuration >= 50 && pressDuration < LONG_PRESS_TIME) {
        // Short press - toggle buzzer
        if (currentMillis - lastButtonPress > 300) {
          buzzerEnabled = !buzzerEnabled;
          lastButtonPress = currentMillis;
          
          // Save to preferences immediately
          preferences.putBool("buzzer_enabled", buzzerEnabled);
          
          Serial.println();
          Serial.println("========== BUZZER CONTROL ==========");
          Serial.println(buzzerEnabled ? "BUZZER: ENABLED" : "BUZZER: DISABLED");
          digitalWrite(BUZZER_PIN, LOW);
          Serial.println("====================================");

          // Update server asynchronously
          if (WiFi.status() == WL_CONNECTED) {
            updateBuzzerSettingToServer(buzzerEnabled);
          } else {
            Serial.println("WiFi not connected. Buzzer setting will be updated when WiFi reconnects.");
          }
        }
      }
    }
    buttonIsPressed = false;
  }
  
  // Check for long press while button is being held
  if (buttonIsPressed && buttonState == LOW) {
    unsigned long pressDuration = currentMillis - pressStartTime;
    
    // Show progress on OLED when holding for long press
    if (pressDuration >= LONG_PRESS_TIME - 1000 && pressDuration < LONG_PRESS_TIME) {
      // Show countdown on OLED
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 10);
      display.println("HOLD TO RESET");
      display.setCursor(0, 25);
      display.print("Resetting in ");
      display.print((LONG_PRESS_TIME - pressDuration) / 1000 + 1);
      display.println("s");
      display.display();
    }
    
    // If long press threshold reached, trigger reset
    if (pressDuration >= LONG_PRESS_TIME) {
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 10);
      display.println("RESETTING...");
      display.display();
    }
  }
  
  lastButtonState = buttonState;
}

// =======================
// OLED Display Function
// =======================
void showAPModeStatus() {
  display.clearDisplay();
  display.drawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Title
  display.setCursor(2, 2);
  display.println("=== AP MODE ===");
  display.drawLine(0, 12, 128, 12, SSD1306_WHITE);
  
  // IP Address
  display.setCursor(2, 18);
  display.print("IP: ");
  display.println(WiFi.softAPIP());
  
  // SSID
  display.setCursor(2, 30);
  display.print("SSID: ");
  display.println(AP_SSID);
  
  // Password
  display.setCursor(2, 42);
  display.print("PWD: ");
  display.println(AP_PASSWORD);
  
  // Instruction
  display.setCursor(2, 54);
  display.println("Connect & Configure");
  
  display.display();
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
  display.println(wifiSSID);
  
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

void updateOLEDDisplay() {
  if (apMode) {
    return;
  }
  
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

// =======================
// Utility Functions
// =======================
void printStatus() {
  Serial.println();
  Serial.println("========== REFRIGERATOR STATUS ==========");
  Serial.print("Device ID: ");
  Serial.println(deviceID);

  Serial.print("Temperature: ");
  Serial.print(latestTemperature);
  Serial.println(" °C");

  Serial.print("Humidity: ");
  Serial.print(latestHumidity);
  Serial.print(" % ");

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
}