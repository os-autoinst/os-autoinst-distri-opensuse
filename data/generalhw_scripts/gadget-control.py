#!/usr/bin/python3
#
# Documentation: https://www.kernel.org/doc/Documentation/usb/gadget_hid.txt
# Based on https://gist.github.com/marmarek/5c44ffeb2f36e106b4d34e7e8780c208 - rev 3
#
# Limitations:
#   * usb_f_hid kernel module needs to be loaded before this script - modprobe usb_f_hid
#   * This script does not work within u-boot/grub. U-boot shows:
#       scanning bus xhci_pci for devices... Failed to get keyboard state from device 0x1d6b:0x0104
#   * It needs the target to be up and running before trying to send anything (otherwise, it crashes)
#   * Mouse reports absolute position (not relative) and is setup for 1024x768
#
# Usage:
#   * a
#   * ctrl-a
#   * ret
#   * mouse_move 10 50
#   * mouse_button 1

import argparse
import os
import os.path
import pathlib
import struct
import sys
import fileinput

class Gadget:
    def __init__(self, storage_path=None, cdrom=False, hid=True):
        self.gadget_configfs_root = pathlib.Path("/sys/kernel/config/usb_gadget/kbd")
        self.udc = os.listdir('/sys/class/udc')[0]
        self.mouse_dev = None
        self.keyboard_dev = None
        self.storage_path = storage_path
        self.storage_cdrom = cdrom
        self.hid = hid

    def set_sysfs_attr(self, name, value):
        path = self.gadget_configfs_root / name
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if isinstance(value, str):
            value = value.encode()
        if isinstance(value, int):
            value = str(value).encode()
        with open(path, 'wb') as f:
            f.write(value)

    def create_gadget(self):
        self.set_sysfs_attr('bcdUSB', '0x0200') # USB 2.0
        self.set_sysfs_attr('bDeviceClass', '0x00') # specified in interface
        self.set_sysfs_attr('bDeviceSubClass', '0x00') # specified in interface
        self.set_sysfs_attr('bcdDevice', '0x0100') # v1.0.0
        self.set_sysfs_attr('bDeviceProtocol', '0x00') # specified in interface
        self.set_sysfs_attr('idVendor', '0x1d6b') # Linux Foundation
        self.set_sysfs_attr('idProduct', '0x0104') # Multifunction composite gadget
        self.set_sysfs_attr('strings/0x409/manufacturer', 'openQA')
        self.set_sysfs_attr('strings/0x409/product', 'Linux USB Gadget')
        self.set_sysfs_attr('strings/0x409/serialnumber', '0123456789abcdef')
        self.set_sysfs_attr('configs/c.1/bmAttributes', '0x80') # Bus powered
        self.set_sysfs_attr('configs/c.1/MaxPower', '250')
        self.set_sysfs_attr('configs/c.1/strings/0x409/configuration', 'c1')
        if self.hid:
            self._create_keyboard_function()
            self._create_mouse_function()
        if self.storage_path:
            self._create_storage_function()

    def _create_keyboard_function(self):
        p = 'functions/hid.usb0/'
        self.set_sysfs_attr(p + 'protocol', '1') # Keyboard
        self.set_sysfs_attr(p + 'subclass', '1') # boot interface subclass
        self.set_sysfs_attr(p + 'report_length', '8')
        report_descriptor = [
                0x05, 0x01,     # USAGE_PAGE (Generic Desktop)
                0x09, 0x06,     # USAGE (Keyboard)
                0xa1, 0x01,     # COLLECTION (Application)
                0x05, 0x07,     #   USAGE_PAGE (Keyboard)
                0x19, 0xe0,     #   USAGE_MINIMUM (Keyboard LeftControl)
                0x29, 0xe7,     #   USAGE_MAXIMUM (Keyboard Right GUI)
                0x15, 0x00,     #   LOGICAL_MINIMUM (0)
                0x25, 0x01,     #   LOGICAL_MAXIMUM (1)
                0x75, 0x01,     #   REPORT_SIZE (1)
                0x95, 0x08,     #   REPORT_COUNT (8)
                0x81, 0x02,     #   INPUT (Data,Var,Abs)
                0x95, 0x01,     #   REPORT_COUNT (1)
                0x75, 0x08,     #   REPORT_SIZE (8)
                0x81, 0x03,     #   INPUT (Cnst,Var,Abs)
                0x95, 0x05,     #   REPORT_COUNT (5)
                0x75, 0x01,     #   REPORT_SIZE (1)
                0x05, 0x08,     #   USAGE_PAGE (LEDs)
                0x19, 0x01,     #   USAGE_MINIMUM (Num Lock)
                0x29, 0x05,     #   USAGE_MAXIMUM (Kana)
                0x91, 0x02,     #   OUTPUT (Data,Var,Abs)
                0x95, 0x01,     #   REPORT_COUNT (1)
                0x75, 0x03,     #   REPORT_SIZE (3)
                0x91, 0x03,     #   OUTPUT (Cnst,Var,Abs)
                0x95, 0x06,     #   REPORT_COUNT (6)
                0x75, 0x08,     #   REPORT_SIZE (8)
                0x15, 0x00,     #   LOGICAL_MINIMUM (0)
                0x25, 0x65,     #   LOGICAL_MAXIMUM (101)
                0x05, 0x07,     #   USAGE_PAGE (Keyboard)
                0x19, 0x00,     #   USAGE_MINIMUM (Reserved)
                0x29, 0x65,     #   USAGE_MAXIMUM (Keyboard Application)
                0x81, 0x00,     #   INPUT (Data,Ary,Abs)
                0xc0            # END_COLLECTION
        ]
        self.set_sysfs_attr(p + 'report_desc', bytes(report_descriptor))
        os.symlink(self.gadget_configfs_root / 'functions/hid.usb0',
                os.path.join(self.gadget_configfs_root, 'configs/c.1/hid.usb0'))

    def _create_mouse_function(self):
        p = 'functions/hid.usb1/'
        self.set_sysfs_attr(p + 'protocol', '0') # tablet
        self.set_sysfs_attr(p + 'subclass', '0') # unspecified
        self.set_sysfs_attr(p + 'report_length', '6')
        # this mouse reports ABSOLUTE position, not relative!
        report_descriptor = [
                0x05, 0x01,        # Usage Page (Generic Desktop Ctrls)
                0x09, 0x02,        # Usage (Mouse)
                0xA1, 0x01,        # Collection (Application)
                0x85, 0x01,        #   Report ID (1)
                0x09, 0x01,        #   Usage (Pointer)
                0xA1, 0x00,        #   Collection (Physical)
                0x05, 0x09,        #     Usage Page (Button)
                0x19, 0x01,        #     Usage Minimum (0x01)
                0x29, 0x03,        #     Usage Maximum (0x03)
                0x15, 0x00,        #     Logical Minimum (0)
                0x25, 0x01,        #     Logical Maximum (1)
                0x95, 0x03,        #     Report Count (3)
                0x75, 0x01,        #     Report Size (1)
                0x81, 0x02,        #     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0x95, 0x01,        #     Report Count (1)
                0x75, 0x05,        #     Report Size (5)
                0x81, 0x03,        #     Input (Const,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0x05, 0x01,        #     Usage Page (Generic Desktop Ctrls)
                0x09, 0x30,        #     Usage (X)
                0x09, 0x31,        #     Usage (Y)
                0x16, 0x01, 0x80,        #     Logical Minimum (-32767)
                0x26, 0xFF, 0x7F,        #     Logical Maximum (32767)
                0x75, 0x10,        #     Report Size (16)
                0x95, 0x02,        #     Report Count (2)
                0x81, 0x06,        #     Input (Data,Var,Rel,No Wrap,Linear,Preferred State,No Null Position)
                0xC0,              #   End Collection
                0xC0,              # End Collection
                0x05, 0x0d,        # Usage Page (Digitizer)
                0x09, 0x01,        # Usage (Digitizer)
                0xA1, 0x01,        # Collection (Application)
                0x85, 0x02,        #   Report ID (2)
                0x05, 0x0d,        #   Usage Page (Digitizer)
                0x09, 0x20,        #   Usage (Stylus)
                0xA1, 0x00,        #   Collection (Physical)
                0x09, 0x32,        #     Usage (In Range)
                0x09, 0x42,        #     Usage (Tip Switch)
                0x09, 0x44,        #     Usage (Barrel Switch)
                0x15, 0x00,        #     Logical Minimum (0)
                0x25, 0x01,        #     Logical Maximum (1)
                0x95, 0x03,        #     Report Count (3)
                0x75, 0x01,        #     Report Size (1)
                0x81, 0x02,        #     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0x95, 0x05,        #     Report Count (5)
                0x75, 0x01,        #     Report Size (1)
                0x81, 0x03,        #     Input (Const,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0x05, 0x01,        #     Usage Page (Generic Desktop Ctrls)
                0x55, 0x0E,        #     UNIT_EXPONENT (-2)       //10^(-2)
                0x65, 0x13,        #     UNIT (Inches, English Linear)  //But exponent -2, so Physical Maximum is in 10’s of mils.
                0x09, 0x30,        #     Usage (X)
                0x15, 0x00,        #     Logical Minimum (0)
                0x26, 0x00, 0x04,        #     Logical Maximum (1024)
                0x35, 0x00,        #     Physical Minimum (0)
                0x46, 0x00, 0x04,        #     Physical Maximum (1024)
                0x75, 0x10,        #     Report Size (16)
                0x95, 0x01,        #     Report Count (1)
                0x81, 0x02,        #     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0x09, 0x31,        #     Usage (Y)
                0x26, 0x00, 0x03,        #     Logical Maximum (768)
                0x46, 0x00, 0x03,        #     Physical Maximum (768)
                0x81, 0x02,        #     Input (Data,Var,Abs,No Wrap,Linear,Preferred State,No Null Position)
                0xC0,              #   End Collection
                0xC0,              # End Collection
        ]
        self.set_sysfs_attr(p + 'report_desc', bytes(report_descriptor))
        os.symlink(self.gadget_configfs_root / 'functions/hid.usb1',
                self.gadget_configfs_root / 'configs/c.1/hid.usb1')

    def _create_storage_function(self):
        p = 'functions/mass_storage.usb2/lun.0/'
        self.set_sysfs_attr(p + 'cdrom', 'Y' if self.storage_cdrom else 'N') # is cdrom
        self.set_sysfs_attr(p + 'file', self.storage_path) # backing file
        self.set_sysfs_attr(p + 'removable', '1')
        os.symlink(self.gadget_configfs_root / 'functions/mass_storage.usb2',
                self.gadget_configfs_root / 'configs/c.1/mass_storage.usb2')


    def _get_gadget_dev(self, func):
        with open(self.gadget_configfs_root / (func + '/dev'), 'r') as f:
            devnum = f.read()
        return '/dev/' + os.path.basename(os.readlink('/sys/dev/char/' + devnum.strip()))


    def enable(self):
        with open(self.gadget_configfs_root / 'UDC', 'w') as f:
            f.write(self.udc)
        if self.hid:
            self.keyboard_dev = open(self._get_gadget_dev('functions/hid.usb0'), 'wb', buffering=0)
            self.mouse_dev = open(self._get_gadget_dev('functions/hid.usb1'), 'wb', buffering=0)

    def disable(self):
        if self.keyboard_dev:
            self.keyboard_dev.close()
            self.keyboard_dev = None
        if self.mouse_dev:
            self.mouse_dev.close()
            self.mouse_dev = None
        with open(os.path.join(self.gadget_configfs_root, 'UDC'), 'w'):
            pass

    def cleanup(self):
        for d in os.listdir(self.gadget_configfs_root / 'configs/c.1'):
            if '.usb' in d:
                os.unlink(self.gadget_configfs_root / 'configs/c.1' / d)
        for (dirpath, dirs, _files) in os.walk(self.gadget_configfs_root, topdown=False):
            for d in dirs:
                if d in ('strings', 'os_desc', 'configs', 'functions', 'lun.0'):
                    # Linux doesn't allow to remove this one
                    continue
                os.rmdir(os.path.join(dirpath, d))
        os.rmdir(self.gadget_configfs_root)

    def write_mouse_move_report(self, x, y, wheel=0):
        # 2 - report id - stylus
        # 0x01 - in range, but not touching
        report = struct.pack('<bBhh', 2, 0x01, x, y)
        self.mouse_dev.write(report)

    def write_mouse_btn_report(self, buttons):
        # 1 - report id - buttons
        report = struct.pack('<bBxxxx', 1, buttons)
        self.mouse_dev.write(report)

    def write_keyboard_report(self, modifiers, key):
        # TODO: more keys?
        report = struct.pack('BxxBxxxx', modifiers, key)
        self.keyboard_dev.write(report)
        self.keyboard_dev.write(b'\0' * 8)

    def __enter__(self):
        if os.path.exists(self.gadget_configfs_root):
            # previous instance didn't cleaned up
            self.disable()
            self.cleanup()
        self.create_gadget()
        self.enable()
        return self

    def __exit__(self, exc_type, exc_value, exc_traceback):
        self.disable()
        self.cleanup()


