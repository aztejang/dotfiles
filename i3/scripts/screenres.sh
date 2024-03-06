#!/bin/bash

# Count the number of connected screens excluding the built-in display (e.g., DSI-1, LVDS-1, eDP-1)
num_screens=$(xrandr --query | grep ' connected' | grep -v 'DSI-1' | wc -l)

# Check if no external screens are connected
if [ "$num_screens" -eq 0 ]; then
    # Your original commands to run if there is no external screen connected
    xrandr --output DSI-1 --rotate right
    xrandr --newmode "904x1400_60.00"  109.50  904 968 1064 1224  1440 1443 1453 1493 -hsync +vsync
    xrandr --addmode DSI-1 904x1400_60.00
    xrandr --output DSI-1 --mode 904x1400_60.00
else
    echo "An external screen is connected. No action taken."
fi