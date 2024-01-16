#!/bin/bash
xrandr --output DSI-1 --rotate right
xrandr --newmode "904x1400_60.00"  109.50  904 968 1064 1224  1440 1443 1453 1493 -hsync +vsync
xrandr --addmode DSI-1 904x1400_60.00
xrandr --output DSI-1 --mode 904x1400_60.00
