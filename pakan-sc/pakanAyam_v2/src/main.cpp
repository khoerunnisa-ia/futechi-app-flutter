#include <Arduino.h>
#include <Wire.h>
#include "RTClib.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <TFT_eSPI.h>
#include <time.h>
#include <I2CKeyPad.h>
#include <WiFiManager.h>

const char *ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7 * 3600; // WIB
const int daylightOffset_sec = 0;
/// ================= EEPROM =================
#define EEPROM_SIZE 4096
#define EEPROM_ADDR 0
#define EEPROM_ADDR_TIMER 3000
#define EEPROM_ADDR_MODE 3010
#define EEPROM_ADDR_RUNMODE 3020
/// ================= PIN =================
#define BUZZER_PIN 17
#define BUTTON_1_PIN 13
#define BUTTON_2_PIN 14

#define LIMIT_1_PIN 35
#define LIMIT_2_PIN 34
#define LIMIT_3_PIN 39
#define LIMIT_4_PIN 36

#define RELAY_1_PIN 32
#define RELAY_2_PIN 33
#define RELAY_3_PIN 25
#define RELAY_4_PIN 26
#define RELAY_5_PIN 27

#define USER_SETUP_LOADED

#define I2C_ADDR 0x27
I2CKeyPad keypad(I2C_ADDR);
char keymap[16] = {
    '1', '2', '3', 'A',
    '4', '5', '6', 'B',
    '7', '8', '9', 'C',
    '*', '0', '#', 'D'};

/// ================= WIFI =================
const char *ssid = "Robotika";
const char *password = "12345678";

/// ================= MQTT =================
const char *mqtt_server = "mqtt.stiatech.my.id";
const char *mqtt_user = "mqttuser";
const char *mqtt_pass = "Robotika";

bool hotspotMode = false;
bool wifiConnected = false;
bool mqttConnected = false;
bool scheduleChanged = false;
bool inputMode = false;
bool needRedrawMenu = false;
bool rtcSynced = false;
unsigned long lastNtpSync = 0;

bool motor1_dirActive = false;
bool motor1_running = false;
bool motor1_dir = true; // true = kanan, false = kiri
bool lastButton1 = HIGH;
unsigned long motor1_startTime = 0;
unsigned long motor1_stopTime = 0;

bool motor2_running = false;
bool motor2_dir = true;

unsigned long conveyor_startTime = 0;
bool conveyor_running = false;

const unsigned long LIMIT_IGNORE_TIME = 1000; // ms
unsigned long motor2_startTime = 0;
unsigned long motor2_stopTime = 0;
bool motor2_dirActive = false;

bool system_running = false;

bool lastButtonStart = HIGH;
bool lastButtonStop = HIGH;

String systemStatus = "READY";
String lastPublishedStatus = "";

uint8_t runMode = 1; // default: mode 2 (dua motor)

int conveyorTime = 5; // default 5 detik
String inputTimer = "";

String inputTime = "";

String client2_status = "-";

WiFiClient espClient;
PubSubClient client(espClient);

/// ================= RTC =================
RTC_DS3231 rtc;
/// ================= LCD =================
TFT_eSPI tft = TFT_eSPI();

// ================= MENU =================
enum MenuState
{
  MENU_NONE,
  MENU_MAIN,
  MENU_ADD_TIME,
  MENU_ADD_DAY,
  MENU_DELETE,
  MENU_TIMER,
  MENU_MODE_HOTSPOT,
  MENU_MODE_MOTOR
};

MenuState menuState = MENU_NONE;

int menuIndex = 0;
int selectedDay = 0;

bool menuActive = false;
bool daySelected[7] = {false, false, false, false, false, false, false};

char daysOfTheWeek[7][12] = {
    "Minggu", "Senin", "Selasa", "Rabu",
    "Kamis", "Jumat", "Sabtu"};

// RTC

/// ================= JADWAL =================
#define MAX_SCHEDULE 10

void syncRTCFromNTP()
{
  Serial.println("Sync RTC dari NTP...");

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  struct tm timeinfo;

  if (!getLocalTime(&timeinfo, 5000)) // timeout 5 detik
  {
    Serial.println("Gagal ambil waktu NTP");
    return;
  }

  rtc.adjust(DateTime(
      timeinfo.tm_year + 1900,
      timeinfo.tm_mon + 1,
      timeinfo.tm_mday,
      timeinfo.tm_hour,
      timeinfo.tm_min,
      timeinfo.tm_sec));

  Serial.println("RTC berhasil diupdate dari NTP");

  rtcSynced = true;
  lastNtpSync = millis();
}

struct Schedule
{
  String days[7];
  int dayCount;
  String time;
};

struct NextSchedule
{
  String day;
  String time;
  int diff;
};

Schedule schedules[MAX_SCHEDULE];
int scheduleCount = 0;

String lastTrigger = "";

bool feeding = false;
char key;

/// ================= Save to EEPROM =================
void saveModeToEEPROM()
{
  EEPROM.write(EEPROM_ADDR_MODE, hotspotMode);
  EEPROM.commit();
}
void loadModeFromEEPROM()
{
  hotspotMode = EEPROM.read(EEPROM_ADDR_MODE) == 1;
}
void saveTimerToEEPROM()
{
  EEPROM.write(EEPROM_ADDR_TIMER, conveyorTime);
  EEPROM.commit();

  Serial.print("SAVE TIMER: ");
  Serial.println(conveyorTime);
}

void loadTimerFromEEPROM()
{
  int val = EEPROM.read(EEPROM_ADDR_TIMER);

  if (val > 0 && val <= 120)
  {
    conveyorTime = val;
  }
  else
  {
    conveyorTime = 5; // default
  }

  Serial.print("LOAD TIMER: ");
  Serial.println(conveyorTime);
}

void saveRunMode()
{
  EEPROM.write(EEPROM_ADDR_RUNMODE, runMode);
  EEPROM.commit();

  Serial.print("SAVE RUN MODE: ");
  Serial.println(runMode);
}

void loadRunMode()
{
  uint8_t val = EEPROM.read(EEPROM_ADDR_RUNMODE);

  if (val == 1 || val == 2)
    runMode = val;
  else
    runMode = 2;

  Serial.print("LOAD RUN MODE: ");
  Serial.println(runMode);
}

