#!/bin/bash

MAC=$1

if [ -z "$MAC" ]; then
    echo "No MAC address provided. Usage: ./wh1000-connect <MAC_address>"
    exit 1
fi

VOLUME=127
MAC_UNDERSCORES=$(echo $MAC | tr  ":" _ )

function restart_pulse {
    echo "Restarting pulse audio..."
    pulseaudio -k
    sleep 2
    pulseaudio --start
    sleep 2
}

function restart_bluetooth {
    echo "Restarting bluetooth service..."
    sudo systemctl stop bluetooth
    sleep 2
    sudo systemctl start bluetooth
    sleep 2
}

function headset_connected {
    hcitool con | grep -P -q "$MAC.*state 1";
}

function connect_headset {
    echo "Running bluetoothctl connect..."
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
    return 1
}

function set_audio_sink {
    SINK=$(pactl list sinks | grep -P ".*$MAC_UNDERSCORES.*"  | grep -oP "(?<=Name: ).*")
    if [[ -z $SINK ]]; then
        echo "Headset $MAC not found in pulse audio, check connection!"
        return 1
    fi
    echo "Setting default audio sink to $SINK"
    pactl set-default-sink "$SINK"
}

function get_device_path {
    BLUEZ_REGEX="/org/bluez/hci0/dev_${MAC_UNDERSCORES}/sep\d+/fd\d+"
    DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "${BLUEZ_REGEX}" | cut -d '"' -f2)
    local retries=5;
    while [ -z "${DEVICE_PATH}" ]; do
        echo "Couldn't find dbus object, wait and retry..."
        sleep 2

        if ! headset_connected ; then
            echo "Headset disconnected in the middle of this operation, check power on and then retry script!"
            exit 1
        fi

        DEVICE_PATH=$(dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects | grep -P "${BLUEZ_REGEX}" | cut -d '"' -f2)
        retries=$((retries-1))
        if [ $retries -eq 0 ]; then
            return 1
        fi

    done
}

function connected_as_a2dp_sink {
    SINK_DESCRIPTION=$(pactl list sinks | grep -P -A1 ".*$MAC_UNDERSCORES.*" | grep -oP "(?<=Description: ).*")
    
    if [[ "$SINK_DESCRIPTION" == *"a2dp_sink"* ]]; then
        return 0
    fi
    return 1
}

function set_a2dp_sink {
    CARD_INDEX=$(pactl list cards short | grep "$MAC_UNDERSCORES" | cut -f1)

    if [ -z "$CARD_INDEX" ]; then
        echo "Could not find card index for Bluetooth device with MAC address $MAC_UNDERSCORES."
        return 1
    fi

    echo "Setting card profile for Bluetooth device with MAC address $MAC_UNDERSCORES, card index $CARD_INDEX to a2dp_sink..."
    pactl set-card-profile "$CARD_INDEX" a2dp_sink
}

function connect_and_set_up_wh1000 {
    if ! headset_connected; then
        local retries=5
	for ((i=0; i<retries; i++)); do
	    connect_headset
            sleep 2
	    if headset_connected; then
	        break
            fi
        done
    fi

    if ! headset_connected ; then
        echo "Failed to connect to headset!"
        return 1
    fi

    if ! connected_as_a2dp_sink && ! set_audio_sink; then
        echo "Failed to set audio sink!"
        return 1
    fi

    if ! get_device_path; then
        echo "Failed to get device path!"
        return 1
    fi

    if ! set_volume; then
        echo "Failed to set volume!"
        return 1
    fi
}

if ! connect_and_set_up_wh1000; then
    retries=5

    for ((i=0; i<retries; i++)); do
        echo "Attempt $((i+1))/$retries..."

        echo "Trying to recover..."

        if headset_connected; then
            echo "Disconnecting headset..."
            disconnect_headset
        fi

        restart_pulse

        if connect_and_set_up_wh1000; then
            echo "Connected successfully!"
            exit 0
        fi
    done

    echo "Restarting bluetooth..."
    restart_bluetooth
    sleep 5
    if connect_and_set_up_wh1000; then
        echo "Connected successfully!"
        exit 0
    fi
    echo "Failed to connect after $retries attempts. Please check the connection and try again."
    exit 1
fi

exit 0