# based on Universal Serial Bus HID Usage Tables
keycodes = {
    # key: (mods, keycode)
    'a': (0, 0x04),               'A': (2, 0x04),
    'b': (0, 0x05),               'B': (2, 0x05),
    'c': (0, 0x06),               'C': (2, 0x06),
    'd': (0, 0x07),               'D': (2, 0x07),
    'e': (0, 0x08),               'E': (2, 0x08),
    'f': (0, 0x09),               'F': (2, 0x09),
    'g': (0, 0x0A),               'G': (2, 0x0A),
    'h': (0, 0x0B),               'H': (2, 0x0B),
    'i': (0, 0x0C),               'I': (2, 0x0C),
    'j': (0, 0x0D),               'J': (2, 0x0D),
    'k': (0, 0x0E),               'K': (2, 0x0E),
    'l': (0, 0x0F),               'L': (2, 0x0F),
    'm': (0, 0x10),               'M': (2, 0x10),
    'n': (0, 0x11),               'N': (2, 0x11),
    'o': (0, 0x12),               'O': (2, 0x12),
    'p': (0, 0x13),               'P': (2, 0x13),
    'q': (0, 0x14),               'Q': (2, 0x14),
    'r': (0, 0x15),               'R': (2, 0x15),
    's': (0, 0x16),               'S': (2, 0x16),
    't': (0, 0x17),               'T': (2, 0x17),
    'u': (0, 0x18),               'U': (2, 0x18),
    'v': (0, 0x19),               'V': (2, 0x19),
    'w': (0, 0x1A),               'W': (2, 0x1A),
    'x': (0, 0x1B),               'X': (2, 0x1B),
    'y': (0, 0x1C),               'Y': (2, 0x1C),
    'z': (0, 0x1D),               'Z': (2, 0x1D),
    '1': (0, 0x1E),               '!': (2, 0x1E),
    '2': (0, 0x1F),               '@': (2, 0x1F),
    '3': (0, 0x20),               '#': (2, 0x20),
    '4': (0, 0x21),               '$': (2, 0x21),
    '5': (0, 0x22),               '%': (2, 0x22),
    '6': (0, 0x23),               '^': (2, 0x23),
    '7': (0, 0x24),               '&': (2, 0x24),
    '8': (0, 0x25),               '*': (2, 0x25),
    '9': (0, 0x26),               '(': (2, 0x26),
    '0': (0, 0x27),               ')': (2, 0x27),
    'ret': (0, 0x28),
    'esc': (0, 0x29),
    'backspace': (0, 0x2A),
    'tab': (0, 0x2B),
    'space': (0, 0x2C),
    '-': (0, 0x2D),               '_': (2, 0x2D),
    'minus': (0, 0x2D),
    '=': (0, 0x2E),               '+': (2, 0x2E),
    '[': (0, 0x2F),               '{': (2, 0x2F),
    ']': (0, 0x30),               '}': (2, 0x30),
    '\\': (0, 0x31),              '|': (2, 0x31),
    #'#': (0, 0x32),              '~': (2, 0x32),
    ';': (0, 0x33),               ':': (2, 0x33),
    '\'': (0, 0x34),              '"': (2, 0x34),
    '`': (0, 0x35),               '~': (2, 0x35),
    ',': (0, 0x36),               '<': (2, 0x36),
    '.': (0, 0x37),               '>': (2, 0x37),
    '/': (0, 0x38),               '?': (2, 0x38),
    #'caps lock': (0, 0x39),
    'f1': (0, 0x3A),
    'f2': (0, 0x3B),
    'f3': (0, 0x3C),
    'f4': (0, 0x3D),
    'f5': (0, 0x3E),
    'f6': (0, 0x3F),
    'f7': (0, 0x40),
    'f8': (0, 0x41),
    'f9': (0, 0x42),
    'f10': (0, 0x43),
    'f11': (0, 0x44),
    'f12': (0, 0x45),
    'printscreen': (0, 0x46),
    'scroll': (0, 0x47),
    'pause': (0, 0x48),
    'insert': (0, 0x49),
    'home': (0, 0x4A),
    'pageup': (0, 0x4B),
    'delete': (0, 0x4C),
    'end': (0, 0x4D),
    'pagedown': (0, 0x4E),
    'right': (0, 0x4F),
    'left': (0, 0x50),
    'down': (0, 0x51),
    'up': (0, 0x52),
    'ctrl': (1, 0x0),
    'shift': (2, 0x0),
    'alt': (4, 0x0),
    'meta': (8, 0x0),
    'rctrl': (16, 0x0),
    'rshift': (32, 0x0),
    'ralt': (64, 0x0),
    'rmeta': (128, 0x0),
}