void saveScheduleToEEPROM()
{
  // StaticJsonDocument<2048> doc;
  JsonDocument doc;
  JsonArray arr = doc.to<JsonArray>();

  for (int i = 0; i < scheduleCount; i++)
  {
    JsonObject obj = arr.createNestedObject();
    obj["on"] = schedules[i].time;

    JsonArray daysArr = obj.createNestedArray("days");

    for (int j = 0; j < schedules[i].dayCount; j++)
    {
      daysArr.add(schedules[i].days[j]);
    }
  }

  String json;
  serializeJson(doc, json);

  Serial.println("SAVE EEPROM:");
  Serial.println(json);

  for (int i = 0; i < json.length(); i++)
  {
    EEPROM.write(EEPROM_ADDR + i, json[i]);
  }

  EEPROM.write(EEPROM_ADDR + json.length(), '\0'); // penutup string
  EEPROM.commit();
}

NextSchedule getNextSchedule()
{
  NextSchedule result;
  result.day = "-";
  result.time = "-";
  result.diff = -1;

  DateTime now = rtc.now();

  int nowMinutes = now.hour() * 60 + now.minute();
  int today = now.dayOfTheWeek();

  int bestDiff = 999999;

  for (int i = 0; i < scheduleCount; i++)
  {
    if (schedules[i].time.length() < 5)
      continue;

    int hour = schedules[i].time.substring(0, 2).toInt();
    int minute = schedules[i].time.substring(3, 5).toInt();
    int schedMinutes = hour * 60 + minute;

    for (int j = 0; j < schedules[i].dayCount; j++)
    {
      String dayStr = schedules[i].days[j];

      int schedDay = -1;
      for (int d = 0; d < 7; d++)
      {
        if (dayStr == daysOfTheWeek[d])
        {
          schedDay = d;
          break;
        }
      }

      if (schedDay == -1)
        continue;

      int totalDiff;

      if (schedDay == today)
      {
        if (schedMinutes > nowMinutes)
          totalDiff = schedMinutes - nowMinutes;
        else
          totalDiff = (7 * 1440) - (nowMinutes - schedMinutes);
      }
      else
      {
        int dayDiff = schedDay - today;
        if (dayDiff < 0)
          dayDiff += 7;

        totalDiff = dayDiff * 1440 + (schedMinutes - nowMinutes);
      }

      if (totalDiff < bestDiff)
      {
        bestDiff = totalDiff;
        result.time = schedules[i].time;
        result.day = daysOfTheWeek[schedDay];
        result.diff = totalDiff;
      }
    }
  }

  return result;
}

int getTodaySchedules(String result[], int maxResult)
{
  DateTime now = rtc.now();
  String today = daysOfTheWeek[now.dayOfTheWeek()];

  int count = 0;

  for (int i = 0; i < scheduleCount; i++)
  {
    for (int j = 0; j < schedules[i].dayCount; j++)
    {
      if (schedules[i].days[j] == today)
      {
        if (count < maxResult)
        {
          result[count++] = schedules[i].time;
        }
        break;
      }
    }
  }

  return count;
}

void loadScheduleFromEEPROM()
{
  String json = "";

  for (int i = 0; i < EEPROM_SIZE; i++)
  {
    char c = EEPROM.read(EEPROM_ADDR + i);
    if (c == '\0')
      break;
    json += c;
  }

  if (json.length() == 0)
  {
    Serial.println("EEPROM kosong");
    return;
  }

  Serial.println("LOAD EEPROM:");
  Serial.println(json);

  StaticJsonDocument<2048> doc;

  if (deserializeJson(doc, json))
  {
    Serial.println("Gagal parse EEPROM");
    return;
  }

  scheduleCount = 0;

  JsonArray arr = doc.as<JsonArray>();

  for (JsonObject obj : arr)
  {
    if (scheduleCount >= MAX_SCHEDULE)
      break;

    schedules[scheduleCount].time = obj["on"] | "";
    schedules[scheduleCount].dayCount = 0;

    if (obj["days"].is<JsonArray>())
    {
      for (JsonVariant d : obj["days"].as<JsonArray>())
      {
        schedules[scheduleCount].days[schedules[scheduleCount].dayCount++] = d.as<String>();
      }
    }

    scheduleCount++;
  }

  Serial.print("Jadwal dari EEPROM: ");
  Serial.println(scheduleCount);
}

bool waitHotspotDecision()
{
  unsigned long start = millis();

  while (millis() - start < 10000) // ⏱ 30 detik
  {
    uint8_t index = keypad.getKey();

    if (index < 16)
    {
      char key = keymap[index];

      if (key == '*')
      {
        Serial.println("HOTSPOT MODE CANCELLED");

        hotspotMode = false;
        saveModeToEEPROM();

        tft.fillScreen(TFT_BLACK);
        tft.setTextColor(TFT_RED, TFT_BLACK);
        tft.drawCentreString("HOTSPOT BATAL", 160, 100, 2);
        tft.drawCentreString("  WAIT...", 160, 120, 2);
        delay(1000);
        return false; // batal
      }
    }

    // tft.fillScreen(TFT_BLACK);
    delay(50);
  }

  return true; // lanjut hotspot
}

// ==========  Setup Wifi Manager =============

void setup_wifi()
{
  WiFiManager wm;

  if (hotspotMode)
  {
    Serial.println("MODE HOTSPOT AKTIF");
    wm.resetSettings(); // 🔥 hapus wifi lama

    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_YELLOW);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.drawCentreString("HOTSPOT MODE", 160, 100, 4);

    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.drawCentreString("Starting...", 160, 140, 2);

    wm.autoConnect("FEEDER_AP");

    hotspotMode = false; // 🔥 reset setelah dipakai
    saveModeToEEPROM();  // simpan

    ESP.restart(); // restart biar balik normal
  }
  else
  {
    WiFi.begin();

    Serial.println("Connecting WiFi...");
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.drawCentreString("LOADING...!", 160, 100, 4);

    unsigned long start = millis();

    while (WiFi.status() != WL_CONNECTED)
    {
      delay(500);
      Serial.print(".");

      if (millis() - start > 10000)
      {
        Serial.println("\nWiFi timeout, lanjut offline");
        return;
      }
    }
    tft.fillScreen(TFT_BLACK);
    Serial.println("\nWiFi Connected");
  }
}

