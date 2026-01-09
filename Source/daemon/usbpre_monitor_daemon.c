/*
 * USBPre Monitor Daemon
 *
 * Automatically detects and initializes Sound Devices USBPre when plugged in.
 * Runs as a Launch Daemon to handle both boot-time and hot-plug scenarios.
 *
 * Features:
 *   - Monitors for USBPre device arrival via IOKit notifications
 *   - Automatically runs PIC initialization sequence
 *   - Handles device unplug/replug
 *   - Logs all activity to system log
 *
 * Compile:
 *   gcc -o usbpre_monitor_daemon usbpre_monitor_daemon.c -framework IOKit -framework CoreFoundation
 *
 * Install:
 *   sudo cp usbpre_monitor_daemon /usr/local/bin/
 *   sudo cp com.sounddevices.usbpre.monitor.plist /Library/LaunchDaemons/
 *   sudo launchctl load /Library/LaunchDaemons/com.sounddevices.usbpre.monitor.plist
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <syslog.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>

#define USBPRE_VENDOR_ID  0x0926
#define USBPRE_PRODUCT_ID 0x0100

// Global flag to prevent multiple simultaneous initializations
static volatile int initialization_in_progress = 0;

typedef struct {
    IONotificationPortRef notifyPort;
    io_iterator_t addedIterator;
    CFRunLoopRef runLoop;
} MonitorContext;

/*
 * Send validated PIC initialization commands
 */
static IOReturn InitializePICController(IOUSBDeviceInterface **dev)
{
    IOReturn result;
    IOUSBDevRequest request;
    uint8_t data;

    syslog(LOG_NOTICE, "USBPre: Starting PIC initialization");

    // Command 1: Initialize PIC
    data = 0x81;
    request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    request.bRequest = 0x01;
    request.wValue = 0x00F0;
    request.wIndex = 0x01F0;
    request.wLength = 1;
    request.pData = &data;

    result = (*dev)->DeviceRequest(dev, &request);
    if (result != kIOReturnSuccess) {
        syslog(LOG_ERR, "USBPre: Command 1 failed: 0x%08x", result);
        return result;
    }

    syslog(LOG_INFO, "USBPre: Command 1 (0x81) succeeded");

    // Wait 5 seconds (as observed in Windows driver)
    sleep(5);

    // Command 2: Activate PIC
    data = 0xC0;
    request.wValue = 0x00F0;
    request.wIndex = 0x01F0;
    request.wLength = 1;
    request.pData = &data;

    result = (*dev)->DeviceRequest(dev, &request);
    if (result != kIOReturnSuccess) {
        syslog(LOG_ERR, "USBPre: Command 2 failed: 0x%08x", result);
        return result;
    }

    syslog(LOG_NOTICE, "USBPre: PIC initialization complete (Command 2: 0xC0)");
    return kIOReturnSuccess;
}

/*
 * Open device and send initialization commands
 */
static void InitializeUSBPreDevice(io_service_t device)
{
    IOCFPlugInInterface **plugInInterface = NULL;
    IOUSBDeviceInterface **deviceInterface = NULL;
    SInt32 score;
    IOReturn kr;

    // Prevent concurrent initialization
    if (initialization_in_progress) {
        syslog(LOG_INFO, "USBPre: Initialization already in progress, skipping");
        return;
    }
    initialization_in_progress = 1;

    syslog(LOG_INFO, "USBPre: Device detected, opening interface");

    // Create plugin interface
    kr = IOCreatePlugInInterfaceForService(device, kIOUSBDeviceUserClientTypeID,
                                          kIOCFPlugInInterfaceID, &plugInInterface, &score);
    if (kr != KERN_SUCCESS || !plugInInterface) {
        syslog(LOG_ERR, "USBPre: Failed to create plugin interface: 0x%08x", kr);
        initialization_in_progress = 0;
        return;
    }

    // Get device interface
    kr = (*plugInInterface)->QueryInterface(plugInInterface,
                                            CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                            (LPVOID *)&deviceInterface);
    (*plugInInterface)->Release(plugInInterface);

    if (kr != KERN_SUCCESS || !deviceInterface) {
        syslog(LOG_ERR, "USBPre: Failed to get device interface: 0x%08x", kr);
        initialization_in_progress = 0;
        return;
    }

    // Open device
    kr = (*deviceInterface)->USBDeviceOpen(deviceInterface);
    if (kr != kIOReturnSuccess) {
        syslog(LOG_ERR, "USBPre: Failed to open device: 0x%08x", kr);
        (*deviceInterface)->Release(deviceInterface);
        initialization_in_progress = 0;
        return;
    }

    // Send PIC initialization commands
    kr = InitializePICController(deviceInterface);

    // Clean up
    (*deviceInterface)->USBDeviceClose(deviceInterface);
    (*deviceInterface)->Release(deviceInterface);

    initialization_in_progress = 0;

    if (kr == kIOReturnSuccess) {
        syslog(LOG_NOTICE, "USBPre: Successfully initialized - device ready");
    } else {
        syslog(LOG_ERR, "USBPre: Initialization failed: 0x%08x", kr);
    }
}

