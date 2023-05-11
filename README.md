# wh1000-connect - dealing with the BT connection issues.

On my Oracle Linux machine, connecting to the Sony wh1000 headset via the settings UI is annoying, sometimes it enters the low quality headset mode, sometimes it plainly doesn't connect. Also, there appear to be two volume controls for the WH, one is remembered on the headset, Windows, Android and Fedora machines that I have set this volume when moving the volume sliders, Oracle Linux doesn't. So I have to tap it out on the physical touch controls, lame-o...
Instead of fixing the issue properly, I applied some duct tape:
1) The script first checks whether the MAC provided as the argument is connected via `hcitool con` output.
2) If connected, get the proper DBUS object for volume settings.
3) Sets the volume to 100, this is not the max, seems like it's 127, however, I read it's possible to set it too high and get some distortion, yuck, don't wanna deal with that. 100 is fine, it's fine!
4) Use pulse audio to detect the output sink for our mac address and then set this sink to be the default one.

Classic disclaimer:
It works on my machine! (i.e. I didn't test it anywhere else and it's probably broken AF)

Usage:

Download the file, store it somewhere, perhaps in your home dir, add execute permissions:

`chmod +x ~/wh1000-connect/wh1000-connect.sh`

I use an alias for running it, put something like this in your .bashrc:

`alias whc='~/wh1000-connect/wh1000-connect.sh 2D:E6:B0:De:7F:96'`

To figure out the MAC address for your headset, you can copy it from the Settings UI, or just run `hcitool con`.
