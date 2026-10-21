#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <uri/UriBraces.h>

// WIFI_SSID, WIFI_PASSWORD and API_TOKEN live in secrets.h (gitignored).
// Copy secrets.example.h to secrets.h and fill it in before flashing.
#include "secrets.h"

// HTTP + JSON API for the Recettas app ("Tomadas" screen), reached over
// the home Tailscale subnet router:
//
//   GET /api/status        -> {"online":true,"relays":{"1":false,...}}
//   PUT /api/relays/{n}    <- {"state":true}  -> {"success":true,"relays":{...}}
//   GET /api/health        -> {"status":"ok","uptime":86400,...}
//
// Every request needs "Authorization: Bearer API_TOKEN".
// Commands are explicit ON/OFF, never toggles, so a retried request is
// harmless. Responses are sent only after the GPIO has been written.

// Relay pins — same wiring as washing_machine.ino; relay N in the API = IN#N.
// Wire notation: relay-side color > ESP-side color
// The board is active-low: LOW energizes the relay, HIGH = off.
struct Relay {
  uint8_t pin;
  const char* label;
  // Auto-off after this many ms (0 = stays on until told otherwise).
  // The drain valve is a motorized valve driven by 15s pulses, so its
  // OPEN/CLOSE relays must never stay energized.
  unsigned long maxOnMs;
};

const Relay RELAYS[] = {
  { 5,  "IN1 / D1 - Valvula solenoide entrada de agua", 0      },  // WHITE > YELLOW
  { 4,  "IN2 / D2 - Bomba de drenagem",                 0      },  // BLACK > ORANGE
  { 0,  "IN3 / D3 - Motor",                             0      },  // BROWN > GREY    ⚠ GPIO0: boot pin, must stay HIGH at boot
  { 2,  "IN4 / D4 - Valvula drenagem ABRIR",            15000  },  // RED > WHITE     ⚠ GPIO2: boot pin, must stay HIGH at boot
  { 14, "IN5 / D5 - Bomba entrada de agua",             0      },  // PURPLE/GREY, grey end at ESP
  { 12, "IN6 / D6 - Valvula drenagem FECHAR",           15000  },  // GREY/PURPLE, purple end at ESP
  { 13, "IN7 / D7 - Reservado (sem carga)",             0      },  // BLUE > PURPLE
  // IN8 is not wired to the ESP.
};
const int RELAY_COUNT = sizeof(RELAYS) / sizeof(RELAYS[0]);

// Relays that must never be on at the same time (1-based). Driving the
// drain valve OPEN and CLOSE together would fight the valve motor.
const int INTERLOCKS[][2] = {
  { 4, 6 },
};
const int INTERLOCK_COUNT = sizeof(INTERLOCKS) / sizeof(INTERLOCKS[0]);

const size_t MAX_BODY_BYTES = 64;

bool relayOn[RELAY_COUNT];
unsigned long relayOnSince[RELAY_COUNT];

ESP8266WebServer server(80);

// ─────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(100);

  // All relays off before anything else. Latch HIGH before switching to
  // OUTPUT so active-low relays don't click on during boot.
  for (int i = 0; i < RELAY_COUNT; i++) {
    digitalWrite(RELAYS[i].pin, HIGH);
    pinMode(RELAYS[i].pin, OUTPUT);
    digitalWrite(RELAYS[i].pin, HIGH);
    relayOn[i] = false;
    relayOnSince[i] = 0;
  }

  Serial.println("Controlador de reles iniciando...");

  connectWiFi();

  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/health", HTTP_GET, handleHealth);
  server.on(UriBraces("/api/relays/{}"), HTTP_PUT, handleSetRelay);
  server.onNotFound(handleNotFound);
  server.begin();
  Serial.println("API HTTP pronta na porta 80.");
}

void loop() {
  server.handleClient();
  enforceMaxOnTime();

  // Auto-reconnect is on, this just logs the new IP once it's back.
  static bool wasConnected = true;
  bool connected = WiFi.status() == WL_CONNECTED;
  if (connected && !wasConnected) {
    Serial.println("WiFi reconectado. IP: " + WiFi.localIP().toString());
  }
  wasConnected = connected;
}

// ─────────────────────────────────────────────
// WIFI
// ─────────────────────────────────────────────
void connectWiFi() {
  Serial.print("Conectando ao WiFi...");
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(" Conectado! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println(" Falha! Tentando de novo em segundo plano.");
  }
}

