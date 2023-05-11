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

function set_volume {
    echo "Setting HW volume to ${VOLUME}..."
    dbus-send --system --print-reply --dest=org.bluez "${DEVICE_PATH}" org.freedesktop.DBus.Properties.Set string:"org.bluez.MediaTransport1" string:"Volume" variant:uint16:"${VOLUME}";
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
    DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d/fd\d" | cut -d '"' -f2)
    while [ -z "${DEVICE_PATH}" ]; do
        echo "Couldn't find dbus object, wait and retry..."
        sleep 2

        if ! headset_connected ; then
            echo "Headset disconnected in the middle of this operation, check power on and then retry script!"
            exit 1
        fi

        DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d/fd\d" | cut -d '"' -f2)
    done
}

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
