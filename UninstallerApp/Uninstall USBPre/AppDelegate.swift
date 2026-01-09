import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: UninstallerWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create and show main window
        windowController = UninstallerWindowController()
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)

        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
