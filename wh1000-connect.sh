#!/bin/bash

MAC=$1
VOLUME=100

# Check if the device is connected

function headset_connected {
    hcitool con | grep -P -q "$MAC.*state 1";
}

# Check if the device is connected
while ! headset_connected ; do
    echo "Headset not connected! Running bluetoothctl to connect..."
    # Use bluetoothctl to connect
    echo -e "connect $MAC \nquit" | bluetoothctl
    echo "Done!"
    sleep 2
done

echo "Headset connected!"

MAC_UNDERSCORES=$(echo $MAC | tr  ":" _ ) 

# Get the full path of the SEP and FD that the headset connected to
DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d/fd\d" | cut -d '"' -f2)

while [ -z "${DEVICE_PATH}" ]
do
  echo "Couldn't find dbus object, wait and retry..."
  sleep 2

  if ! headset_connected ; then
    echo "Headset disconnected in the middle of this operation, check power on and then retry script!"
    exit 1
  fi

  DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d/fd\d" | cut -d '"' -f2)
done

echo "Setting HW volume to ${VOLUME}..."
dbus-send --system --print-reply --dest=org.bluez "${DEVICE_PATH}" org.freedesktop.DBus.Properties.Set string:"org.bluez.MediaTransport1" string:"Volume" variant:uint16:"${VOLUME}";

# Use pactl to find the sink for the Bluetooth device with the given MAC address
SINK=$(pactl list sinks | grep -P ".*$MAC_UNDERSCORES.*"  | grep -oP "(?<=Name: ).*")

if [[ -z $SINK ]]; then
  # The Bluetooth device is not connected or the sink could not be found
  echo "Headset $MAC not found in pulse audio, check connection!"
  exit 1
else
  # The Bluetooth device is connected and the sink was found
  echo "Setting default audio sink to $SINK"
  pactl set-default-sink "$SINK"
fi

exit 0
