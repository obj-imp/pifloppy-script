# pifloppy-script


Takes the instructions from https://github.com/rocketcrane/Pi-Floppy

and the tutorial at https://magpi.raspberrypi.com/articles/pi-zero-w-smart-usb-flash-drive

and scripts it all together to setup a Raspberry Pi Zero W to look like both a USB drive and a samba share at the same time. 

instructions:

1. flash the Pi with the Raspberry Pi Imager tool and the Bullseye 32-bit lite OS (found in the legacy OS section)
2. SSH into the Pi
3. `sudo wget https://raw.githubusercontent.com/obj-imp/pifloppy-script/refs/heads/main/cncpi.bash'
4. `sudo bash ./cncpi.bash`