/// ================= Tampilkan jadwal terdekat =================
void printNextSchedule()
{
  DateTime now = rtc.now();

  int nowMinutes = now.hour() * 60 + now.minute();
  int today = now.dayOfTheWeek(); // 0 = Minggu

  int bestDiff = 999999;
  String bestTime = "-";
  String bestDay = "-";

  for (int i = 0; i < scheduleCount; i++)
  {
    // parsing jam "HH:MM"
    if (schedules[i].time.length() < 5)
      continue;

    int hour = schedules[i].time.substring(0, 2).toInt();
    int minute = schedules[i].time.substring(3, 5).toInt();

    int schedMinutes = hour * 60 + minute;

    for (int j = 0; j < schedules[i].dayCount; j++)
    {
      String dayStr = schedules[i].days[j];

      // konversi nama hari ke index
      int schedDay = -1;
      for (int d = 0; d < 7; d++)
      {
        if (dayStr == daysOfTheWeek[d])
        {
          schedDay = d;
          break;
        }
      }

      if (schedDay == -1)
        continue;

      int totalDiff;

      // 🔥 PRIORITAS HARI INI
      if (schedDay == today)
      {
        if (schedMinutes > nowMinutes)
        {
          totalDiff = schedMinutes - nowMinutes;
        }
        else
        {
          totalDiff = (7 * 1440) - (nowMinutes - schedMinutes);
        }
      }
      else
      {
        int dayDiff = schedDay - today;
        if (dayDiff < 0)
          dayDiff += 7;

        totalDiff = dayDiff * 1440 + (schedMinutes - nowMinutes);
      }

      // 🔥 INI YANG SEBELUMNYA HILANG
      if (totalDiff < bestDiff)
      {
        bestDiff = totalDiff;
        bestTime = schedules[i].time;
        bestDay = daysOfTheWeek[schedDay];
      }
    }
  }

  Serial.println("=== NEXT SCHEDULE ===");

  if (bestDiff == 999999)
  {
    Serial.println("Tidak ada jadwal");
  }
  else
  {
    Serial.print("Hari : ");
    Serial.println(bestDay);

    Serial.print("Jam  : ");
    Serial.println(bestTime);

    Serial.print("Dalam: ");
    Serial.print(bestDiff);
    Serial.println(" menit lagi");
  }
}

void updateDashboard()
{
  static String lastTime = "";
  static String lastDay = "";
  static String lastStatus = "";
  static bool lastWifi = false;
  static bool lastMqtt = false;
  int lastModeRun;

  DateTime now = rtc.now();

  char buf[10];
  sprintf(buf, "%02d:%02d:%02d", now.hour(), now.minute(), now.second());

  String timeStr = String(buf);
  String dayStr = daysOfTheWeek[now.dayOfTheWeek()];

  // WIFI
  if (wifiConnected != lastWifi)
  {
    tft.fillRect(50, 40, 60, 20, TFT_BLACK);
    tft.setTextColor(wifiConnected ? TFT_GREEN : TFT_RED);
    tft.drawString(wifiConnected ? "OK" : "OFF", 70, 40, 2);
    lastWifi = wifiConnected;
  }

  // MQTT
  if (mqttConnected != lastMqtt)
  {
    tft.fillRect(50, 65, 60, 20, TFT_BLACK);
    tft.setTextColor(mqttConnected ? TFT_GREEN : TFT_RED);
    tft.drawString(mqttConnected ? "OK" : "OFF", 70, 65, 2);
    lastMqtt = mqttConnected;
  }

  // STATUS
  // if (client2_status != lastStatus)
  // {
  //   tft.fillRect(70, 90, 100, 20, TFT_BLACK);
  //   tft.setTextColor(client2_status == "RUN" ? TFT_GREEN : TFT_RED);
  //   tft.drawString(client2_status, 70, 90, 2);
  //   lastStatus = client2_status;
  // }
  if (systemStatus != lastStatus)
  {
    tft.fillRect(70, 90, 50, 20, TFT_BLACK);

    if (systemStatus == "RUN")
      tft.setTextColor(TFT_GREEN, TFT_BLACK);
    else if (systemStatus == "STOP")
      tft.setTextColor(TFT_RED, TFT_BLACK);
    else // READY
      tft.setTextColor(TFT_WHITE, TFT_BLACK);

    tft.drawString(systemStatus, 70, 90, 2);

    lastStatus = systemStatus;
  }

  // HARI
  if (dayStr != lastDay)
  {
    tft.fillRect(10, 115, 110, 20, TFT_BLACK);
    tft.drawString(dayStr, 10, 115, 2);
    lastDay = dayStr;
  }

  // JAM (update tiap detik)
  if (timeStr != lastTime)
  {
    tft.fillRect(10, 132, 110, 20, TFT_BLACK);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.drawString(timeStr, 10, 132, 4);
    lastTime = timeStr;
  }
  // Run Mode Motor
  if (runMode == 1)
  {
    tft.setTextColor(TFT_WHITE, TFT_BLUE);
    tft.drawString("1 Motor", 260, 5, 2);
  }
  if (runMode == 2)
  {
    tft.setTextColor(TFT_WHITE, TFT_BLUE);
    tft.drawString("2 Motor", 260, 5, 2);
  }
}

String getScheduleSignature()
{
  String s = "";

  for (int i = 0; i < scheduleCount; i++)
  {
    s += schedules[i].time;

    for (int j = 0; j < schedules[i].dayCount; j++)
    {
      s += schedules[i].days[j];
    }
  }

  return s;
}

bool isValidTime(String t)
{
  if (t.length() != 4)
    return false;

  int hour = t.substring(0, 2).toInt();
  int minute = t.substring(2, 4).toInt();

  if (hour < 0 || hour > 23)
    return false;
  if (minute < 0 || minute > 59)
    return false;

  return true;
}

String formatTimeDisplay(String t)
{
  if (t.length() == 0)
    return "";

  if (t.length() <= 2)
    return t; // masih jam

  if (t.length() == 3)
    return t.substring(0, 2) + ":" + t.substring(2);

  if (t.length() >= 4)
    return t.substring(0, 2) + ":" + t.substring(2, 4);

  return t;
}