def parse_and_send_cmd(gadget, line):
    if line.startswith('mouse_'):
        cmd, param = line.split(' ', 1)
        if cmd == 'mouse_move':
            x, y = [int(p) for p in param.split(' ')]
            #x, y = (32767/1024*x), (32767/768*y)
            gadget.write_mouse_move_report(int(x), int(y))
        elif cmd == 'mouse_button':
            param = int(param)
            gadget.write_mouse_btn_report(param)
        else:
            print("Unknown command: {}".format(cmd), file=sys.stderr)
        return

    key = line
    mods = 0
    while True:
        if key.startswith('ctrl-'):
            mods |= 0x01
            key = key[len('ctrl-'):]
        elif key.startswith('shift-'):
            mods |= 0x02
            key = key[len('shift-'):]
        elif key.startswith('alt-'):
            mods |= 0x04
            key = key[len('alt-'):]
        else:
            break

    if key not in keycodes:
        print("Unknown key: {}".format(key))
        return

    extra_mods, keycode = keycodes[key]
    mods |= extra_mods
    gadget.write_keyboard_report(mods, keycode)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--storage', default=None, action='store')
    parser.add_argument('--is-cdrom', default=False, action='store_true')
    parser.add_argument('--storage-only', default=False, action='store_true')
    args = parser.parse_args()

    with Gadget(storage_path=args.storage, cdrom=args.is_cdrom, hid=not args.storage_only) as gadget:
        for line in fileinput.input(files=[]):
            parse_and_send_cmd(gadget, line.strip())

if __name__ == '__main__':
    main()
