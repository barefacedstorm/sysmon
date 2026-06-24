#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================================================="
echo "      "CPU Graph & Memory Monitor Installer (XFCE)"
echo "========================================================="

# 1. Desktop Environment Check
if [ "$XDG_CURRENT_DESKTOP" != "XFCE" ] && ! pgrep -x xfce4-panel >/dev/null; then
    echo "ERROR: This installer only supports the XFCE desktop environment."
    exit 1
fi

# 2. Distro Detection and Dependency Installation
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
else
    OS_NAME="Unknown Linux Distro"
fi

echo "Detected Operating System: $OS_NAME"

INSTALL_CMD=""
if command -v apt-get >/dev/null 2>&1; then
    INSTALL_CMD="sudo apt-get update && sudo apt-get install -y xfce4-cpugraph-plugin xfce4-systemload-plugin"
elif command -v dnf >/dev/null 2>&1; then
    INSTALL_CMD="sudo dnf install -y xfce4-cpugraph-plugin xfce4-systemload-plugin"
elif command -v pacman >/dev/null 2>&1; then
    INSTALL_CMD="sudo pacman -Sy --noconfirm xfce4-cpugraph-plugin xfce4-systemload-plugin"
else
    echo "WARNING: Unknown package manager. Please ensure xfce4-cpugraph-plugin and xfce4-systemload-plugin are installed manually."
fi

if [ -n "$INSTALL_CMD" ]; then
    echo "Installing required panel plugins..."
    eval "$INSTALL_CMD"
fi

# 3. Check for xfconf-query
if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "ERROR: xfconf-query is required to modify panel settings but is not installed."
    exit 1
fi

echo "Configuring XFCE panel..."

# Get current plugin-ids array
CURRENT_IDS=$(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null || true)

if [ -z "$CURRENT_IDS" ]; then
    echo "ERROR: Could not read /panels/panel-1/plugin-ids. Is your XFCE panel running?"
    exit 1
fi

# Convert CURRENT_IDS to a clean list of numbers
IDS_LIST=$(echo "$CURRENT_IDS" | grep -E '^[0-9]+$' || true)
if [ -z "$IDS_LIST" ]; then
    IDS_LIST=$(echo "$CURRENT_IDS" | tr '\n' ' ' | sed -E 's/[^0-9 ]//g' | tr -s ' ')
fi

# Read into an array
read -r -a ids_arr <<< "$IDS_LIST"
echo "Current active panel plugin IDs: ${ids_arr[*]}"

# Find if CPU graph and System load are already defined
CPU_GRAPH_ID=""
SYSTEM_LOAD_ID=""

ALL_PLUGINS=$(xfconf-query -c xfce4-panel -p /plugins -l 2>/dev/null || true)

# Loop over plugins to find matching types
while read -r line; do
    if [[ "$line" =~ ^/plugins/plugin-([0-9]+)$ ]]; then
        id="${BASH_REMATCH[1]}"
        val=$(xfconf-query -c xfce4-panel -p "$line" 2>/dev/null || true)
        if [ "$val" = "cpugraph" ]; then
            CPU_GRAPH_ID="$id"
        elif [ "$val" = "systemload" ]; then
            SYSTEM_LOAD_ID="$id"
        fi
    fi
done <<< "$ALL_PLUGINS"

# If not found, assign new IDs based on maximum found ID (avoiding high values reserved for actions)
MAX_ID=0
while read -r line; do
    if [[ "$line" =~ ^/plugins/plugin-([0-9]+) ]]; then
        id="${BASH_REMATCH[1]}"
        if [ "$id" -gt "$MAX_ID" ] && [ "$id" -lt 1000 ]; then
            MAX_ID="$id"
        fi
    fi
done <<< "$ALL_PLUGINS"

if [ -z "$CPU_GRAPH_ID" ]; then
    CPU_GRAPH_ID=$((MAX_ID + 1))
    echo "Registering CPU Graph plugin with ID $CPU_GRAPH_ID..."
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$CPU_GRAPH_ID" -n -t string -s "cpugraph"
    MAX_ID=$CPU_GRAPH_ID
