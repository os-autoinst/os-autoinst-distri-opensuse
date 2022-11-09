/*
# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-3.0-or-later
*/

#include <WiFi.h>
#include <WiFiClient.h>
#include <WebServer.h>

#include <Keyboard.h>
#include "keymap.h"


#define STASSID "openQA-worker"
#define STAPSK "CHANGE THIS DUMMY TO YOUR PASSWORD"

#define WEBSERVER_PORT 80

#define SENDKEY_KEY_PRESS_TIME_MS 30
#define WIFI_CONNECT_DOT_PROGRESS_INTERVAL_MS 500
#define WIFI_CONNECT_RESET_AFTER_INTERVAL_NUM 30

#define DEFAULT_WEB_DOC_LEN 2000
#define LOGBUF_LEN 10
#define LOGBUF_MAXLEN DEFAULT_WEB_DOC_LEN * LOGBUF_LEN
#define WEBROOT_LEN LOGBUF_MAXLEN + DEFAULT_WEB_DOC_LEN

const char *ssid = STASSID;
const char *password = STAPSK;
WebServer server(WEBSERVER_PORT);


// Ringbuffer for the last LOGBUF_LEN keyboard inputs to be shown on the webui
char* logbuf[LOGBUF_LEN] = {NULL};
uint_fast8_t logbuf_next_idx = 0;

void logbuf_add(const char* logline) {
  if (logbuf[logbuf_next_idx] != NULL) {
    free(logbuf[logbuf_next_idx]);
  }
  logbuf[logbuf_next_idx] = strdup(logline);
  logbuf_next_idx = (logbuf_next_idx + 1) % LOGBUF_LEN;
}

void logbuf_out(String* out) {
  for (uint_fast8_t i=0; i < LOGBUF_LEN; i++) {
    uint_fast8_t idx = (logbuf_next_idx + i) % LOGBUF_LEN;
    if (logbuf[idx] == NULL) {
      continue;
    }
    *out += "<li>" + String(logbuf[idx]) + "</li>\n";
  }
}

// Functions for key combinarions (accepting qemu syntax) and typing strings
void kb_sendkey(String keycmd) {
  int start = 0;
  do {
    int next = keycmd.indexOf('-', start);
    int end = (next == -1) ? keycmd.length() : next;
    String key = keycmd.substring(start, end);
    uint8_t key_raw = get_key(key);
    if (key_raw) { 
      Serial.println("Pressing " + key);
      Keyboard.press(key_raw);
    }
    else {
      Serial.println("Could not find key " + key);
    }
    start = next + 1;
    delay(SENDKEY_KEY_PRESS_TIME_MS);
  } while (start != 0);
  Keyboard.releaseAll();
  Serial.println("Releasing all keys");
}

void kb_type(String s) {
  Serial.println("Typing " + s);
  Keyboard.print(s);
}


// Entry functions
void setup(void) {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.println("");

  // Wait for connection
  uint16_t i = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(WIFI_CONNECT_DOT_PROGRESS_INTERVAL_MS);
    Serial.print(".");
    if (i++ > WIFI_CONNECT_RESET_AFTER_INTERVAL_NUM) {
      Serial.println("wifi not coming up - resetting...");
      rp2040.reboot();
    }
  }

  Serial.println("");
  Serial.print("Connected to ");
  Serial.println(ssid);
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  digitalWrite(LED_BUILTIN, HIGH);

  server.on("/", web_handle_root);
  server.on("/cmd", web_handle_cmd);
  server.onNotFound(web_handle_not_found);
  server.begin();
  Serial.println("HTTP server started");

  Keyboard.begin();
}

void loop(void) {
  server.handleClient();
}


// Webserver callback functions
void web_handle_root() {
  char temp[WEBROOT_LEN + 1]; // 1 for string termination
  int sec = millis() / 1000;
  int min = sec / 60;
  int hr = min / 60;

  String ip = WiFi.localIP().toString();
  String mac = WiFi.macAddress();

  String log;
  log.reserve(LOGBUF_MAXLEN);
  logbuf_out(&log);

  snprintf(temp, WEBROOT_LEN, "<html>\
    <head>\
      <title>RPi Pico W Keyboard Emulator</title>\
      <style>\
        body { background-color: #cccccc; font-family: Arial, Helvetica, Sans-Serif; Color: #000088; }\
      </style>\
    </head>\
    <body>\
      <h1>This is RPi Pico W Keyboard Emulator!</h1>\
      <h3>Infos</h3>\
      <p>\
        Uptime: %02d:%02d:%02d<br>\
        Free heap mem: %i / %i<br>\
        SSID: <tt>%s</tt><br>\
        IP: <tt>%s</tt><br>\
        MAC: <tt>%s</tt><br>\
      </p>\
      <h3>API</h3>\
      <ul>\
        <li><tt>/cmd?type=type this string</tt></li>\
        <li><tt>/cmd?sendkey=ctrl-alt-del</tt></li>\
      </ul>\
      <h3>Keyboard log (newest %i entries - most recent entry last)</h3>\
      <ul>\
        %s\
      </ul>\
    </body>\
  </html>", hr, min % 60, sec % 60, rp2040.getFreeHeap(), rp2040.getTotalHeap(), ssid, ip.c_str(), mac.c_str(), LOGBUF_LEN, log.c_str());
  server.send(200, "text/html", temp);
}

void web_handle_not_found() {
  digitalWrite(LED_BUILTIN, LOW);
  String message = "File Not Found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET) ? "GET" : "POST";
  message += "\nArguments: ";
  message += server.args();
  message += "\n";

  for (uint_fast8_t i = 0; i < server.args(); i++) {
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }

  server.send(404, "text/plain", message);
  digitalWrite(LED_BUILTIN, HIGH);
}

void web_handle_cmd() {
  digitalWrite(LED_BUILTIN, LOW);
  String s;
  s.reserve(DEFAULT_WEB_DOC_LEN);
  for (uint_fast8_t i = 0; i < server.args(); i++) {
    if (server.argName(i) == "sendkey") {
      kb_sendkey(server.arg(i));
      s += "sendkey: " + server.arg(i);
      logbuf_add(s.c_str());
      break;      
    }
    if (server.argName(i) == "type") {
      kb_type(server.arg(i));
      s += "type: " + server.arg(i);
      logbuf_add(s.c_str());
      break;
    }
  }
  server.send(200, "text/plain", s+"\n");
  digitalWrite(LED_BUILTIN, HIGH);
}
