Testing on real hardware for Raspberry Pi testing
=================================================

# Initial notes
This document is refering to the internal openqa.suse.de (OSD) setup and not to the
public openqa.opensuse.org (O3) setup.

While most of the setup is similar, there are some key differences:

- different NFS share (In the O3 DMZ the NFS host would be `openqa1-opensuse` but actually
  ggardet's O3 rpi hw test setup is using GIT as it is not in that network)
- no wifi or bluetooth setup in the O3 setup
- no hw serial connection in the O3 setup but `sshserial` (just leave out the `GENERAL_HW_SOL_` config)
- usage of the older `flash_sd.sh` script in the O3 setup

# Overview

```
┌───────────────────────────┐        ┌──┬───────┬─┐
│                           │        │  │SD-Card│ │
│                           │  USB   │  └───────┘ │
│                           ├───────►│ USB SD-Mux ├─┐ µSD   ┌────────────────┐         ┌─────────────────┐
│         piworker          │        └────────────┘ └──────►│                │   5V    │ WLAN Power Plug │
│      Raspberry Pi 4B      │      USB UART Adapter         │ Raspberry Pi 4 ├────────►│  Shelly Plug S  │
│                           ├──────────────────────────────►│                │         └─────────────────┘
│                           │                               │                │   SPI   ┌─────────────────┐
│                           │  USB  ┌──────────────┐  HDMI  │                ├────────►│  LetsTrust TPM  │
│                           ├──────►│ HDMI Grabber │───────►│                │         └─────────────────┘
│                           │       └──────────────┘        │                │   I2C   ┌─────────────────┐
│                           │                               │                ├────────►│    DS3231 RTC   │
│                           │                               │                │         └─────────────────┘
│ ┌───────────────────────┐ │                               └────────────────┘
│ │ openQA-worker WLAN AP │ │        ┌──┬───────┬─┐
│ └───────────────────────┘ │        │  │SD-Card│ │
│                           │  USB   │  └───────┘ │
│ ┌───────────────────────┐ ├───────►│ USB SD-Mux ├─┐ µSD   ┌──────────────────┐       ┌─────────────────┐
│ │ openQA-worker BT      │ │        └────────────┘ └──────►│                  │  5V   │ WLAN Power Plug │
│ └───────────────────────┘ │      USB UART Adapter         │ Raspberry Pi 3B+ ├──────►│  Shelly Plug S  │
│                           ├──────────────────────────────►│                  │       └─────────────────┘
│                           │                               └──────────────────┘
│                           │        ┌──┬───────┬─┐
│                           │        │  │SD-Card│ │
│                           │  USB   │  └───────┘ │
│                           ├───────►│ USB SD-Mux ├─┐ µSD   ┌─────────────────────┐    ┌─────────────────┐
│                           │        └────────────┘ └──────►│                     │ 5V │ WLAN Power Plug │
│                           │      USB UART Adapter         │ Raspberry Pi 3Bv1.2 ├───►│  Shelly Plug S  │
│                           ├──────────────────────────────►│                     │    └─────────────────┘
│                           │                               └─────────────────────┘
│                           │
└───────────────────────────┘
```

All Raspberries are connected to the QA Network via Ethernet cable.
The Shelly Plugs are connected to the piworker directly via WLAN (`openQA-worker`) using the AP on that device.
The SUTs are connecting to that WLAN Network during the openQA test as well as searching for Bluetooth devices during the test to check wireless connectivity.
The 230V AC to 5V DC power adapters have been omitted in this graphic for better overview.

# Setup

We are using a setup without the usb gadget method but using the [USB SD-Mux](https://shop.linux-automation.com/usb_sd_mux-D02-R01-V02-C00) and the `usbsdmux` cli tool. For now Samsung sdcards (EVO Plus 32GB) worked fine with that hardware but SanDisk sdcards didn't.
We have a usb-ttl serial adapters and Shelly Plug S wifi power plugs for power cycling the RPi SUT.
That one has the advantage that it doesn't enforce using the vendor cloud for operation.

## Install packages

```
VERSION=15.3
zypper ar obs://devel:openQA devel:openQA
source /etc/os-release
zypper ar obs://devel:openQA:Leap:$VERSION devel:openQA:Leap:$VERSION
zypper ref
zypper -n in openQA-worker os-autoinst-distri-opensuse-deps nfs-client
zypper -n in qemu-tools icewm-default xterm-console python3-usbsdmux hostapd dhcp-server bluez
```

## Allow access to USB SD-Mux and serial adapters

Create udev rule: `/etc/udev/rules.d/99-piworker-permission.rules`:
```
ACTION=="add", SUBSYSTEM=="scsi_generic", KERNEL=="sg[0-9]", ATTRS{manufacturer}=="Linux Automation GmbH", ATTRS{product}=="usb-sd-mux*", OWNER="_openqa-worker"
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*", ATTRS{manufacturer}=="Linux Automation GmbH", ATTRS{product}=="usb-sd-mux*", OWNER="_openqa-worker"
```

Ensure that `_openqa-worker` will be able to access the usb-serial adapter:
```
usermod -a -G dialout _openqa-worker
```

Ensure that `_openqa-worker` will be able to access the HDMI grabber:
```
usermod -a -G video _openqa-worker
```

Disable apparmor:
```
systemctl mask apparmor
```

## Mount NFS share from openqa server

Add to `/etc/fstab`:
```
openqa.suse.de:/var/lib/openqa/share /var/lib/openqa/share nfs noauto,nofail,retry=30,ro,x-systemd.automount,x-systemd.device-timeout=10m,x-systemd.mount-timeout=30m  0 0
```

## Use tmpfs for pool directory (to extend sdcard lifetime if you have enough RAM)

Add to `/etc/fstab`:
```
tmpfs /var/lib/openqa/pool tmpfs defaults 0 0
```

## Create worker configuration

Add to `/etc/openqa/workers.ini`:
```
[global]
GENERAL_HW_CMD_DIR = /var/lib/openqa/share/tests/opensuse/data/generalhw_scripts
WORKER_HOSTNAME = <INSERT WORKER HOST ETHERNET IP ADDRESS HERE>
RPI_WIFI_PSK = <INSERT WORKER HOST WIFI PASSWORD HERE>
RPI_WIFI_WORKER_IP = 192.168.7.1

[1]
# Raspberry Pi 4 B
# Most config moved to openQA `MACHINE` defintion due to https://progress.opensuse.org/issues/63766
GENERAL_HW_FLASH_ARGS = /dev/shm/1 000000001006
GENERAL_HW_FLASH_CMD = flash_sd_rootless.sh

GENERAL_HW_POWEROFF_CMD = power_on_off_shelly.sh
GENERAL_HW_POWEROFF_ARGS = 192.168.7.11 off
GENERAL_HW_POWERON_CMD = power_on_off_shelly.sh
GENERAL_HW_POWERON_ARGS = 192.168.7.11 on

GENERAL_HW_SOL_CMD = get_sol_dev.sh
GENERAL_HW_SOL_ARGS = serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.1:1.0-port0

SUT_IP = <INSERT RASPBERRY SUT IP HERE AS CONFIGURED IN NETWORK DHCP SERVER>
WORKER_CLASS = generalhw_RPi4
```

In the configuration above the sdmux devices (the control as well as the block device node) are added by serial number, so they will just work on any usb port. The USB UART adapters don't have a serial number so they are added by path which means that they can be distinguished reliably only as long as they are always connected to the same usb port (this is also true for the usb hub they are connected to).

Workaround for https://progress.opensuse.org/issues/105855: openqa-worker will fail if it starts before NTP sync is done (on non-RTC hosts) so auto-restart worker and try to wait for time-sync.target.
Write to `/etc/systemd/system/openqa-worker@.service.d/override.conf`:
```
[Service]
Restart=always
RestartSec=10s
```

Enable the worker:
```
systemctl enable openqa-worker@1
```

## WLAN network configuration

### Setup bridge

Configure br0 which is to be used by the wlan0 device.
Write to `/etc/sysconfig/network/ifcfg-br0`:
```
IPADDR='192.168.7.1/24'
BOOTPROTO='static'
STARTMODE='auto'
BRIDGE='yes'
BRIDGE_PORTS=''
BRIDGE_STP='off'
BRIDGE_FORWARDDELAY='15'
ZONE=dmz
```

### Setup hostapd

Setup wifi AP for wifi plugs and for SUT to test wifi connection. This AP doesn't provide internet access.

```
interface=wlan0
bridge=br0
ssid=openQA-worker
wpa_passphrase=<INSERT WORKER HOST WIFI PASSWORD HERE>
driver=nl80211
country_code=DE
hw_mode=g
channel=7
# Bit field: bit0 = WPA, bit1 = WPA2, 3=both
wpa=2
# Bit field: 1=wpa, 2=wep, 3=both
auth_algs=1
wpa_pairwise=CCMP
wpa_key_mgmt=WPA-PSK
logger_stdout=-1
logger_stdout_level=2
```

Ensure that wlan0 is up before starting hostapd (otherwise hostapd will not add wlan0 to the bridge).
This will work at least after a reboot.
Write to `/etc/systemd/system/hostapd.service.d/override.conf`:
```
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device
```

Enable hostapd:
```
systemctl enable hostapd
```

### Setup dhcp server
Write to `/etc/dhcpd.conf`:

```
subnet 192.168.7.0 netmask 255.255.255.0 {
    range 192.168.7.30 192.168.7.254;
}

# wifi power plugs
host shelly1 { hardware ethernet e8:68:e7:c5:00:14; fixed-address 192.168.7.11; }
host shelly2 { hardware ethernet 3c:61:05:f0:56:42; fixed-address 192.168.7.12; }
host shelly3 { hardware ethernet 34:ab:95:1c:94:f0; fixed-address 192.168.7.13; }
```

Enable dhcp:
```
sed -i 's/^DHCPD_INTERFACE="[^"]*"/DHCPD_INTERFACE="br0"/' /etc/sysconfig/dhcpd
systemctl enable dhcpd
```

### Setup firewall

```
systemctl enable --now firewalld

# ensure that the wifi doesn't allow ssh access
firewall-cmd --zone=dmz --remove-service=ssh --permanent

# ensure that webui can access worker for live debug mode
firewall-cmd --zone=public --set-target=ACCEPT --permanent

firewall-cmd --reload
```

## Bluetooth configuration
Write to `/etc/systemd/system/bluetooth-config.service`:
```
[Unit]
Description=Configure bluetooth
After=bluetooth.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bluetoothctl power on
ExecStart=/usr/bin/bluetoothctl system-alias openQA-worker
ExecStart=/usr/bin/bluetoothctl discoverable-timeout 0
ExecStart=/usr/bin/bluetoothctl discoverable on
ExecStart=/usr/bin/bluetoothctl show
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable bluetooth:
```
systemctl enable --now bluetooth
systemctl enable --now bluetooth-config
```

## Workaround for insufficient RAM
As the images are not stored to the sdcard of the worker host (it would wear down the sdcard too fast) the images should be stored in RAM, which is reflected in the above configuration (/dev/shm/). While this works fine with a single worker instance, 4GB of RAM is not sufficient for three worker instances. So as a workaround I'm using an NFS share, which is obviously not very fast (especially as the image is copied from the osd NFS share to that new NFS share).

### NFS Server
On the server write to `/etc/exports`:
```
/export *(rw,async,no_subtree_check,insecure,no_root_squash)
```

### Mount
Add to `/etc/fstab`:
```
<NFS SERVER IP>:/export/ /nfs nfs noauto,nofail,retry=30,rw,x-systemd.automount,x-systemd.device-timeout=10m,x-systemd.mount-timeout=30m  0 0
```

Then replace the `/dev/shm/` entries in the `workers.ini` with `/nfs/`.

## Reboot

```
reboot
```