fi

if [ -z "$SYSTEM_LOAD_ID" ]; then
    SYSTEM_LOAD_ID=$((MAX_ID + 1))
    echo "Registering System Load plugin with ID $SYSTEM_LOAD_ID..."
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$SYSTEM_LOAD_ID" -n -t string -s "systemload"
fi

# Configure System Load plugin (enable Memory, disable CPU/Swap/Uptime to keep it clean)
echo "Configuring System Load settings..."
xfconf-query -c xfce4-panel -p "/plugins/plugin-$SYSTEM_LOAD_ID/cpu-enabled" -n -t bool -s false
xfconf-query -c xfce4-panel -p "/plugins/plugin-$SYSTEM_LOAD_ID/memory-enabled" -n -t bool -s true
xfconf-query -c xfce4-panel -p "/plugins/plugin-$SYSTEM_LOAD_ID/swap-enabled" -n -t bool -s false
xfconf-query -c xfce4-panel -p "/plugins/plugin-$SYSTEM_LOAD_ID/uptime-enabled" -n -t bool -s false

# Find the systray plugin ID to insert our new widgets right before it (matching standard Kali layout)
SYSTRAY_ID=""
while read -r line; do
    if [[ "$line" =~ ^/plugins/plugin-([0-9]+)$ ]]; then
        id="${BASH_REMATCH[1]}"
        val=$(xfconf-query -c xfce4-panel -p "$line" 2>/dev/null || true)
        if [ "$val" = "systray" ]; then
            SYSTRAY_ID="$id"
        fi
    fi
done <<< "$ALL_PLUGINS"

# Build new active plugins list
new_ids=()
added_cpugraph=false
added_systemload=false

in_array_cpu=false
in_array_sys=false
for item in "${ids_arr[@]}"; do
    if [ "$item" -eq "$CPU_GRAPH_ID" ]; then
        in_array_cpu=true
    fi
    if [ "$item" -eq "$SYSTEM_LOAD_ID" ]; then
        in_array_sys=true
    fi
done

if $in_array_cpu && $in_array_sys; then
    echo "Plugins are already active in the panel layout."
else
    # Insert new plugins before the status/system tray
    for item in "${ids_arr[@]}"; do
        if [ -n "$SYSTRAY_ID" ] && [ "$item" -eq "$SYSTRAY_ID" ]; then
            if ! $in_array_cpu && ! $added_cpugraph; then
                new_ids+=("$CPU_GRAPH_ID")
                added_cpugraph=true
            fi
            if ! $in_array_sys && ! $added_systemload; then
                new_ids+=("$SYSTEM_LOAD_ID")
                added_systemload=true
            fi
        fi
        
        if [ "$item" -ne "$CPU_GRAPH_ID" ] && [ "$item" -ne "$SYSTEM_LOAD_ID" ]; then
            new_ids+=("$item")
        fi
    done

    # Fallback if no system tray was found
    if [ "${#new_ids[@]}" -eq 0 ] || [ "${#new_ids[@]}" -le "${#ids_arr[@]}" ]; then
        new_ids=()
        for item in "${ids_arr[@]}"; do
            if [ "$item" -ne "$CPU_GRAPH_ID" ] && [ "$item" -ne "$SYSTEM_LOAD_ID" ]; then
                new_ids+=("$item")
            fi
        done
        new_ids+=("$CPU_GRAPH_ID" "$SYSTEM_LOAD_ID")
    fi

    # Set new array in Xfconf
    QUERY_CMD="xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids"
    for item in "${new_ids[@]}"; do
        QUERY_CMD="$QUERY_CMD -t int -s $item"
    done
    
    echo "Updating active panel plugin IDs..."
    eval "$QUERY_CMD"
fi

echo "Restarting XFCE panel to apply changes..."
xfce4-panel -r

echo "========================================================="
echo "  SUCCESS: CPU Graph & Memory Monitor are now on your bar!"
echo "========================================================="
