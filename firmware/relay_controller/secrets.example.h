// Copy this file to secrets.h (gitignored) and fill in the real values.
#pragma once

#define WIFI_SSID     "your-wifi"
#define WIFI_PASSWORD "your-password"

// Same value goes in the app: Mais > Tomadas > gear icon > Token da API.
// Generate one with e.g.: python -c "import secrets; print(secrets.token_urlsafe(24))"
#define API_TOKEN     "change-me"
