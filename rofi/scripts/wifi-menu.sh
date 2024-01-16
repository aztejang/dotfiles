#!/usr/bin/env bash

# Get wifis, wrangle em around, add indicators for locked and unlocked etc 
get_wifi_list() {
    nmcli --fields "IN-USE,SECURITY,SSID" device wifi list | \
    sed 1d | \
    sed 's/  */ /g' | \
    sed -E 's/WPA*.?\S/ /g' | \
    sed 's/--/ /g' | \
    sed '/^\*/ {s/^\*//; s/$/ /}'
}

# Show loading message
(echo "Searching for Wi-Fi networks..."; sleep 0.1) | rofi -dmenu -i -selected-row 1 -p "Wi-Fi" -theme-str '@import "message.rasi"' & 
ROFI_PID=$!
wifi_list=$(get_wifi_list)
kill $ROFI_PID

# Wifi toggle
connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
    toggle="  Disable Wi-Fi"
elif [[ "$connected" =~ "disabled" ]]; then
    toggle="  Enable Wi-Fi"
fi

# Call rofi with wifi list
chosen_network=$(echo -e "$toggle\n$wifi_list" | uniq -u | rofi -dmenu -i -selected-row 1 -p "Wi-Fi SSID: " -theme-str '@import "wifi.rasi"' )

# Extract chosen SSID
chosen_id=$(echo "$chosen_network" | awk '{print $NF}')

if [ -z "$chosen_network" ]; then
    exit
elif [ "$chosen_network" = "  Enable Wi-Fi" ]; then
    nmcli radio wifi on
elif [ "$chosen_network" = "  Disable Wi-Fi" ]; then
    nmcli radio wifi off
else
    # Check if SSID is a saved connection
    saved_connection=$(nmcli connection show --active | grep "$chosen_id")

    # Connected message. TODO: add disconnected
    display_message_and_kill() {
        echo "Connected to $chosen_id" | rofi -dmenu -i -p "Wi-Fi" -theme-str '@import "message.rasi"' &
        local pid=$!
        sleep 2
        kill $pid
    }

    if [ -n "$saved_connection" ]; then
        # Connect to the saved connection
        if nmcli device wifi connect "$chosen_id" | grep -q "successfully"; then
            display_message_and_kill
        fi
    else
        # Prompt for password for new networks
        if [[ "$chosen_network" =~ "" ]]; then
            wifi_password=$(rofi -dmenu -p "Password: " -theme-str '@import "input.rasi"' )
            if [ -z "$wifi_password" ]; then
                exit # Exit if no password is entered
            fi
        fi
        if nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep -q "successfully"; then
            display_message_and_kill
        fi
    fi
fi