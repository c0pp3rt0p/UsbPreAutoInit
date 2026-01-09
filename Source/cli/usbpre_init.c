/*
 * USBPre PIC Initialization Tool
 *
 * Manual initialization for Sound Devices USBPre audio interface.
 * Run this after plugging in the device if you prefer not to use the daemon.
 *
 * Commands discovered via USB packet capture from Windows driver (2025).
 *
 * Copyright (c) 2025 Craig Carrier
 * Licensed under MIT License
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>

#define USBPRE_VENDOR_ID   0x0926
#define USBPRE_PRODUCT_ID  0x0100

/*
 * PIC Initialization Commands (validated via USB packet sniffing)
 *
 * Both commands use:
 *   bmRequestType: 0x40 (Host-to-device, Vendor, Device)
 *   bRequest:      0x01
 *   wValue:        0x00F0
 *   wIndex:        0x01F0
 *   wLength:       1
 *
 * Command 1 data: 0x81 (initialize)
 * Command 2 data: 0xC0 (activate)
 * Delay between:  5 seconds
 */

static io_service_t find_usbpre_device(void)
{
    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    if (!match) return IO_OBJECT_NULL;

    SInt32 vid = USBPRE_VENDOR_ID;
    SInt32 pid = USBPRE_PRODUCT_ID;
    CFNumberRef vidRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vid);
    CFNumberRef pidRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pid);

    CFDictionarySetValue(match, CFSTR(kUSBVendorID), vidRef);
    CFDictionarySetValue(match, CFSTR(kUSBProductID), pidRef);
    CFRelease(vidRef);
    CFRelease(pidRef);

    return IOServiceGetMatchingService(kIOMainPortDefault, match);
}

static IOUSBDeviceInterface** open_device(io_service_t device)
{
    IOCFPlugInInterface **plugin = NULL;
    IOUSBDeviceInterface **dev = NULL;
    SInt32 score;

    if (IOCreatePlugInInterfaceForService(device, kIOUSBDeviceUserClientTypeID,
            kIOCFPlugInInterfaceID, &plugin, &score) != kIOReturnSuccess) {
        return NULL;
    }

    (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                              (LPVOID*)&dev);
    (*plugin)->Release(plugin);

    if (dev && (*dev)->USBDeviceOpen(dev) != kIOReturnSuccess) {
        (*dev)->Release(dev);
        return NULL;
    }

    return dev;
}

static IOReturn send_pic_command(IOUSBDeviceInterface **dev, uint8_t data)
{
    IOUSBDevRequest req = {
        .bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
        .bRequest = 0x01,
        .wValue = 0x00F0,
        .wIndex = 0x01F0,
        .wLength = 1,
        .pData = &data
    };
    return (*dev)->DeviceRequest(dev, &req);
}

int main(int argc, char *argv[])
{
    printf("USBPre PIC Initialization\n");
    printf("=========================\n\n");

    io_service_t device = find_usbpre_device();
    if (device == IO_OBJECT_NULL) {
        fprintf(stderr, "Error: USBPre not found. Is it plugged in?\n");
        return 1;
    }
    printf("Found USBPre device\n");

    IOUSBDeviceInterface **dev = open_device(device);
    IOObjectRelease(device);
    if (!dev) {
        fprintf(stderr, "Error: Could not open device\n");
        return 1;
    }

    printf("Sending initialization commands...\n");

    if (send_pic_command(dev, 0x81) != kIOReturnSuccess) {
        fprintf(stderr, "Error: Command 1 failed\n");
        (*dev)->USBDeviceClose(dev);
        (*dev)->Release(dev);
        return 1;
    }
    printf("  Command 1 (0x81): OK\n");

    printf("  Waiting 5 seconds...\n");
    sleep(5);

    if (send_pic_command(dev, 0xC0) != kIOReturnSuccess) {
        fprintf(stderr, "Error: Command 2 failed\n");
        (*dev)->USBDeviceClose(dev);
        (*dev)->Release(dev);
        return 1;
    }
    printf("  Command 2 (0xC0): OK\n");

    (*dev)->USBDeviceClose(dev);
    (*dev)->Release(dev);

    printf("\nSuccess! Device initialized.\n");
    printf("Buttons, LEDs, and phantom power should now work.\n");
    return 0;
}