void updateScheduleUI()
{
  static String lastData = "";
  int x = 130;

  // bikin signature biar tidak redraw terus
  String currentData = "";
  for (int i = 0; i < scheduleCount; i++)
  {
    currentData += schedules[i].time;
  }

  if (currentData == lastData)
    return;

  // clear area
  tft.fillRect(x, 60, 140, 100, TFT_BLACK);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.drawString("Jadwal:", x, 40, 2);

  tft.setTextColor(TFT_WHITE, TFT_BLACK);

  int yStart = 60;
  int rowHeight = 20;

  for (int i = 0; i < 5; i++)
  {
    int leftIndex = i;
    int rightIndex = i + 5;

    String leftText = "--:--";
    String rightText = "--:--";

    if (leftIndex < scheduleCount)
      leftText = schedules[leftIndex].time;

    if (rightIndex < scheduleCount)
      rightText = schedules[rightIndex].time;

    // kiri
    tft.drawString(
        String(leftIndex + 1) + ". " + leftText,
        x,
        yStart + i * rowHeight,
        2);

    // kanan
    tft.drawString(
        String(rightIndex + 1) + ". " + rightText,
        x + 70,
        yStart + i * rowHeight,
        2);
  }

  lastData = currentData;
}
/// ================= WIFI =================
void handleRTCUpdate()
{
  // hanya jalan kalau WiFi ada
  if (WiFi.status() != WL_CONNECTED)
    return;

  // 🔥 kalau belum pernah sync
  if (!rtcSynced)
  {
    syncRTCFromNTP();
    return;
  }

  // 🔥 sync ulang tiap 6 jam (opsional, biar akurat)
  if (millis() - lastNtpSync > 21600000) // 6 jam
  {
    syncRTCFromNTP();
  }
}

/// ================= FEED =================
void triggerFeed(String mode)
{
  if (feeding)
    return;

  feeding = true;

  Serial.println("FEED START: " + mode);

  client.publish("client2/status", "{\"pakan\":\"RUN\"}");

  /// AKSI
  // digitalWrite(RELAY_EN_1_PIN, HIGH);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
  delay(1000); // durasi pakan

  // digitalWrite(RELAY_EN_1_PIN, LOW);

  client.publish("client2/status", "{\"pakan\":\"STOP\"}");

  feeding = false;

  Serial.println("FEED DONE");
}

// ================= MOTOR & CONVEYOR CONTROL =================

void Motor_1(bool en, bool dir)
{
  if (en)
  {
    digitalWrite(RELAY_3_PIN, dir ? HIGH : LOW); // DIR ON
    digitalWrite(RELAY_2_PIN, HIGH);             // EN ON

    motor1_dirActive = true;
  }
  else
  {
    digitalWrite(RELAY_2_PIN, LOW); // motor OFF

    // simpan waktu berhenti
    motor1_stopTime = millis();
  }
}

void Motor_2(bool en, bool dir)
{
  if (en)
  {
    digitalWrite(RELAY_5_PIN, dir ? HIGH : LOW); // DIR
    digitalWrite(RELAY_4_PIN, HIGH);             // EN

    motor2_dirActive = true;
  }
  else
  {
    digitalWrite(RELAY_4_PIN, LOW); // OFF
    motor2_stopTime = millis();
  }
}

void setSystemStatus(String newStatus)
{
  if (systemStatus == newStatus)
    return;

  systemStatus = newStatus;

  Serial.print("STATUS: ");
  Serial.println(systemStatus);

  // 🔥 MQTT publish (hanya kalau berubah)
  if (client.connected())
  {
    String payload = "{\"pakan\":\"" + systemStatus + "\"}";
    client.publish("client2/status", payload.c_str());
  }
}

void conveyor(bool en)
{
  digitalWrite(RELAY_1_PIN, en ? HIGH : LOW);
}

void stopAllMotor()
{
  Motor_1(false, motor1_dir);
  Motor_2(false, motor2_dir);
  conveyor(false);

  motor1_running = false;
  motor2_running = false;

  system_running = false;
  setSystemStatus("STOP");
  Serial.println("!!! EMERGENCY STOP !!!");
}

void startSystem()
{
  if (system_running)
    return;

  system_running = true;
  setSystemStatus("RUN");

  // ===== MOTOR 1 (selalu jalan) =====
  motor1_dir = !motor1_dir;
  motor1_running = true;
  motor1_startTime = millis();
  motor1_stopTime = millis();
  motor1_dirActive = true;

  // ===== MOTOR 2 (hanya mode 2) =====
  if (runMode == 2)
  {
    motor2_dir = !motor2_dir;
    motor2_running = true;
    motor2_startTime = millis();
    motor2_stopTime = millis();
    motor2_dirActive = true;
  }

  // ===== CONVEYOR =====
  conveyor(true);
  conveyor_running = true;
  conveyor_startTime = millis();

  Serial.print("MODE: ");
  Serial.println(runMode == 1 ? "Motor1 Only" : "Motor1 + Motor2");
}

void handleButtons()
{
  bool btnStart = digitalRead(BUTTON_1_PIN);
  bool btnStop = digitalRead(BUTTON_2_PIN);

  // ===== STOP (prioritas tinggi) =====
  if (lastButtonStop == HIGH && btnStop == LOW)
  {
    delay(20);
    stopAllMotor();
  }

  // ===== START (hanya saat tombol ditekan) =====
  if (lastButtonStart == HIGH && btnStart == LOW)
  {
    delay(20);
    startSystem();

    // if (!system_running)
    // {
    //   system_running = true;

    //   // Motor 1
    //   motor1_dir = !motor1_dir;
    //   motor1_running = true;
    //   motor1_startTime = millis();
    //   motor1_stopTime = millis(); // 🔥 TAMBAH INI
    //   motor1_dirActive = true;    // 🔥 TAMBAH INI

    //   // Motor 2
    //   motor2_dir = !motor2_dir;
    //   motor2_running = true;
    //   motor2_startTime = millis();
    //   motor2_stopTime = millis(); // 🔥 TAMBAH INI
    //   motor2_dirActive = true;    // 🔥 TAMBAH INI

    //   Serial.println("SYSTEM START");
    // }
  }

  lastButtonStart = btnStart;
  lastButtonStop = btnStop;
}

bool readLimit(uint8_t pin)
{
  int count = 0;

  for (int i = 0; i < 5; i++)
  {
    if (digitalRead(pin) == LOW)
      count++;
    delay(1);
  }

  return (count >= 3);
}

