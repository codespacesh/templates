#!/bin/bash
# Start XFCE desktop environment with VNC
set -e

echo "Starting XFCE desktop environment..."

export DISPLAY=:99

# Start X virtual framebuffer
Xvfb :99 -screen 0 1920x1080x24 &
sleep 2

# Start XFCE session
startxfce4 &
sleep 3

# Start VNC server
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &
sleep 1

# Start noVNC web proxy
websockify --web=/usr/share/novnc 6080 localhost:5900 &

echo "XFCE desktop started!"
echo "  - VNC server: localhost:5900"
echo "  - noVNC web:  http://localhost:6080/vnc.html"
