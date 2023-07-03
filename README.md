# wh1000-connect - dealing with the BT connection issues.

On my Oracle Linux machine, connecting to the Sony wh1000 headset via the settings UI is annoying, sometimes it enters the low quality headset mode, sometimes it plainly doesn't connect. Also, there appear to be two volume controls for the WH, one is remembered on the headset, Windows, Android and Fedora machines that I have set this volume when moving the volume sliders, Oracle Linux doesn't. So I have to tap it out on the physical touch controls, lame-o...
Instead of fixing the issue properly, I applied some duct tape:
1) The script first checks whether the MAC provided as the argument is connected via `hcitool con` output.
2) If connected, checks whether it's in a2dp mode
3) Switches to a2dp mode if needed.
4) Gets the proper DBUS object for volume settings.
5) Sets the volume to 127, this is the max. I've read that this can lead to some distortion on some devices, but it works for me.
6) Use pulse audio to detect the output sink for our mac address and then set this sink to be the default one.

Classic disclaimer:
It works on my machine! (i.e. I didn't test it anywhere else and it's probably broken AF)

Usage:

Download the file, store it somewhere, perhaps in your home dir, add execute permissions:

`chmod +x ~/wh1000-connect/wh1000-connect.sh`

I use an alias for running it, put something like this in your .bashrc:

`alias whc='~/wh1000-connect/wh1000-connect.sh 2D:E6:B0:De:7F:96'`

To figure out the MAC address for your headset, you can copy it from the Settings UI, or just run `hcitool con`.