void handleMotor1()
{
  if (!system_running || !motor1_running)
    return;

  if (millis() - motor1_startTime < LIMIT_IGNORE_TIME)
  {
    Motor_1(true, motor1_dir);
    return;
  }

  if (readLimit(LIMIT_1_PIN) || readLimit(LIMIT_2_PIN))
  {
    Motor_1(false, motor1_dir);
    motor1_running = false;
    Serial.println("Motor1 STOP (limit)");
   
    // 🔥 reset system jika semua motor selesai
    if (!motor1_running && !motor2_running && system_running)
    {
      system_running = false;
      setSystemStatus("READY");
      // Serial.println("SYSTEM READY");
    }

    return;
  }

  Motor_1(true, motor1_dir);
}

void handleMotor2()
{
  // 🔥 jika mode 1 → pastikan motor2 mati
  if (runMode == 1)
  {
    Motor_2(false, motor2_dir);
    motor2_running = false;
    //setSystemStatus("STOP");

    if (!motor1_running)
    {
      system_running = false;
      setSystemStatus("STOP");
      // Serial.println("SYSTEM READY");
    }

    return;
  }
  if (!system_running || !motor2_running)
    return;

  if (millis() - motor2_startTime < LIMIT_IGNORE_TIME)
  {
    Motor_2(true, motor2_dir);
    return;
  }

  if (readLimit(LIMIT_3_PIN) || readLimit(LIMIT_4_PIN))
  {
    Motor_2(false, motor2_dir);
    motor2_running = false;

    Serial.println("Motor2 STOP (limit)");
    //setSystemStatus("STOP");

    if (!motor1_running && !motor2_running && system_running)
    {
      system_running = false;
      setSystemStatus("STOP");
      // Serial.println("SYSTEM READY");
    }

    return;
  }

  Motor_2(true, motor2_dir);
}

void handleConveyor()
{
  if (!conveyor_running)
    return;

  // 🔥 pakai nilai dari EEPROM
  if (millis() - conveyor_startTime >= (conveyorTime * 1000))
  {
    conveyor(false);
    conveyor_running = false;

    Serial.println("Conveyor STOP (timer EEPROM)");
  }
}

void handleMotor1DirTimeout()
{
  if (!motor1_running && motor1_dirActive &&
      (millis() - motor1_stopTime > 2000))
  {
    digitalWrite(RELAY_3_PIN, LOW);
    motor1_dirActive = false;

    Serial.println("DIR Motor1 OFF (timeout)");
  }
}
void handleMotor2DirTimeout()
{
  if (!motor2_running && motor2_dirActive &&
      (millis() - motor2_stopTime > 2000))
  {
    digitalWrite(RELAY_5_PIN, LOW);
    motor2_dirActive = false;

    Serial.println("DIR Motor2 OFF (timeout)");
  }
}

/// ================= MQTT CALLBACK =================
void callback(char *topic, byte *payload, unsigned int length)
{
  String msg;

  for (int i = 0; i < length; i++)
  {
    msg += (char)payload[i];
  }

  Serial.println("\n=== MQTT MASUK ===");
  Serial.println("TOPIC: " + String(topic));
  Serial.println("PAYLOAD: " + msg);

  /// FEED NOW
  if (String(topic) == "client2/set/pakan")
  {
    StaticJsonDocument<100> doc;

    if (deserializeJson(doc, msg))
    {
      Serial.println("JSON ERROR");
      return;
    }

    if (doc["run"] == 1)
    {
      triggerFeed("MANUAL");
      startSystem();
    }
  }

  /// STATUS CLIENT2
  if (String(topic) == "client2/status")
  {
    StaticJsonDocument<100> doc;

    if (!deserializeJson(doc, msg))
    {
      client2_status = doc["pakan"] | "-";
    }
  }

  /// JADWAL
  if (String(topic) == "client2/set/jadwal")
  {

    StaticJsonDocument<2048> doc;

    DeserializationError error = deserializeJson(doc, msg);

    if (error)
    {
      Serial.print("JSON ERROR: ");
      Serial.println(error.c_str());
      return;
    }

    /// 🔥 PENTING: pakai ini
    if (!doc.is<JsonArray>())
    {
      Serial.println("ROOT BUKAN ARRAY!");
      return;
    }

    JsonArray arr = doc.as<JsonArray>();

    scheduleCount = 0;

    for (JsonObject obj : arr)
    {
      if (scheduleCount >= MAX_SCHEDULE)
        break;

      String t = obj["on"] | "";

      Serial.print("TIME: ");
      Serial.println(t);

      schedules[scheduleCount].time = t;
      schedules[scheduleCount].dayCount = 0;

      if (obj["days"].is<JsonArray>())
      {
        for (JsonVariant d : obj["days"].as<JsonArray>())
        {
          String day = d.as<String>();

          schedules[scheduleCount].days[schedules[scheduleCount].dayCount++] = day;

          Serial.print("DAY: ");
          Serial.println(day);
        }
      }

      scheduleCount++;
    }
    saveScheduleToEEPROM();
    scheduleChanged = true;
    Serial.print("TOTAL: ");
    Serial.println(scheduleCount);
  }
}

/// ================= CEK JADWAL (RTC) =================
void checkSchedule()
{

  DateTime now = rtc.now();

  char buf[6];
  sprintf(buf, "%02d:%02d", now.hour(), now.minute());

  String nowTime = String(buf);
  String dayName = daysOfTheWeek[now.dayOfTheWeek()];

  for (int i = 0; i < scheduleCount; i++)
  {

    if (schedules[i].time == nowTime)
    {

      for (int j = 0; j < schedules[i].dayCount; j++)
      {

        if (schedules[i].days[j] == dayName)
        {

          String key = dayName + nowTime;

          if (key != lastTrigger)
          {
            lastTrigger = key;
            // triggerFeed("AUTO");
            startSystem();
          }
        }
      }
    }
  }
}

/// ================= MQTT RECONNECT =================
unsigned long lastReconnectAttempt = 0;
void reconnect()
{
  if (client.connected())
    return;

  unsigned long now = millis();

  // coba tiap 3 detik saja
  if (now - lastReconnectAttempt < 3000)
    return;

  lastReconnectAttempt = now;

  Serial.print("MQTT connect...");

  if (client.connect("ESP32_FEEDER", mqtt_user, mqtt_pass))
  {
    Serial.println("OK");

    client.subscribe("client2/set/pakan");
    client.subscribe("client2/set/jadwal");
  }
  else
  {
    Serial.print("FAILED: ");
    Serial.println(client.state());
  }
}

