#!/bin/sh
# ============================================
# FamDash Kiosk Setup Script for Alpine Linux
# Run as root after fresh setup-alpine
# ============================================

KIOSK_USER="kiosk"
FAMDASH_URL="https://your-famdash-url"  # <-- Change this

set -e

echo ">>> Enabling community repo..."
ALPINE_VER=$(cat /etc/alpine-release | cut -d'.' -f1,2)
sed -i "s|#.*community|https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community|" /etc/apk/repositories

echo ">>> Updating packages..."
apk update && apk upgrade

echo ">>> Installing basics..."
apk add bash curl nano

echo ">>> Installing Xorg + Openbox..."
apk add \
  xorg-server \
  xf86-video-fbdev \
  xf86-input-evdev \
  xf86-input-libinput \
  openbox \
  xinit \
  xterm \
  xset

echo ">>> Installing Chromium..."
apk add chromium

echo ">>> Installing elogind + polkit..."
apk add elogind polkit
rc-update add elogind default
rc-service elogind start || true

echo ">>> Installing eudev (device manager)..."
apk add eudev
rc-update add udev default
rc-update add udev-trigger default
rc-update add udev-settle default

echo ">>> Setting up kiosk user..."
if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  adduser -D "$KIOSK_USER"
fi

adduser "$KIOSK_USER" video
adduser "$KIOSK_USER" input
adduser "$KIOSK_USER" tty

echo ">>> Setting Xorg setuid..."
chmod u+s /usr/bin/Xorg

echo ">>> Creating Openbox autostart..."
mkdir -p /home/$KIOSK_USER/.config/openbox
cat > /home/$KIOSK_USER/.config/openbox/autostart << EOF
# Prevent sleep and screen blanking
xset s off
xset -dpms
xset s noblank

# Launch FamDash in kiosk mode
chromium-browser --kiosk --no-sandbox --disable-infobars \
  --disable-session-crashed-bubble \
  --app=${FAMDASH_URL} &
EOF

echo ">>> Creating .xinitrc..."
cat > /home/$KIOSK_USER/.xinitrc << EOF
exec openbox-session
EOF

echo ">>> Creating .profile auto-startx..."
cat > /home/$KIOSK_USER/.profile << EOF
[ \$(tty) = /dev/tty1 ] && startx -- vt1
EOF

echo ">>> Setting correct ownership..."
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

echo ">>> Configuring auto-login on tty1..."
sed -i "s|tty1::respawn:.*|tty1::respawn:/bin/login -f $KIOSK_USER|" /etc/inittab

echo ">>> Installing WiFi watchdog..."
cat > /usr/local/bin/wifi-watchdog.sh << 'WATCHDOG'
#!/bin/sh
LOG=/var/log/wifi-watchdog.log
MAX_LINES=100
IFACE=wlan0
TEST_IP=1.1.1.1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> $LOG
}

trim_log() {
    if [ $(wc -l < $LOG) -gt $MAX_LINES ]; then
        tail -n $MAX_LINES $LOG > $LOG.tmp && mv $LOG.tmp $LOG
    fi
}

if ! ping -c 3 -W 2 $TEST_IP > /dev/null 2>&1; then
    log "--- Connectivity lost to $TEST_IP ---"
    log "IP status: $(ip addr show $IFACE | grep inet)"
    log "Gateway: $(ip route | grep default)"
    log "WiFi link: $(iw dev $IFACE link 2>&1 | grep -E 'SSID|signal|freq')"
    log "WPA status: $(wpa_cli -i $IFACE status 2>&1 | grep -E 'wpa_state|ssid|ip')"
    log "Attempting soft fix..."
    /sbin/rc-service wpa_supplicant restart
    sleep 10
    /sbin/udhcpc -i $IFACE > /dev/null 2>&1
    sleep 5
    if ! ping -c 3 -W 2 $TEST_IP > /dev/null 2>&1; then
        log "Soft fix failed. Rebooting..."
        /sbin/reboot
    else
        log "Soft fix worked. Connectivity restored."
    fi
else
    log "OK | $(iw dev $IFACE link 2>&1 | grep -E 'signal|freq' | tr '\n' ' ')"
fi

trim_log
WATCHDOG
chmod +x /usr/local/bin/wifi-watchdog.sh

echo ">>> Setting up WiFi watchdog cron..."
echo "*/10 * * * * /usr/local/bin/wifi-watchdog.sh" >> /etc/crontabs/root
rc-update add crond default

echo ">>> Enabling local services..."
rc-update add local default

echo ""
echo "============================================"
echo " Kiosk setup complete!"
echo " Edit FAMDASH_URL in this script before use."
echo " Rebooting in 5 seconds..."
echo "============================================"
sleep 5
reboot
