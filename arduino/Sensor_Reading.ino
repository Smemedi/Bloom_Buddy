#include <SoftwareSerial.h>
#include <WiFiS3.h>
#include <connection.h> //Contains wifi SSID, password, server IP address

SoftwareSerial mod(2, 3);

const byte queryNPK[]   = {0x02, 0x03, 0x00, 0x00, 0x00, 0x07, 0x04, 0x3B};
const byte queryLight[] = {0x01, 0x03, 0x00, 0x02, 0x00, 0x02, 0x65, 0xCB};

byte buf[30];

const char* ssid     = "WIFI_SSID";
const char* password = "WIFI_PASS";
const char* server   = "IP_ADDR";
const int   port     = 5000;

WiFiClient client;

int findPattern(byte b0, byte b1, byte b2) {
  for (int i = 0; i < 27; i++) {
    if (buf[i] == b0 && buf[i+1] == b1 && buf[i+2] == b2) return i;
  }
  return -1;
}

bool readFrame(byte *buffer, int &len, int maxLen, int timeoutMs) {
  len = 0;
  unsigned long start = millis();

  while (millis() - start < timeoutMs && len < maxLen) {
    if (mod.available()) {
      buffer[len++] = mod.read();
    }
  }

  return len > 0;
}

void setup() {
  Serial.begin(9600);
  mod.begin(4800);
  delay(1000);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
}

void sendData(float moisture, float temp, int ec, float ph,
              int n, int p, int k, float lux) {

  if (!client.connect(server, port)) {
    return;
  }

  String json = "{";
  json += "\"moisture\":" + String(moisture, 1) + ",";
  json += "\"temperature\":" + String(temp, 1) + ",";
  json += "\"ec\":" + String(ec) + ",";
  json += "\"ph\":" + String(ph, 1) + ",";
  json += "\"nitrogen\":" + String(n) + ",";
  json += "\"phosphorus\":" + String(p) + ",";
  json += "\"potassium\":" + String(k) + ",";
  json += "\"lux\":" + String(lux, 1);
  json += "}";

  client.println("POST /reading HTTP/1.1");
  client.println("Host: " + String(server));
  client.println("Content-Type: application/json");
  client.println("Content-Length: " + String(json.length()));
  client.println("Connection: close");
  client.println();
  client.println(json);

  client.stop();
}

void loop() {

  float moisture = 0, temp = 0, ph = 0, lux = 0;
  int ec = 0, n = 0, p = 0, k = 0;

  // =========================
  // NPK SENSOR
  // =========================
  while (mod.available()) mod.read();

  mod.write(queryNPK, sizeof(queryNPK));
  delay(1200);

  memset(buf, 0, sizeof(buf));
  int idx = 0;

  while (mod.available() && idx < 30) {
    buf[idx++] = mod.read();
  }

  for (int i = 0; i < idx; i++) {
    Serial.print(buf[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  int start = findPattern(0x01, 0x03, 0x04);
  if (start >= 0 && (idx - start) >= 9) {

    byte *r = buf + start;

    moisture = ((r[3] << 8) | r[4]) * 0.1;
    temp     = ((r[5] << 8) | r[6]) * 0.1;
    ec       = (r[7] << 8) | r[8];
  }
  else {
  }

  delay(300);

  // =========================
  // LIGHT SENSOR
  // =========================
  while (mod.available()) mod.read();

  mod.write(queryLight, sizeof(queryLight));
  delay(800);

  memset(buf, 0, sizeof(buf));
  idx = 0;

  while (mod.available() && idx < 30) {
    buf[idx++] = mod.read();
  }

  int s = findPattern(0x01, 0x03, 0x04);
  if (s >= 0 && (idx - s) >= 7) {
    byte *r = buf + s;
    long raw = ((long)r[3] << 24) | ((long)r[4] << 16) |
               ((long)r[5] << 8) | r[6];
    lux = raw / 1000.0;
  }
  else {
  }

  // =========================
  // SEND DATA (FROZEN STATE)
  // =========================
  sendData(moisture, temp, ec, ph, n, p, k, lux);

  delay(10000);
}