void drawStaticUI()
{
  tft.fillScreen(TFT_BLACK);

  // HEADER
  tft.fillRect(0, 0, 320, 25, TFT_BLUE);
  tft.setTextColor(TFT_WHITE, TFT_BLUE);
  tft.drawString("MONITOR SISTEM", 10, 5, 2);
  tft.drawString("Mode :", 210, 5, 2);

  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.drawString("WiFi:", 10, 40, 2);
  tft.drawString("MQTT:", 10, 65, 2);
  tft.drawString("Status:", 10, 90, 2);
}

bool buzzerOn = false;
unsigned long buzzerTimer = 0;

void beep()
{
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  delay(100);
}

// void drawMenuOverlay()
// {
//   tft.fillRect(0, 180, 320, 60, TFT_BLACK);

//   tft.setTextColor(TFT_YELLOW, TFT_BLACK);
//   tft.drawString("MENU:", 10, 180, 2);

//   if (menuIndex == 0)
//     tft.setTextColor(TFT_BLACK, TFT_YELLOW);
//   else
//     tft.setTextColor(TFT_WHITE, TFT_BLACK);
//   tft.drawString("Tambah", 10, 200, 2);

//   if (menuIndex == 1)
//     tft.setTextColor(TFT_BLACK, TFT_YELLOW);
//   else
//     tft.setTextColor(TFT_WHITE, TFT_BLACK);
//   tft.drawString("Hapus", 8, 200, 2);
// }

void drawMenuMain()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.drawString("MENU:", 10, 180, 2);

  const char *menu[5] = {"Tambah", "Hapus", "Timer", "Hotspot", "Motor"};

  for (int i = 0; i < 5; i++)
  {
    if (i == menuIndex)
      tft.setTextColor(TFT_BLACK, TFT_YELLOW);
    else
      tft.setTextColor(TFT_WHITE, TFT_BLACK);

    tft.drawString(menu[i], 10 + i * 60, 205, 2);
  }
}

void drawMenuInputTime()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("INPUT JAM (HHMM):", 10, 180, 2);

  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.drawString(formatTimeDisplay(inputTime), 10, 210, 4);
  // jika panjang 4 tapi invalid
  if (inputTime.length() == 4 && !isValidTime(inputTime))
  {
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.drawString("Format Salah!", 150, 210, 2);
  }
}

void drawMenuSelectDay()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  for (int i = 0; i < 7; i++)
  {
    if (i == selectedDay)
      tft.setTextColor(TFT_BLACK, TFT_YELLOW);
    else
      tft.setTextColor(TFT_WHITE, TFT_BLACK);

    // tft.drawString(daysOfTheWeek[i].substring(0,3), 10 + i * 45, 200, 2);
    tft.drawString(String(daysOfTheWeek[i]).substring(0, 3), 10 + i * 45, 200, 2);
    // 🔥 centang
    tft.drawRect(13 + i * 45, 220, 12, 12, TFT_WHITE);

    if (daySelected[i])
      tft.fillRect(15 + i * 45, 222, 8, 8, TFT_GREEN);
  }
}

void drawMenuDelete()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  if (scheduleCount == 0)
  {
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.drawString("Tidak ada jadwal", 10, 200, 2);
    return;
  }

  for (int i = 0; i < scheduleCount; i++)
  {
    if (i == menuIndex)
      tft.setTextColor(TFT_BLACK, TFT_RED);
    else
      tft.setTextColor(TFT_WHITE, TFT_BLACK);

    tft.drawString(schedules[i].time, 10 + i * 60, 200, 2);
  }
}
void drawMenuTimer()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("SET TIMER (detik)", 10, 180, 2);

  tft.setTextColor(TFT_YELLOW, TFT_BLACK);

  String display = inputTimer;
  if (display == "")
    display = String(conveyorTime);

  tft.drawString(display + " s", 10, 210, 4);
}

void drawMenuMode()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("MODE HOTSPOT", 10, 180, 2);

  if (hotspotMode)
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
  else
    tft.setTextColor(TFT_RED, TFT_BLACK);

  tft.drawString(hotspotMode ? "Aktif" : "Tidak", 10, 210, 4);
}

void drawKeypadInfo()
{
  static int lastState = -1;
  static bool lastMenuActive = false;

  // 🔥 kalau tidak berubah → tidak redraw
  if (lastState == menuState && lastMenuActive == menuActive)
    return;

  lastState = menuState;
  lastMenuActive = menuActive;

  int x = 10;
  int y = 162;

  tft.fillRect(0, y, 320, 16, TFT_YELLOW);
  tft.setTextColor(TFT_BLACK, TFT_YELLOW);

  if (!menuActive)
  {
    tft.drawString("D : Menu", x, y, 2);
    return;
  }

  if (menuState == MENU_MAIN)
  {
    tft.drawString("A/B : Pilih   # : Enter   * : Exit", x, y, 2);
  }
  else if (menuState == MENU_ADD_TIME)
  {
    tft.drawString("0-9 : Input  C : Hapus  # : Next   * : Exit", x, y, 2);
  }
  else if (menuState == MENU_ADD_DAY)
  {
    tft.drawString("A/B : Pilih  # : Ceklis  D : Save   * : Exit", x, y, 2);
  }
  else if (menuState == MENU_DELETE)
  {
    tft.drawString("A/B : Pilih  # : Hapus  * : Exit", x, y, 2);
  }
  else if (menuState == MENU_TIMER)
  {
    tft.drawString("0-9 : Input  # : Save  * : Exit", x, y, 2);
  }
  else if (menuState == MENU_MODE_HOTSPOT)
  {
    tft.drawString("A/B : Ubah  # : Enter  * : Exit", x, y, 2);
  }
  else if (menuState == MENU_MODE_MOTOR)
  {
    tft.drawString("A/B : Ubah  # : Save  * : Exit", x, y, 2);
  }
}

void drawMenuHotspot()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("MODE HOTSPOT", 10, 180, 2);

  tft.setTextColor(hotspotMode ? TFT_GREEN : TFT_RED, TFT_BLACK);
  tft.drawString(hotspotMode ? "Aktif" : "Tidak", 10, 210, 4);
}