/*
 * Callback when USBPre device is added
 */
static void DeviceAddedCallback(void *refcon, io_iterator_t iterator)
{
    io_service_t device;

    while ((device = IOIteratorNext(iterator))) {
        syslog(LOG_NOTICE, "USBPre: Device arrival detected");

        // Small delay to let macOS settle
        sleep(1);

        // Initialize the device
        InitializeUSBPreDevice(device);

        // Release this reference
        IOObjectRelease(device);
    }
}

/*
 * Setup IOKit notifications for device arrival
 */
static int SetupDeviceMonitoring(MonitorContext *ctx)
{
    CFMutableDictionaryRef matchingDict;
    IOReturn kr;

    // Create matching dictionary for USBPre
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        syslog(LOG_ERR, "USBPre: Failed to create matching dictionary");
        return -1;
    }

    // Add vendor and product ID
    SInt32 vendorID = USBPRE_VENDOR_ID;
    SInt32 productID = USBPRE_PRODUCT_ID;
    CFNumberRef vendorNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorID);
    CFNumberRef productNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productID);

    CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), vendorNum);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), productNum);

    CFRelease(vendorNum);
    CFRelease(productNum);

    // Create notification port
    ctx->notifyPort = IONotificationPortCreate(kIOMainPortDefault);
    ctx->runLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(ctx->notifyPort);
    CFRunLoopAddSource(ctx->runLoop, runLoopSource, kCFRunLoopDefaultMode);

    // Register for device arrival notifications
    kr = IOServiceAddMatchingNotification(ctx->notifyPort,
                                         kIOFirstMatchNotification,
                                         matchingDict,
                                         DeviceAddedCallback,
                                         ctx,
                                         &ctx->addedIterator);

    if (kr != KERN_SUCCESS) {
        syslog(LOG_ERR, "USBPre: Failed to add matching notification: 0x%08x", kr);
        return -1;
    }

    // Prime the iterator (handles devices already present)
    DeviceAddedCallback(ctx, ctx->addedIterator);

    syslog(LOG_NOTICE, "USBPre: Monitor daemon started, watching for device");
    return 0;
}

int main(int argc, char *argv[])
{
    MonitorContext ctx = {0};

    // Open syslog
    openlog("usbpre_monitor", LOG_PID | LOG_CONS, LOG_DAEMON);
    syslog(LOG_NOTICE, "USBPre Monitor Daemon starting (VID:0x%04X, PID:0x%04X)",
           USBPRE_VENDOR_ID, USBPRE_PRODUCT_ID);

    // Setup device monitoring
    if (SetupDeviceMonitoring(&ctx) < 0) {
        syslog(LOG_ERR, "USBPre: Failed to setup device monitoring");
        closelog();
        return 1;
    }

    // Run event loop
    CFRunLoopRun();

    // Cleanup (never reached in normal operation)
    IONotificationPortDestroy(ctx.notifyPort);
    IOObjectRelease(ctx.addedIterator);
    closelog();

    return 0;
}
