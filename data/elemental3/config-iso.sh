#!/bin/bash

set -xe

# Ensure extensions included in ISO's image are loaded at boot
# ISO filesystem is mounted at /run/initramfs/live folder
mkdir -p /run/extensions
for RAW in /run/initramfs/live/*.raw; do
  [[ -f "${RAW}" ]] && ln -s ${RAW} /run/extensions/
done

# Set autologin for the Live ISO
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I xterm-256color
EOF

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I xterm-256color
EOF

# Set the elemental-autoinstall.service
cat > /etc/systemd/system/elemental-autoinstall.service <<EOF
[Unit]
Description=Elemental Autoinstall
After=multi-user.target
ConditionPathExists=/run/initramfs/live/Install/install.yaml
ConditionFileIsExecutable=/usr/bin/elemental3ctl
OnSuccess=reboot.target

[Service]
Type=oneshot
ExecStart=/usr/bin/elemental3ctl --debug install --create-boot-entry
Restart=on-failure
RestartSec=5
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

systemctl enable elemental-autoinstall.service
