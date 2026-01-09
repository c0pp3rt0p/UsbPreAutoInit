# USBPre Auto-Init

Automatic initialization for Sound Devices USBPre audio interface on modern macOS.

## Why This Exists

The USBPre has two microcontrollers:

1. **UDA1335** - Handles USB audio. Works automatically via Apple's built-in USB Audio Class driver.
2. **PIC** - Controls buttons, LEDs, and phantom power. Powers up dormant and needs a wake-up call.

On modern macOS, audio works out of the box - Apple handles it. But the buttons, LEDs, and 48V phantom power control don't work until the PIC receives two USB vendor commands. This project sends those commands automatically.

## What It Does

- **Monitors USB events** - Detects when your USBPre is connected (at boot or hot-plugged)
- **Auto-initializes** - Sends the PIC wake-up sequence automatically
- **Runs in background** - Launch daemon starts at system boot
- **Transparent operation** - No manual intervention required

## Features

- ✅ Works with macOS 11.0 (Big Sur) and later
- ✅ Supports both Intel and Apple Silicon Macs
- ✅ Professional .pkg installer
- ✅ GUI uninstaller app
- ✅ Code signed and notarized (safe for all users)
- ✅ Zero configuration needed

## Requirements

- macOS 11.0 (Big Sur) or later
- Sound Devices USBPre (VID: 0x0926, PID: 0x0100)
- Administrator privileges (for installation only)

## Installation

### Easy Install (Recommended)

1. Download the latest `USBPreAutoInit-x.x.x.pkg` from [Releases](https://github.com/yourusername/USBPreAutoInit/releases)
2. Double-click the .pkg file
3. Follow the installation wizard
4. Done! Plug in your USBPre to test

The daemon starts automatically at boot and monitors for your device.

### Alternative: DMG Install

1. Download the latest `USBPreAutoInit-x.x.x.dmg`
2. Open the DMG and run the installer inside
3. Follow the installation wizard

## Usage

**No configuration needed!** After installation:

1. **Plug in your USBPre** - The device will initialize automatically within 1-2 seconds
2. **Use your audio software** - The device appears as a standard audio interface
3. **Unplug and replug** - Auto-initialization happens every time

### Verify Installation

Check if the daemon is running:

```bash
sudo launchctl list | grep usbpre
```

You should see: `com.sounddevices.usbpre.monitor`

View activity logs:

```bash
sudo tail -f /var/log/usbpre_monitor.log
```

## Manual Initialization (Alternative)

If you prefer not to install the daemon, you can use the CLI tool to initialize manually after plugging in:

```bash
# Build the CLI tool
cd Source/cli
gcc -o usbpre_init usbpre_init.c -framework IOKit -framework CoreFoundation

# Run after plugging in device
./usbpre_init
```

This is useful for one-off usage or testing.

## Uninstallation

### GUI Method (Recommended)

1. Go to **Applications → Utilities**
2. Run **Uninstall USBPre**
3. Click **Uninstall** and authenticate when prompted

### Manual Method

```bash
# Stop the daemon
sudo launchctl unload /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist

# Remove files
sudo rm /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
sudo rm /usr/local/bin/usbpre_monitor_daemon
sudo rm /var/log/usbpre_monitor.log

# Forget package receipt
sudo pkgutil --forget com.sounddevices.usbpre.monitor
```

## Troubleshooting

### Device Doesn't Initialize

1. **Check daemon status:**
   ```bash
   sudo launchctl list | grep usbpre
   ```

2. **Check logs:**
   ```bash
   sudo tail -50 /var/log/usbpre_monitor.log
   ```

3. **Restart daemon:**
   ```bash
   sudo launchctl unload /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
   sudo launchctl load /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
   ```

4. **Physically unplug and replug the device**

### Daemon Won't Start

- Verify file permissions:
  ```bash
  ls -l /usr/local/bin/usbpre_monitor_daemon
  ls -l /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
  ```

- Should show:
  ```
  -rwxr-xr-x  root  wheel  usbpre_monitor_daemon
  -rw-r--r--  root  wheel  com.sounddevices.usbpre.monitor.plist
  ```

- Fix permissions if needed:
  ```bash
  sudo chmod 755 /usr/local/bin/usbpre_monitor_daemon
  sudo chmod 644 /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
  sudo chown root:wheel /usr/local/bin/usbpre_monitor_daemon
  sudo chown root:wheel /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
  ```

### Still Having Issues?

1. Check Console.app for system messages
2. Review full logs: `/var/log/usbpre_monitor.log`
3. [Open an issue](https://github.com/yourusername/USBPreAutoInit/issues) with logs attached

## Technical Details

### What Gets Installed

- **Daemon binary:** `/usr/local/bin/usbpre_monitor_daemon`
- **Launch daemon:** `/Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist`
- **Uninstaller app:** `/Applications/Utilities/Uninstall USBPre.app`
- **Log file:** `/var/log/usbpre_monitor.log`

### How It Works

1. Launch daemon starts at boot
2. Registers IOKit notification for USB device arrival
3. Filters for USBPre (VID: 0x0926, PID: 0x0100)
4. Sends validated initialization sequence:
   - Command 1: Write `0x81` to register `0x00F0`
   - Wait 5 seconds
   - Command 2: Write `0xC0` to register `0x00F0`
5. Logs all activity to syslog and log file

### USB Initialization Protocol

The USBPre requires a specific two-command sequence discovered through Windows USB packet analysis:

```c
// Command 1
bmRequestType: 0x40 (Host-to-Device, Vendor, Device)
bRequest: 0x01
wValue: 0x00F0
wIndex: 0x01F0
Data: 0x81

// Wait 5 seconds

// Command 2
Same structure, Data: 0xC0
```

This sequence initializes the PIC microcontroller that manages the device.

## Building from Source

See [BUILDING.md](BUILDING.md) for developer documentation.

## License

MIT License - See [LICENSE](LICENSE)

## Author

Craig Carrier (2025)

## Contributing

Contributions welcome! In particular:

- **Linux support** - The USB commands are documented; a libusb implementation would be straightforward
- **Bug fixes and improvements**

To contribute:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly on your hardware
4. Submit a pull request

## Disclaimer

This is an unofficial third-party project, not affiliated with or endorsed by Sound Devices. Use at your own risk.
