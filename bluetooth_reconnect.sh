#!/bin/bash

RETRY_INTERVAL=7

# Function to restart the Bluetooth service in Batocera
function restart_bluetooth_service() {
  echo "$(date): Restarting Bluetooth via batocera-bluetooth..."
  /usr/bin/batocera-bluetooth disable
  sleep 2
  /usr/bin/batocera-bluetooth enable
  sleep 5
}

# Get the address of the active Bluetooth adapter
ADAPTER=$(hciconfig | awk '
  BEGIN {bd_address=""}
  /^hci[0-9]+:/ {adapter=$1; bd_address=""}
  /BD Address:/ {bd_address=$3}
  /UP RUNNING/ {print bd_address; exit}
')

if [ -z "$ADAPTER" ]; then
  echo "No active Bluetooth adapter found."
  exit 1
fi

echo "Active Bluetooth adapter: $ADAPTER"

while true; do
  # List paired devices (folders inside the adapter directory)
  PAIRED_DEVICES=$(ls -d /var/lib/bluetooth/"$ADAPTER"/[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F] 2>/dev/null | xargs -n1 basename)

  if [ -z "$PAIRED_DEVICES" ]; then
    echo "No paired devices found."
  fi

  echo "Enabling scan..."
  timeout 5 bluetoothctl scan on
  if [ $? -ne 0 ]; then
    echo "$(date): Timeout or failed to enable scan."
    restart_bluetooth_service
    continue
  fi

  sleep 5

  bluetoothctl scan off || echo "Failed to stop scan, this can be ignored."

  # List currently visible devices
  VISIBLE_DEVICES=$(bluetoothctl devices | awk '{print $2}')

  for MAC in $PAIRED_DEVICES; do
    if echo "$VISIBLE_DEVICES" | grep -Fxq "$MAC"; then
      echo "$(date): Attempting to reconnect $MAC..."
      bluetoothctl connect "$MAC"
    else
      echo "$(date): Device $MAC is not visible, skipping."
    fi
  done

  echo "Waiting $RETRY_INTERVAL seconds before next attempt..."
  sleep $RETRY_INTERVAL
done