void drawMenuMotor()
{
  tft.fillRect(0, 180, 320, 60, TFT_BLACK);

  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.drawString("MODE MOTOR", 10, 180, 2);

  tft.setTextColor(TFT_YELLOW, TFT_BLACK);

  if (runMode == 1)
    tft.drawString("Motor1 Only", 10, 210, 4);
  else
    tft.drawString("Motor1 + Motor2", 10, 210, 4);
}

void handleKeypad()
{
  static unsigned long lastRead = 0;
  if (millis() - lastRead < 80)
    return;
  lastRead = millis();

  uint8_t index = keypad.getKey();

  // 🔥 filter jika tidak ada tombol
  if (index >= 16)
    return;

  char key = keymap[index];

  Serial.print("Index: ");
  Serial.print(index);
  Serial.print(" -> Tombol: ");
  Serial.println(key);

  beep();

  // ================= MASUK MENU =================
  if (key == 'D' && !menuActive)
  {
    menuActive = true;
    menuState = MENU_MAIN;
    menuIndex = 0;
    needRedrawMenu = true;
    return;
  }

  if (!menuActive)
    return;

  // ================= MENU UTAMA =================
  // 🔥 KELUAR MENU GLOBAL (tombol *)
  if (key == '*')
  {
    menuActive = false;
    menuState = MENU_NONE;
    needRedrawMenu = true;
    return;
  }

  if (menuState == MENU_MAIN)
  {
    if (key == 'A')
    {
      menuIndex--;
      needRedrawMenu = true; // 🔥 TAMBAH INI
    }

    if (key == 'B')
    {
      menuIndex++;
      needRedrawMenu = true; // 🔥 TAMBAH INI
    }

    if (menuIndex < 0)
      menuIndex = 4;
    if (menuIndex > 4)
      menuIndex = 0;

    if (key == '#')
    {
      if (menuIndex == 0)
      {
        menuState = MENU_ADD_TIME;
        inputTime = "";
      }
      else if (menuIndex == 1)
      {
        menuState = MENU_DELETE;
        menuIndex = 0;
      }
      else if (menuIndex == 2)
      {
        menuState = MENU_TIMER;
        inputTimer = "";
      }
      else if (menuIndex == 3)
      {
        menuState = MENU_MODE_HOTSPOT; // 🔥
      }
      else if (menuIndex == 4)
      {
        menuState = MENU_MODE_MOTOR; // 🔥
      }
      needRedrawMenu = true;
    }
  }

  // ================= INPUT JAM =================
  else if (menuState == MENU_ADD_TIME)
  {
    if (key >= '0' && key <= '9' && inputTime.length() < 4)
    {
      inputTime += key;
      needRedrawMenu = true;
    }

    // 🔥 BACKSPACE (C)
    if (key == 'C')
    {
      if (inputTime.length() > 0)
      {
        inputTime.remove(inputTime.length() - 1);
        needRedrawMenu = true;
      }
    }

    // lanjut pilih hari
    if (key == '#')
    {
      // 🚫 belum 4 digit
      if (inputTime.length() != 4)
      {
        beep();
        return;
      }

      // 🚫 format salah
      if (!isValidTime(inputTime))
      {
        Serial.println("FORMAT JAM SALAH");

        digitalWrite(BUZZER_PIN, HIGH);
        delay(300);
        digitalWrite(BUZZER_PIN, LOW);

        needRedrawMenu = true;
        return;
      }

      // ✅ VALID → lanjut
      menuState = MENU_ADD_DAY;

      for (int i = 0; i < 7; i++)
        daySelected[i] = false;

      needRedrawMenu = true;
    }
    // keluar
    if (key == '*')
    {
      menuActive = false;
    }
  }

  // ================= PILIH HARI =================
  else if (menuState == MENU_ADD_DAY)
  {
    if (key == 'A')
      selectedDay--;
    if (key == 'B')
      selectedDay++;

    if (selectedDay < 0)
      selectedDay = 6;
    if (selectedDay > 6)
      selectedDay = 0;

    // 🔥 TOGGLE CENTANG (ON/OFF)
    if (key == '#')
    {
      daySelected[selectedDay] = !daySelected[selectedDay];
      needRedrawMenu = true;
    }

    // 🔥 BACKSPACE / UNSELECT CEPAT
    if (key == 'C')
    {
      daySelected[selectedDay] = false;
      needRedrawMenu = true;
    }

    // 🔥 SIMPAN (pakai D)
    if (key == 'D')
    {
      if (scheduleCount < MAX_SCHEDULE)
      {
        schedules[scheduleCount].time =
            inputTime.substring(0, 2) + ":" + inputTime.substring(2, 4);

        schedules[scheduleCount].dayCount = 0;

        // 🔥 ambil semua hari yang dicentang
        for (int i = 0; i < 7; i++)
        {
          if (daySelected[i])
          {
            schedules[scheduleCount].days[schedules[scheduleCount].dayCount++] = daysOfTheWeek[i];
          }
        }

        // minimal 1 hari harus dipilih
        if (schedules[scheduleCount].dayCount > 0)
        {
          scheduleCount++;
          saveScheduleToEEPROM();
        }
      }

      menuActive = false;
    }

    // keluar tanpa simpan
    if (key == '*')
    {
      menuActive = false;
    }

    needRedrawMenu = true;
  }

  // ================= HAPUS =================
  else if (menuState == MENU_DELETE)
  {
    if (scheduleCount == 0)
    {
      menuActive = false;
      return;
    }

    if (key == 'A')
      menuIndex--;
    if (key == 'B')
      menuIndex++;

    if (menuIndex < 0)
      menuIndex = scheduleCount - 1;
    if (menuIndex >= scheduleCount)
      menuIndex = 0;

    if (key == '#')
    {
      for (int i = menuIndex; i < scheduleCount - 1; i++)
        schedules[i] = schedules[i + 1];

      scheduleCount--;
      saveScheduleToEEPROM();
    }

    if (key == '*')
    {
      menuActive = false;
    }

    needRedrawMenu = true;
  }

  // ================= TIMER =================
  else if (menuState == MENU_TIMER)
  {
    // input angka
    if (key >= '0' && key <= '9' && inputTimer.length() < 3)
    {
      inputTimer += key;
      needRedrawMenu = true;
    }

    // 🔥 BACKSPACE
    if (key == 'C')
    {
      if (inputTimer.length() > 0)
      {
        inputTimer.remove(inputTimer.length() - 1);
        needRedrawMenu = true;
      }
    }

    // 🔥 SIMPAN
    if (key == '#')
    {
      int val = inputTimer.toInt();

      if (val > 0 && val <= 120)
      {
        conveyorTime = val;
        saveTimerToEEPROM(); // 🔥 SIMPAN
      }

      // menuActive = false;
    }

    // keluar
    if (key == '*')
    {
      menuActive = false;
      menuState = MENU_NONE;
      needRedrawMenu = true;
      return;
    }
  }
  // ================= Mode Hotspot=================
  else if (menuState == MENU_MODE_HOTSPOT)
  {
    // toggle
    if (key == 'A' || key == 'B')
    {
      hotspotMode = !hotspotMode;
      needRedrawMenu = true;
    }

    // simpan + restart
    if (key == '#')
    {
      saveModeToEEPROM();

      if (hotspotMode)
      {
        tft.fillScreen(TFT_BLACK);
        tft.setTextColor(TFT_YELLOW);
        tft.setTextColor(TFT_YELLOW, TFT_BLACK);
        tft.drawCentreString("Restart...", 160, 100, 2);
        delay(1000);
        ESP.restart();
      }
    }

    // keluar
    if (key == '*')
    {
      menuActive = false;
      menuState = MENU_NONE;
      needRedrawMenu = true;
    }
  }
  // ================= Mode Motor=================
  else if (menuState == MENU_MODE_MOTOR)
  {
    // toggle mode 1 ↔ 2
    if (key == 'A' || key == 'B')
    {
      runMode++;
      if (runMode > 2)
        runMode = 1;

      needRedrawMenu = true;
    }

    // simpan
    if (key == '#')
    {
      saveRunMode();
    }

    // keluar
    if (key == '*')
    {
      menuActive = false;
      menuState = MENU_NONE;
      needRedrawMenu = true;
    }
  }
}
/// ================= SETUP =================
void setup()
{
  Serial.begin(9600);

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BUTTON_1_PIN, INPUT_PULLUP); // trigger Motor 1 run
  pinMode(BUTTON_2_PIN, INPUT_PULLUP); // trigger Motor 2 run
  pinMode(LIMIT_1_PIN, INPUT);
  pinMode(LIMIT_2_PIN, INPUT);
  pinMode(LIMIT_3_PIN, INPUT);
  pinMode(LIMIT_4_PIN, INPUT);
  pinMode(RELAY_1_PIN, OUTPUT); // EN Conveyor
  pinMode(RELAY_2_PIN, OUTPUT); // EN Motor 1
  pinMode(RELAY_3_PIN, OUTPUT); // DIR Motor 1
  pinMode(RELAY_4_PIN, OUTPUT); // EN Motor 2
  pinMode(RELAY_5_PIN, OUTPUT); // DIR Motor 2

  // 🔥 1. I2C
  Wire.begin(21, 22);
  keypad.begin();

  // 🔥 2. RTC
  if (!rtc.begin())
  {
    Serial.println("RTC ERROR");
    while (1)
      ;
  }

  // 🔥 3. TFT
  tft.init();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.drawCentreString("LOADING...!", 160, 100, 4);

  // 🔥 4. EEPROM
  EEPROM.begin(EEPROM_SIZE);
  loadScheduleFromEEPROM();
  loadTimerFromEEPROM();
  loadModeFromEEPROM();
  loadRunMode();

  // 🔥 5. HOTSPOT DECISION
  if (hotspotMode)
  {
    tft.fillScreen(TFT_BLACK);

    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    tft.drawCentreString("HOTSPOT MODE", 160, 80, 4);

    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.drawCentreString("Tekan * untuk batal", 160, 120, 2);
    tft.drawCentreString("Auto start 10 detik", 160, 140, 2);

    if (!waitHotspotDecision())
    {
      hotspotMode = false;
      saveModeToEEPROM();
    }
  }

  // 🔥 6. WIFI (tetap dipanggil)
  setup_wifi();

  // 🔥 7. RTC Sync
  DateTime now = rtc.now();

  if (rtc.lostPower() || now.year() < 2024)
  {
    Serial.println("RTC tidak valid");

    if (WiFi.status() == WL_CONNECTED)
    {
      syncRTCFromNTP();
    }
    else
    {
      Serial.println("Pakai waktu terakhir RTC / compile time");

      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    }
  }

  // 🔥 8. UI
  tft.fillScreen(TFT_BLACK);
  drawStaticUI();

  // 🔥 9. MQTT
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);

  beep();
  Serial.println("SYSTEM READY");
}
/// ================= LOOP =================
unsigned long lastPrint = 0;
unsigned long lastUI = 0;