// ─────────────────────────────────────────────
// RELAYS
// ─────────────────────────────────────────────
void writeRelay(int index, bool on) {
  digitalWrite(RELAYS[index].pin, on ? LOW : HIGH);
  if (on && !relayOn[index]) relayOnSince[index] = millis();
  relayOn[index] = on;
  Serial.printf("%s -> %s\n", RELAYS[index].label, on ? "LIGADO" : "DESLIGADO");
}

// Number of the relay that blocks turning `relay` on, or 0 if none.
int interlockConflict(int relay) {
  for (int i = 0; i < INTERLOCK_COUNT; i++) {
    int a = INTERLOCKS[i][0];
    int b = INTERLOCKS[i][1];
    if (relay == a && relayOn[b - 1]) return b;
    if (relay == b && relayOn[a - 1]) return a;
  }
  return 0;
}

void enforceMaxOnTime() {
  unsigned long now = millis();
  for (int i = 0; i < RELAY_COUNT; i++) {
    if (relayOn[i] && RELAYS[i].maxOnMs > 0 &&
        now - relayOnSince[i] >= RELAYS[i].maxOnMs) {
      Serial.print("Tempo maximo atingido: ");
      writeRelay(i, false);
    }
  }
}

// ─────────────────────────────────────────────
// HTTP API
// ─────────────────────────────────────────────
bool authorized() {
  String expected = String("Bearer ") + API_TOKEN;
  String given = server.header("Authorization");
  // Constant-time compare so the token can't be guessed byte by byte.
  if (given.length() != expected.length()) return false;
  uint8_t diff = 0;
  for (size_t i = 0; i < expected.length(); i++) {
    diff |= given[i] ^ expected[i];
  }
  return diff == 0;
}

void sendJson(int code, const String& body) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(code, "application/json", body);
}

void sendError(int code, const String& message) {
  sendJson(code, "{\"success\":false,\"error\":\"" + message + "\"}");
}

String relaysJson() {
  String json = "{";
  for (int i = 0; i < RELAY_COUNT; i++) {
    if (i > 0) json += ",";
    json += "\"" + String(i + 1) + "\":" + (relayOn[i] ? "true" : "false");
  }
  return json + "}";
}

void handleStatus() {
  if (!authorized()) return sendError(401, "unauthorized");
  sendJson(200, "{\"online\":true,\"relays\":" + relaysJson() + "}");
}

void handleHealth() {
  if (!authorized()) return sendError(401, "unauthorized");
  sendJson(200,
           "{\"status\":\"ok\",\"uptime\":" + String(millis() / 1000) +
           ",\"rssi\":" + String(WiFi.RSSI()) +
           ",\"freeHeap\":" + String(ESP.getFreeHeap()) + "}");
}

// Parses {"state": true|false} without pulling in a JSON library.
// Returns 1 / 0, or -1 when the body is malformed.
int parseState(const String& body) {
  int key = body.indexOf("\"state\"");
  if (key < 0) return -1;
  int colon = body.indexOf(':', key + 7);
  if (colon < 0) return -1;
  int i = colon + 1;
  while (i < (int)body.length() && isspace(body[i])) i++;
  if (body.startsWith("true", i)) return 1;
  if (body.startsWith("false", i)) return 0;
  return -1;
}

void handleSetRelay() {
  if (!authorized()) return sendError(401, "unauthorized");

  String arg = server.pathArg(0);
  int relay = arg.toInt();
  if (relay < 1 || relay > RELAY_COUNT || String(relay) != arg) {
    return sendError(400, "invalid relay number");
  }

  String body = server.arg("plain");
  if (body.length() > MAX_BODY_BYTES) return sendError(400, "body too large");
  int state = parseState(body);
  if (state < 0) return sendError(400, "expected {\\\"state\\\": true|false}");

  if (state == 1) {
    int conflict = interlockConflict(relay);
    if (conflict) {
      return sendError(503, "relay " + String(conflict) + " is on; turn it off first");
    }
  }

  writeRelay(relay - 1, state == 1);
  sendJson(200, "{\"success\":true,\"relays\":" + relaysJson() + "}");
}

void handleNotFound() {
  sendError(404, "not found");
}
