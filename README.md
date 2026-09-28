# FamDash Kiosk — Alpine Linux Setup

A lightweight kiosk setup for displaying [FamDash](https://famdash.app) on Alpine Linux using Chromium and Openbox.

---

## Requirements

- Alpine Linux 3.24+ (x86_64)
- Fresh `setup-alpine` install to disk (sys mode)
- Internet connection (ethernet recommended for initial setup)
- Root access

---

## Quick Install

```bash
wget https://raw.githubusercontent.com/MaxTheTechy/kiosk/main/kiosk-setup.sh
chmod +x kiosk-setup.sh
nano kiosk-setup.sh  # Edit KIOSK_USER and FAMDASH_URL at the top
./kiosk-setup.sh
```

The script will install everything and reboot automatically.

---

## What the Script Does

| Step | Action |
|------|--------|
| 1 | Enables Alpine community repo |
| 2 | Updates packages |
| 3 | Installs Xorg, Openbox, Chromium |
| 4 | Installs elogind, polkit, eudev |
| 5 | Creates kiosk user and adds to correct groups |
| 6 | Configures Chromium kiosk autostart |
| 7 | Disables screen sleep/blanking |
| 8 | Configures auto-login on tty1 |
| 9 | Installs WiFi watchdog (runs every 10 min) |
| 10 | Reboots |

---

## Configuration

Edit these two variables at the top of `kiosk-setup.sh` before running:

```sh
KIOSK_USER="kiosk"           # Local user account name
FAMDASH_URL="https://your-famdash-url"  # Your FamDash instance URL
```

---

## WiFi Setup

After the script runs, configure WiFi:

```bash
nano /etc/wpa_supplicant/wpa_supplicant.conf
```

```
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=wheel
ap_scan=1

network={
    ssid="YourSSID"
    psk="YourPassword"
    bgscan="simple:30:-70:300"
}
```

Then:
```bash
rc-service wpa_supplicant restart
udhcpc -i wlan0
```

---

## WiFi Watchdog

The watchdog script runs every 10 minutes and:
- Pings `1.1.1.1` to test connectivity
- Logs diagnostics if connection is lost
- Attempts a soft fix (restarts wpa_supplicant)
- Reboots if the soft fix fails

**Log location:** `/var/log/wifi-watchdog.log`

```bash
# View log
cat /var/log/wifi-watchdog.log

# Run manually
/usr/local/bin/wifi-watchdog.sh
```

---

## Useful Commands

```bash
# Kill Chromium (via SSH)
pkill chromium

# Kill X entirely
pkill Xorg

# Check WiFi status
ip addr show wlan0

# Check input devices
DISPLAY=:0 XAUTHORITY=/home/kiosk/.Xauthority xinput list

# Check kiosk user groups
groups kiosk
```

---

## Tested Hardware

| Hardware | Result |
|----------|--------|
| Intel J1800 (Unifi UVC-NVR) | ✅ Works great |
| Raspberry Pi 4 4GB | ⚠️ Works but slower |

---

## Known Issues

- **Realtek RTL8192EU WiFi dongles** — driver support is poor on Alpine. Use Ralink RT5370, Mediatek MT7601U, or Atheros AR9271 instead.
- **Touchscreen (ILITEK USB)** — requires `eudev` running for Xorg to detect input devices.

---

## License

MIT
