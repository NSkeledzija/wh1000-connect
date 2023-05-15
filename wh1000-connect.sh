#!/bin/bash

MAC=$1

if [ -z "$MAC" ]; then
    echo "No MAC address provided. Usage: ./wh1000-connect <MAC_address>"
    exit 1
fi
VOLUME=100
MAC_UNDERSCORES=$(echo $MAC | tr  ":" _ )

function headset_connected {
    hcitool con | grep -P -q "$MAC.*state 1";
}

function connect_headset {
    echo "Headset not connected! Running bluetoothctl to connect..."
    echo -e "connect $MAC \nquit" | bluetoothctl
    echo "Done!"
}

function disconnect_headset {
    echo "Disconnecting from headset..."
    echo -e "disconnect $MAC \nquit" | bluetoothctl
    echo "Done!"
}

function set_volume {
    local retries=5

    for ((i=0; i<retries; i++)); do
        echo "Setting HW volume to ${VOLUME} on device path: ${DEVICE_PATH}"
        dbus-send --system --print-reply --dest=org.bluez "${DEVICE_PATH}" org.freedesktop.DBus.Properties.Set string:"org.bluez.MediaTransport1" string:"Volume" variant:uint16:"${VOLUME}";

        if [ $? -eq 0 ]; then
            echo "Volume set successfully!"
            return 0
        else
            echo "Failed to set volume. Retry $((i+1))/$retries..."
            sleep 2
        fi
    done

    echo "Failed to set volume after $retries attempts. Please check the connection and try again."
    exit 1
}

function set_audio_sink {
    SINK=$(pactl list sinks | grep -P ".*$MAC_UNDERSCORES.*"  | grep -oP "(?<=Name: ).*")
    if [[ -z $SINK ]]; then
        echo "Headset $MAC not found in pulse audio, check connection!"
        exit 1
    else
        echo "Setting default audio sink to $SINK"
        pactl set-default-sink "$SINK"
    fi
}

function get_device_path {
	BLUEZ_REGEX="/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d+/fd\d+"
    DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "${BLUEZ_REGEX}" | cut -d '"' -f2)
    while [ -z "${DEVICE_PATH}" ]; do
        echo "Couldn't find dbus object, wait and retry..."
        sleep 2

        if ! headset_connected ; then
            echo "Headset disconnected in the middle of this operation, check power on and then retry script!"
            exit 1
        fi

        DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "${BLUEZ_REGEX}" | cut -d '"' -f2)
    done
}

# We disconnect the headset first when running this script. Reasoning behind this is that sometimes
# when starting my laptop, it connects to WH1000 in headset mode, disconnecting it here and connecting again fixes it.
while headset_connected ; do
    disconnect_headset
    sleep 2
done

# Check if the device is connected
while ! headset_connected ; do
    connect_headset
    sleep 2
done

echo "Headset connected!"

get_device_path
set_volume
set_audio_sink

exit 0
