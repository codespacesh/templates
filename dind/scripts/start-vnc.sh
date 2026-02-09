#!/bin/bash
# Start VNC stack for Playwright headed mode
set -e

echo "Starting VNC desktop environment..."

export DISPLAY=:99

Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 &
sleep 1

fluxbox >/dev/null 2>&1 &
sleep 1

x11vnc -display :99 -forever -nopw -shared -rfbport 5900 >/dev/null 2>&1 &
sleep 1

websockify --web=/usr/share/novnc 6080 localhost:5900 >/dev/null 2>&1 &

echo "VNC desktop started!"
echo "  - VNC server: localhost:5900"
echo "  - noVNC web:  http://localhost:6080/vnc.html"
