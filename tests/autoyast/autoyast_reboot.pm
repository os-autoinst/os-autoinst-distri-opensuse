# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: systemd-sysvinit
# Summary: Reboot for autoyast scenarios
# - Switch from the serial terminal to the root console on qemu
# - Call power_action reboot, with options "keepconsole => 1" and "textmode =>
# 1"
# Maintainer: Pavel Sladek <psladek@suse.cz>

use Mojo::Base 'basetest';
use testapi qw(is_serial_terminal :DEFAULT);
use power_action_utils 'power_action';
use Utils::Backends 'is_qemu';

sub run {
    # The following boot is watched with needles, which a serial terminal
    # cannot show, so reboot from the VGA root console on qemu.
    select_console 'root-console' if is_qemu && is_serial_terminal;
    # Otherwise reboot from the current console and do not switch to x11 or root console
    # Note, on s390x with SLE15 VNC is not running even if enabled in the profile
    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;
