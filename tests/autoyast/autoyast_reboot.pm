# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: systemd-sysvinit
# Summary: Reboot for autoyast scenarios
# - Call power_action reboot, with options "keepconsole => 1" and "textmode =>
# 1"
# Maintainer: Pavel Sladek <psladek@suse.cz>

use Mojo::Base 'basetest';
use testapi;
use power_action_utils 'power_action';

sub run {
    # Reboot from the current console and keep it. On qemu a serial terminal
    # is still moved to the VGA console by power_action first, so the boot
    # that follows can be watched with needles.
    # Note, on s390x with SLE15 VNC is not running even if enabled in the profile
    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;