void loop()
{
  // ===== SYSTEM CORE (REALTIME) =====
  handleButtons();
  handleMotor1();
  handleMotor2();
  handleConveyor();
  handleMotor1DirTimeout();
  handleMotor2DirTimeout();

  // ===== NETWORK =====
  wifiConnected = WiFi.status() == WL_CONNECTED;
  mqttConnected = client.connected();

  handleRTCUpdate();

  if (!client.connected())
    reconnect();

  client.loop();
  checkSchedule();

  // ===== INPUT =====
  handleKeypad();

  // ===== UI =====
  if (millis() - lastUI > 200)
  {
    lastUI = millis();
    updateDashboard();
    updateScheduleUI();
    drawKeypadInfo();
  }

  if (millis() - lastPrint > 5000)
  {
    lastPrint = millis();
    printNextSchedule();
  }

  if (needRedrawMenu)
  {
    needRedrawMenu = false;

    if (!menuActive)
    {
      tft.fillRect(0, 180, 320, 60, TFT_BLACK);
    }
    else
    {
      switch (menuState)
      {
      case MENU_MAIN:
        drawMenuMain();
        break;
      case MENU_ADD_TIME:
        drawMenuInputTime();
        break;
      case MENU_ADD_DAY:
        drawMenuSelectDay();
        break;
      case MENU_DELETE:
        drawMenuDelete();
        break;
      case MENU_TIMER:
        drawMenuTimer();
        break;
      case MENU_MODE_HOTSPOT:
        drawMenuHotspot();
        break;

      case MENU_MODE_MOTOR:
        drawMenuMotor();
        break;
      }
    }
  }
}