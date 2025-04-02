#!/bin/bash
set -e

#
#based on instructions https://github.com/rocketcrane/Pi-Floppy
#based on article at https://magpi.raspberrypi.com/articles/pi-zero-w-smart-usb-flash-drive
#

# Pre-requisites:
# 1. Raspberry Pi OS (Bullseye) flashed using Pi Imager
# 2. SSH enabled and WiFi configured
# 3. Run this script with sudo

usage() {

    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --floppy             Download a preformatted image to work with GoTek Floppy emulator"
    echo ""
    echo "Pre-requisite:"
    echo " 1. Raspberry Pi OS (Bullseye lite) flashed using Pi Imager"
    echo " 3. Run this script with sudo"

    exit 1
}

# Check for Raspberry Pi OS Bullseye
echo "Checking OS version..."
if ! grep -q "VERSION_ID=\"11\"" /etc/os-release; then
    echo "Error: This script requires Raspberry Pi OS Bullseye."
    echo "Exiting..."
    exit 1
fi
echo "Raspberry Pi OS Bullseye detected. Proceeding..."

while [[ $# -gt 0 ]]; do
    case $1 in
        --floppy)
            FLOPPY=true
            shift
            ;;
        --samba)
            if [[ -z $2 ]]; then
                echo "Missing share name for Samba"
                usage
            fi
            SAMBA_SHARE=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Step 2: Configure USB driver
echo "Configuring USB driver..."
echo "dtoverlay=dwc2" | sudo tee -a /boot/config.txt
echo "dwc2" | sudo tee -a /etc/modules

# Step 3: Create container file
echo "Creating container file..."
if [[ $FLOPPY ]]; then
    echo "Downloading okuma_usb.bin..."
    sudo wget -O /piflop.bin https://cncpi.s3.us-west-2.amazonaws.com/okuma_usb.bin
else
    sudo dd bs=1M if=/dev/zero of=/piflop.bin count=256
    sudo mkdosfs /piflop.bin -F 32 -I
fi

# Step 4: Set up USB floppy device
echo "Configuring automatic mass storage..."
if [[ ! -f /etc/rc.local ]]; then
    sudo bash -c 'cat > /etc/rc.local << EOF
#!/bin/bash
sudo modprobe g_mass_storage file=/piflop.bin stall=0 ro=0 removable=1
exit 0
EOF'
    sudo chmod +x /etc/rc.local
else
    sudo sed -i '/exit 0/i sudo modprobe g_mass_storage file=/piflop.bin stall=0 ro=0 removable=1' /etc/rc.local
fi

# Step 5: Mount container file
echo "Setting up filesystem mount..."
sudo mkdir -p /mnt/floppy
echo "/piflop.bin /mnt/floppy auto users,umask=000 0 2" | sudo tee -a /etc/fstab
sudo mount -a

# Step 6: Automate device reconnect
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip
sudo pip3 install watchdog

echo "Configuring watchdog service..."
sudo wget -O /usr/local/share/usbshare.py http://rpf.io/usbzw
sudo chmod +x /usr/local/share/usbshare.py

# Modify script parameters
sudo sed -i 's|CMD_MOUNT =.*|CMD_MOUNT = "modprobe g_mass_storage file=/piflop.bin stall=0 ro=0 removable=1"|' /usr/local/share/usbshare.py
sudo sed -i 's|WATCH_PATH =.*|WATCH_PATH = "/mnt/floppy"|' /usr/local/share/usbshare.py
sudo sed -i 's|ACT_TIME_OUT =.*|ACT_TIME_OUT = 2|' /usr/local/share/usbshare.py

# Create systemd service
sudo bash -c 'cat > /etc/systemd/system/usbshare.service << EOF
[Unit]
Description=USB Share Watchdog
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/share/usbshare.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable usbshare.service
sudo systemctl start usbshare.service


echo "Configuring Samba share..."
sudo apt-get install -y samba
sudo bash -c "cat >> /etc/samba/smb.conf << EOF
[usbfloppy]
   browseable = yes
   path = /mnt/floppy
   guest ok = yes
   read only = no
   create mask = 777
EOF"

sudo systemctl restart smbd




echo "Setup complete! Please restart your Raspberry Pi to apply all changes."
echo "You can do this by running the following command:"
echo "  sudo reboot"
echo "Or, you can manually power off and then power on again."
