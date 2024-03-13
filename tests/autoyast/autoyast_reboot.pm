# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: systemd-sysvinit
# Summary: Reboot for autoyast scenarios
# - Call power_action reboot, with options "keepconsole => 1" and "textmode =>
# 1"
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;
use power_action_utils 'power_action';
use bootloader_setup qw(add_grub_cmdline_settings);
sub run {

    
    # https://freedesktop.org/wiki/Software/systemd/Debugging/
    my $grub_param="systemd.log_level=debug systemd.log_target=kmsg log_buf_len=1M printk.devkmsg=on enforcing=0";
    add_grub_cmdline_settings($grub_param, update_grub => 1);

    # We are already in console, so reboot from it and do not switch to x11 or root console
    # Note, on s390x with SLE15 VNC is not running even if enabled in the profile
    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;

