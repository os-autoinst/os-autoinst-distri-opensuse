#!/bin/bash

# Ensure extensions included in ISO's /extensions folder are loaded at boot
# ISO filesystem is mounted at /run/initramfs/live folder
rm -rf /run/extensions
ln -s /run/initramfs/live/extensions /run/extensions

# Set the elemental-autoinstall.service, used to automatically install UC image
cat > /etc/systemd/system/elemental-autoinstall.service <<EOF
[Unit]
Description=Elemental Autoinstall
Wants=network-online.target
After=network-online.target
ConditionPathExists=/run/initramfs/live/Install/install.yaml
ConditionFileIsExecutable=/usr/bin/elemental3ctl

[Service]
Type=oneshot
ExecStart=/usr/bin/elemental3ctl --debug install
ExecStartPost=reboot

[Install]
WantedBy=multi-user.target
EOF

systemctl enable elemental-autoinstall.service
