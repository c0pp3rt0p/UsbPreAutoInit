import Cocoa
import Security

class UninstallerWindowController: NSWindowController {
    // UI Components
    private var statusLabel: NSTextField!
    private var uninstallButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var iconView: NSImageView!

    // Paths to remove
    private let daemonPath = "/usr/local/bin/usbpre_monitor_daemon"
    private let plistPath = "/Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist"
    private let logPath = "/var/log/usbpre_monitor.log"
    private let packageID = "com.sounddevices.usbpre.monitor"

    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Uninstall USBPre Auto-Init"
        window.center()

        super.init(window: window)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Icon
        iconView = NSImageView(frame: NSRect(x: 20, y: 180, width: 64, height: 64))
        iconView.image = NSImage(named: NSImage.cautionName)
        contentView.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: "Uninstall USBPre Auto-Init")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.frame = NSRect(x: 100, y: 220, width: 330, height: 24)
        contentView.addSubview(titleLabel)

        // Description
        let descLabel = NSTextField(labelWithString: "This will remove the USBPre monitor daemon from your system.\n\nThe daemon will no longer automatically initialize your USBPre device when plugged in.")
        descLabel.isEditable = false
        descLabel.isBordered = false
        descLabel.backgroundColor = .clear
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.frame = NSRect(x: 100, y: 140, width: 330, height: 60)
        contentView.addSubview(descLabel)

        // Files to be removed label
        let filesLabel = NSTextField(labelWithString: "Files to be removed:")
        filesLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        filesLabel.frame = NSRect(x: 20, y: 110, width: 410, height: 16)
        contentView.addSubview(filesLabel)

        // File list
        let fileList = NSTextField(labelWithString: "• \(daemonPath)\n• \(plistPath)\n• \(logPath)\n• Package receipt")
        fileList.isEditable = false
        fileList.isBordered = false
        fileList.backgroundColor = .clear
        fileList.font = NSFont.systemFont(ofSize: 10)
        fileList.lineBreakMode = .byWordWrapping
        fileList.frame = NSRect(x: 30, y: 30, width: 400, height: 70)
        contentView.addSubview(fileList)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.textColor = .systemBlue
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 20, y: 50, width: 410, height: 20)
        contentView.addSubview(statusLabel)

        // Progress indicator
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 195, y: 30, width: 60, height: 20))
        progressIndicator.style = .spinning
        progressIndicator.isHidden = true
        contentView.addSubview(progressIndicator)

        // Uninstall button
        uninstallButton = NSButton(frame: NSRect(x: 330, y: 12, width: 100, height: 32))
        uninstallButton.title = "Uninstall"
        uninstallButton.bezelStyle = .rounded
        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallClicked(_:))
        contentView.addSubview(uninstallButton)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 230, y: 12, width: 90, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked(_:))
        contentView.addSubview(cancelButton)
    }

    @objc private func uninstallClicked(_ sender: Any) {
        // Confirm with user
        let alert = NSAlert()
        alert.messageText = "Uninstall USBPre Auto-Init?"
        alert.informativeText = "This will remove the monitor daemon. You'll need to manually initialize your USBPre device after unplugging it."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response != .alertFirstButtonReturn {
            return
        }

        // Disable button and show progress
        uninstallButton.isEnabled = false
        statusLabel.stringValue = "Requesting authorization..."
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        // Perform uninstall
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performUninstall()

                DispatchQueue.main.async {
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                    self.showSuccess()
                }
            } catch {
                DispatchQueue.main.async {
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                    self.uninstallButton.isEnabled = true
                    self.statusLabel.stringValue = ""
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func cancelClicked(_ sender: Any) {
        NSApp.terminate(nil)
    }

    private func performUninstall() throws {
        // Update status
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "Stopping daemon..."
        }

        // Stop daemon
        try runWithAdmin("/bin/launchctl", args: ["unload", plistPath])

        sleep(1)

        // Remove files
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "Removing files..."
        }

        try runWithAdmin("/bin/rm", args: ["-f", plistPath])
        try runWithAdmin("/bin/rm", args: ["-f", daemonPath])
        try runWithAdmin("/bin/rm", args: ["-f", logPath])

        // Forget package receipt
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "Removing package receipt..."
        }

        try runWithAdmin("/usr/sbin/pkgutil", args: ["--forget", packageID])
    }

    private func runWithAdmin(_ command: String, args: [String]) throws {
        // Build the full command
        let fullCommand = ([command] + args)
            .map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
            .joined(separator: " ")

        // Use osascript to run with administrator privileges
        let script = "do shell script \"\(fullCommand)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "UninstallerError",
                         code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to execute: \(command)\n\(errorMessage)"])
        }
    }

    private func showSuccess() {
        statusLabel.stringValue = "Successfully uninstalled!"
        statusLabel.textColor = .systemGreen

        let alert = NSAlert()
        alert.messageText = "Uninstallation Complete"
        alert.informativeText = "USBPre Auto-Init has been successfully removed from your system.\n\nYou can now close this window."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()

        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Uninstallation Failed"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
