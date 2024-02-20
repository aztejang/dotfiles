#!/usr/bin/env bash

# Constants
divider="---------"
goback="Back"

# Checks if bluetooth controller is powered on
power_on() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        return 0
    else
        return 1
    fi
}

# Toggles power state
toggle_power() {
    if power_on; then
        bluetoothctl power off
        show_menu
    else
        if rfkill list bluetooth | grep -q 'blocked: yes'; then
            rfkill unblock bluetooth && sleep 3
        fi
        bluetoothctl power on
        show_menu
    fi
}

# Checks if controller is scanning for new devices
scan_on() {
    if bluetoothctl show | grep -q "Discovering: yes"; then
        echo "  Stop scan"
        return 0
    else
        echo "󰐷  Start scan"
        return 1
    fi
}

# Toggles scanning state
toggle_scan() {
    if scan_on; then
        kill $(pgrep -f "bluetoothctl scan on")
        bluetoothctl scan off
        show_menu
    else
        bluetoothctl scan on &
        echo "Scanning..."
        sleep 5
        show_menu
    fi
}

# Checks if controller is able to pair to devices
pairable_on() {
    if bluetoothctl show | grep -q "Pairable: yes"; then
        echo "Pairable: on"
        return 0
    else
        echo "Pairable: off"
        return 1
    fi
}

# Toggles pairable state
toggle_pairable() {
    if pairable_on; then
        bluetoothctl pairable off
        show_menu
    else
        bluetoothctl pairable on
        show_menu
    fi
}

# Checks if controller is discoverable by other devices
discoverable_on() {
    if bluetoothctl show | grep -q "Discoverable: yes"; then
        echo "Discoverable: on"
        return 0
    else
        echo "Discoverable: off"
        return 1
    fi
}

# Toggles discoverable state
toggle_discoverable() {
    if discoverable_on; then
        bluetoothctl discoverable off
        show_menu
    else
        bluetoothctl discoverable on
        show_menu
    fi
}

# Checks if a device is connected
device_connected() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Disconnect"; then
        return 0
    else
        return 1
    fi
}

# Toggles device connection
toggle_connection() {
    echo -e 'agent on\ndefault-agent\nquit' | bluetoothctl //test
    if device_connected "$1"; then
        bluetoothctl disconnect "$1"
        device_menu "$device"
    else
        bluetoothctl conn
        ect "$1"
        device_menu "$device"
    fi
}

# Checks if a device is paired
device_paired() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Paired: yes"; then
        echo "Unpair"
        return 0
    else
        echo "Pair"
        return 1
    fi
}

# Toggles device paired state
toggle_paired() {
    echo -e 'agent on\ndefault-agent\nquit' | bluetoothctl //test
    if device_paired "$1"; then
        bluetoothctl remove "$1"
        device_menu "$device"
    else
        bluetoothctl pair "$1"
        device_menu "$device"
    fi
}

# Checks if a device is trusted
device_trusted() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Trusted: yes"; then
        echo "Distrust"
        return 0
    else
        echo "Trust"
        return 1
    fi
}

# Toggles device connection
toggle_trust() {
    if device_trusted "$1"; then
        bluetoothctl untrust "$1"
        device_menu "$device"
    else
        bluetoothctl trust "$1"
        device_menu "$device"
    fi
}

# Prints a short string with the current bluetooth status
# Useful for status bars like polybar, etc.
print_status() {
    if power_on; then
        printf ''

        paired_devices_cmd="devices Paired"
        # Check if an outdated version of bluetoothctl is used to preserve backwards compatibility
        if (( $(echo "$(bluetoothctl version | cut -d ' ' -f 2) < 5.65" | bc -l) )); then
            paired_devices_cmd="paired-devices"
        fi

        mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | grep Device | cut -d ' ' -f 2)
        counter=0

        for device in "${paired_devices[@]}"; do
            if device_connected "$device"; then
                device_alias=$(bluetoothctl info "$device" | grep "Alias" | cut -d ' ' -f 2-)

                if [ $counter -gt 0 ]; then
                    printf ", %s" "$device_alias"
                else
                    printf " %s" "$device_alias"
                fi

                ((counter++))
            fi
        done
        printf "\n"
    else
        echo ""
    fi
}

# A submenu for a specific device that allows connecting, pairing, and trusting
device_menu() {
    device=$1

    # Get device name and mac address
    device_name=$(echo "$device" | cut -d ' ' -f 3-)
    mac=$(echo "$device" | cut -d ' ' -f 2)

    # Build options
    if device_connected "$mac"; then
        connected="Disconnect"
    else
        connected="Connect"
    fi
    paired=$(device_paired "$mac")
    trusted=$(device_trusted "$mac")
    #options="$connected\n$paired\n$trusted\n$goback\nExit"
    options="$connected\n$paired\n$trusted\n$goback"

    # Open rofi menu, read chosen option
    chosen="$(echo -e "$options" | rofi -dmenu -p "$device_name" -theme-str '@import "wifi.rasi"')"


    # Match chosen option to command
    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$connected")
            toggle_connection "$mac"
            ;;
        "$paired")
            toggle_paired "$mac"
            ;;
        "$trusted")
            toggle_trust "$mac"
            ;;
        "$goback")
            show_menu
            ;;
    esac
}

# Opens a rofi menu with current bluetooth status and options to connect
show_menu() {
    # Get menu options
    if power_on; then
        power="󰂲  Disable Bluetooth"

        # Fetch all devices
        mapfile -t all_devices < <(bluetoothctl devices | awk '{print $2}') # Get MAC addresses
        devices="" # Initialize empty string for devices

        for mac in "${all_devices[@]}"; do
            device_info=$(bluetoothctl info "$mac")
            # Extract device name; fallback to MAC address if no name is present
            device_name=$(echo "$device_info" | grep "Name" | cut -d ' ' -f 2-)
            if [ -z "$device_name" ]; then
                device_name=$mac  # Use MAC address if no name is found
            fi
            
            paired=$(echo "$device_info" | grep -q "Paired: yes" && echo "true" || echo "false")

            # Prepend "NEW" to unpaired devices, "PAI" to paired devices
            if [ "$paired" == "false" ]; then
                devices+="  $device_name\n"
            else
                devices+="  $device_name\n"
            fi
        done

        # Get controller flags
        scan=$(scan_on)
        pairable=$(pairable_on)
        discoverable=$(discoverable_on)

        # Options passed to rofi
        options="$power\n$scan\n$devices"
    else
        power="󰂯  Enable Bluetooth"
        options="$power\nExit"
    fi

    # Open rofi menu, read chosen option
    chosen="$(echo -e "$options" | rofi -dmenu -p "Bluetooth" -theme-str '@import "wifi.rasi"')"

    # Match chosen option to command
    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$power")
            toggle_power
            ;;
        "$scan")
            toggle_scan
            ;;
        "$discoverable")
            toggle_discoverable
            ;;
        "$pairable")
            toggle_pairable
            ;;
        *)
            # Extract the label (NEW/PAI + name/MAC) to find the device
            label=$(echo "$chosen" | sed -e 's/^ //g' -e 's/^ //g')
            device=$(bluetoothctl devices | grep -F "$label" | awk '{print "Device " $2}')
            # This assumes label (device name or MAC) is enough to uniquely identify the device in `bluetoothctl devices` output
            # Open a submenu if a device is selected
            if [[ $device ]]; then device_menu "$device"; fi
            ;;
    esac
}

case "$1" in
    --status)
        print_status
        ;;
    *)
        show_menu
        ;;
esac
